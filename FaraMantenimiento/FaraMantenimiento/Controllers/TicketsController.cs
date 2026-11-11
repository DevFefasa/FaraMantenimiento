using System.Security.Claims;
using FaraMantenimiento.Helpers;
using FaraMantenimiento.ViewModels.Tickets;
using FM.OrigenDatos.Modelos.Adjunto;
using FM.OrigenDatos.Modelos.Tickets;
using FM.Programacion.Constantes;
using FM.Programacion.Servicios;
using FM.Programacion.Servicios.Tickets;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FaraMantenimiento.Controllers;

[Authorize]
public class TicketsController : Controller
{
    private readonly TicketServicio _tickets;
    private readonly CatalogoServicio _catalogos;
    private readonly ExportacionServicio _exportacion;
    private readonly SapServicio _sap;

    // Callers: Program.cs DI. API: BuscarArticulosSap/BuscarProveedoresSap. Schema: ConnectionStrings:SapHana, Sap:Esquema.
    // Confirm: SapServicio registrado en ProgramacionServiceCollectionExtensions.
    // User instruction: "Endpoints de búsqueda (AJAX, mínimo 2 letras, máximo 30 resultados) para artículos... y proveedores"
    public TicketsController(TicketServicio tickets, CatalogoServicio catalogos, ExportacionServicio exportacion, SapServicio sap)
    {
        _tickets = tickets;
        _catalogos = catalogos;
        _exportacion = exportacion;
        _sap = sap;
    }

    private int UsuarioId => AppAccess.UsuarioId(User) ?? 0;
    private string? RolCodigo => User.FindFirstValue(ClaimTypes.Role);

    private async Task<FM.OrigenDatos.Modelos.Catalogos.CatalogoCombosModelo> CombosAsync(CancellationToken ct)
    {
        var (_, c) = await _catalogos.ObtenerCombosAsync(ct);
        return c;
    }

    // Límites del Dropzone (los lee _AdjuntosInput).
    private void LimitesAdjuntos()
    {
        ViewData["MaxMb"] = _tickets.MaxMbAdjunto;
        ViewData["MaxCount"] = _tickets.MaxAdjuntosPorSubida;
    }

    [HttpGet, RequierePermiso(Pantallas.TicketCrear)]
    public async Task<IActionResult> Crear(CancellationToken ct)
    {
        ViewData["Title"] = "Nuevo ticket";
        ViewBag.Combos = await CombosAsync(ct);
        LimitesAdjuntos();
        return View(new TicketCrearViewModel());
    }

    [HttpPost, ValidateAntiForgeryToken, RequierePermiso(Pantallas.TicketCrear)]
    public async Task<IActionResult> Crear(TicketCrearViewModel model, List<IFormFile>? adjuntos, CancellationToken ct)
    {
        ViewData["Title"] = "Nuevo ticket";
        ViewBag.Combos = await CombosAsync(ct);
        LimitesAdjuntos();
        if (!ModelState.IsValid) return View(model);

        var resp = await _tickets.CrearAsync(UsuarioId, model.FiSucursalId, model.FiUbicacionId, model.FcUbicacionDetalle,
            model.FiActivoId, model.FiTipoMantenimientoId, model.FiCategoriaId, model.FiPrioridadId,
            model.FcDescripcion, model.FdFechaSugerida, ct);

        if (!resp.FbSucces)
        {
            TempData["Error"] = resp.FcMensaje;
            return View(model);
        }

        // Extraer id del fjData simple: {"ticket": "N", ...}
        var id = ExtraerId(resp.FjData, "ticket");
        var rechazados = new List<string>();
        if (id > 0 && adjuntos != null)
        {
            var validos = adjuntos.Where(x => x != null && x.Length > 0).ToList();
            var max = _tickets.MaxAdjuntosPorSubida;
            if (validos.Count > max)
            {
                rechazados.Add($"Solo se permiten {max} archivos por envío; se omitieron {validos.Count - max}.");
                validos = validos.Take(max).ToList();
            }
            foreach (var f in validos)
            {
                var r = await _tickets.SubirAdjuntoAsync(id, "SOLICITUD", f, UsuarioId, RolCodigo, ct);
                if (!r.FbSucces) rechazados.Add($"{Path.GetFileName(f.FileName)}: {r.FcMensaje}");
            }
        }

        if (rechazados.Count > 0)
            TempData["Error"] = "Ticket creado, pero algunos adjuntos no se guardaron. " + string.Join(" | ", rechazados);
        TempData["Exito"] = resp.FcMensaje;
        return id > 0 ? RedirectToAction(nameof(Detalle), new { id }) : RedirectToAction(nameof(Index));
    }

    // Pestañas de /Tickets (orden de la pantalla). El filtrado por vista y su permiso están en sp_ticket_listar_vista.
    public static readonly IReadOnlyList<(string Vista, string Titulo, string Corto)> Vistas = new[]
    {
        ("creados", "Tickets creados por mí", "Creados por mí"),
        ("asignados", "Tickets asignados a mí", "Asignados a mí"),
        ("equipo", "Tickets de mi equipo", "Mi equipo"),
        ("aprobar", "Tickets por aprobar", "Por aprobar"),
        ("atender", "Tickets por atender", "Por atender"),
        ("todos", "Todos los tickets", "Todos")
    };

    private static string? VistaValida(string? vista)
    {
        var v = (vista ?? "").Trim().ToLowerInvariant();
        // Nombres viejos (Exportar?modo=...) → vista nueva.
        v = v switch { "mios" => "creados", "bandeja" => "atender", "aprobacion" => "aprobar", _ => v };
        return Vistas.Any(x => x.Vista == v) ? v : null;
    }

    private bool TienePermisoTickets() =>
        User.Claims.Any(c => c.Type == AppAccess.PermisoClaim && c.Value.StartsWith("TICKET_", StringComparison.OrdinalIgnoreCase));

    /// <summary>Vista por defecto: "creados" si puede crear o ver los suyos; si no, la primera de su función.</summary>
    private string VistaPorDefecto(IEnumerable<string> disponibles)
    {
        var d = disponibles.ToList();
        if (User.HasClaim(AppAccess.PermisoClaim, Pantallas.TicketCrear) || User.HasClaim(AppAccess.PermisoClaim, Pantallas.TicketMios))
            return "creados";
        foreach (var v in new[] { "aprobar", "atender", "todos", "equipo", "asignados", "creados" })
            if (d.Contains(v)) return v;
        return "creados";
    }

    private static TicketFiltro FiltroDe(string vista, TicketFiltro? filtro, string? estado)
    {
        switch (vista)
        {
            case "atender":
                return new TicketFiltro { FcEstadoCodigo = estado, FbSoloAbiertos = string.IsNullOrWhiteSpace(estado) };
            case "todos":
                filtro ??= new TicketFiltro();
                filtro.FiSolicitanteId = null;
                return filtro;
            default:
                return new TicketFiltro();
        }
    }

    // Enlaces viejos (menú anterior, correos, dashboard): redirigen a la pestaña equivalente.
    [HttpGet]
    public IActionResult Mios() => RedirectToAction(nameof(Index), new { vista = "creados" });

    [HttpGet]
    public IActionResult Bandeja(string? estado) => RedirectToAction(nameof(Index), new { vista = "atender", estado });

    [HttpGet]
    public IActionResult Aprobacion() => RedirectToAction(nameof(Index), new { vista = "aprobar" });

    /// <summary>Pantalla única de tickets con pestañas (?vista=creados|asignados|equipo|aprobar|atender|todos).</summary>
    [HttpGet]
    public async Task<IActionResult> Index(string? vista, string? estado, TicketFiltro filtro, CancellationToken ct)
    {
        if (!TienePermisoTickets()) return Forbid();

        var resumen = await _tickets.VistasAsync(UsuarioId, ct);
        var disponibles = resumen.Where(x => x.FbDisponible).Select(x => x.FcVista).ToList();
        var v = VistaValida(vista);
        if (v == null || !disponibles.Contains(v))
        {
            if (!string.IsNullOrWhiteSpace(vista))
                TempData["Error"] = "No tiene acceso a esa vista de tickets.";
            v = VistaPorDefecto(disponibles);
            if (!string.IsNullOrWhiteSpace(vista)) return RedirectToAction(nameof(Index), new { vista = v });
        }

        var f = FiltroDe(v, filtro, estado);
        f.FiPagina = f.FiPagina <= 0 ? 1 : f.FiPagina;
        f.FiTamano = v == "todos" ? (f.FiTamano <= 0 ? 20 : f.FiTamano) : 200;
        ViewBag.Estado = estado;
        return await ListaAsync(v, f, resumen, ct);
    }

    /// <summary>Excel de una vista con los mismos filtros que la pantalla (todas las páginas); el SP valida el permiso.</summary>
    [HttpGet]
    public async Task<IActionResult> Exportar(string? vista, string? modo, TicketFiltro filtro, string? estado, CancellationToken ct)
    {
        var v = VistaValida(vista ?? modo);
        if (v == null) return NotFound();

        var f = FiltroDe(v, filtro, estado);
        var (cab, filas) = await _tickets.ListarParaExportarAsync(v, f, UsuarioId, ct: ct);
        if (!cab.FbSucces)
        {
            if (cab.FiCodigo is 401 or 403) return Forbid();
            TempData["Error"] = cab.FcMensaje;
            return RedirectToAction(nameof(Index), new { vista = v, estado });
        }

        var titulo = Vistas.First(x => x.Vista == v).Titulo + (string.IsNullOrWhiteSpace(estado) ? "" : $" ({estado})") + $" · {DateTime.Now:dd/MM/yyyy HH:mm}";
        var bytes = _exportacion.ExcelTickets(titulo, filas);
        var nombre = $"Tickets_{v}_{DateTime.Now:yyyyMMdd_HHmm}.xlsx";
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", nombre);
    }

    private async Task<IActionResult> ListaAsync(string vista, TicketFiltro filtro, List<TicketVistaResumenModelo> resumen, CancellationToken ct)
    {
        var titulo = Vistas.First(x => x.Vista == vista).Titulo;
        ViewData["Title"] = "Tickets";
        var resp = await _tickets.ListarAsync(vista, filtro, UsuarioId, ct);
        if (!resp.FbSucces) TempData["Error"] = resp.FcMensaje;
        var vm = new TicketListaViewModel
        {
            Titulo = titulo,
            Modo = vista,
            Filtro = filtro,
            Items = resp.Datos,
            FjData = resp.FjData,
            Combos = await CombosAsync(ct),
            Vistas = resumen
        };
        return View("Index", vm);
    }

    [HttpGet]
    public async Task<IActionResult> Detalle(int id, CancellationToken ct)
    {
        var (det, acciones) = await _tickets.ObtenerAsync(id, UsuarioId, RolCodigo, ct);
        if (!det.Cabecera.FbSucces || det.Ticket == null)
        {
            TempData["Error"] = det.Cabecera.FcMensaje;
            return RedirectToAction(nameof(Index));
        }

        ViewData["Title"] = det.Ticket.FcNumero;
        LimitesAdjuntos();
        ViewBag.PuedeEvidencia = TicketServicio.PuedeCargarEvidencia(RolCodigo);
        if (string.Equals(det.Ticket.FcEstadoCodigo, EstadosTicket.Resuelto, StringComparison.OrdinalIgnoreCase))
        {
            // Aviso "si no responde en N días el ticket se cierra solo" (parámetro DIAS_CIERRE_AUTOMATICO).
            var par = await _catalogos.ParametroListarAsync(true, ct);
            var dias = par.FbSucces ? par.Datos.FirstOrDefault(p => p.FcClave == "DIAS_CIERRE_AUTOMATICO")?.FcValor : null;
            if (int.TryParse(dias, out var n) && n > 0) ViewBag.DiasCierreAutomatico = n;
        }
        if (TicketServicio.PuedeCambiarRecordatorioSla(RolCodigo))
            ViewBag.RecordatorioSla = await _tickets.ObtenerRecordatorioSlaAsync(id, ct);
        var adj =await _tickets.ListarAdjuntosAsync(id, null, UsuarioId, RolCodigo, ct);
        return View(new TicketDetalleViewModel
        {
            Ticket = det.Ticket,
            Historial = det.Historial,
            Materiales = det.Materiales,
            Encuesta = det.Encuesta,
            Comentarios = det.Comentarios,
            Acciones = acciones,
            Combos = await CombosAsync(ct),
            Adjuntos = adj.FbSucces ? adj.Datos : new List<AdjuntoModelo>()
        });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> CambiarEstado(int id, string estado, int? motivoEsperaId, string? comentario, CancellationToken ct)
    {
        var resp = await _tickets.CambiarEstadoAsync(id, estado, motivoEsperaId, comentario, UsuarioId, RolCodigo, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Asignar(int id, string tipoResponsable, int? tecnicoId, int? proveedorId,
        string? proveedorSapCodigo, string? proveedorSapNombre, DateTime? fechaProgramada, CancellationToken ct)
    {
        var resp = await _tickets.AsignarAsync(id, tipoResponsable, tecnicoId, proveedorId, proveedorSapCodigo, proveedorSapNombre, fechaProgramada, UsuarioId, RolCodigo, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    // Select2 AJAX: artículos SAP (OITM). Mín. 2 letras, máx. 30.
    // User: "Si la cadena no está configurada... 'SAP no está configurado'"
    [HttpGet]
    public async Task<IActionResult> BuscarArticulosSap(string? q, CancellationToken ct)
    {
        var r = await _sap.BuscarArticulosAsync(q, ct);
        if (!r.FbConfigurado)
            return Json(new { results = Array.Empty<object>(), error = r.FcMensaje ?? "SAP no está configurado" });
        var results = r.Datos.Select(a => new
        {
            id = a.FcCodigo,
            text = $"{a.FcCodigo} — {a.FcNombre} (stk {a.FnExistencia:0.##})",
            itemCode = a.FcCodigo,
            itemName = a.FcNombre,
            unidad = a.FcUnidad,
            existencia = a.FnExistencia,
            costo = a.FnCostoPromedio
        });
        return Json(new { results, error = r.FcMensaje });
    }

    // Select2 AJAX: proveedores SAP (OCRD CardType=S).
    [HttpGet]
    public async Task<IActionResult> BuscarProveedoresSap(string? q, CancellationToken ct)
    {
        var r = await _sap.BuscarProveedoresAsync(q, ct);
        if (!r.FbConfigurado)
            return Json(new { results = Array.Empty<object>(), error = r.FcMensaje ?? "SAP no está configurado" });
        var results = r.Datos.Select(p => new
        {
            id = p.FcCodigo,
            text = $"{p.FcCodigo} — {p.FcNombre}",
            cardCode = p.FcCodigo,
            cardName = p.FcNombre
        });
        return Json(new { results, error = r.FcMensaje });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> CambiarPrioridad(int id, int prioridadId, CancellationToken ct)
    {
        var resp = await _tickets.CambiarPrioridadAsync(id, prioridadId, UsuarioId, RolCodigo, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> GuardarEjecucion(
        int id, DateTime? fechaInicio, DateTime? fechaFin, decimal? horasTrabajadas,
        decimal? costoManoObra, decimal? costoProveedor, string? diagnostico, string? causaRaiz,
        string? trabajoRealizado, string? accionesPreventivas, CancellationToken ct)
    {
        var resp = await _tickets.GuardarEjecucionAsync(id, fechaInicio, fechaFin, horasTrabajadas, costoManoObra, costoProveedor,
            diagnostico, causaRaiz, trabajoRealizado, accionesPreventivas, UsuarioId, RolCodigo, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> GuardarMaterial(int id, int? materialId, string descripcion, decimal cantidad, string? unidad, decimal costoUnitario, string? codigoSap, CancellationToken ct)
    {
        var resp = await _tickets.GuardarMaterialAsync(materialId, id, descripcion, cantidad, unidad, costoUnitario, codigoSap, UsuarioId, RolCodigo, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> EliminarMaterial(int id, int materialId, CancellationToken ct)
    {
        var resp = await _tickets.EliminarMaterialAsync(materialId, id, UsuarioId, RolCodigo, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Encuesta(int id, int calificacion, bool conforme, string? comentario, CancellationToken ct)
    {
        var resp = await _tickets.GuardarEncuestaAsync(id, calificacion, conforme, comentario, UsuarioId, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    /// <summary>Activa o desactiva el recordatorio diario de SLA vencido (ADMIN, JEFATURA, MANTENIMIENTO).</summary>
    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> RecordatorioSla(int id, bool desactivar, CancellationToken ct)
    {
        var resp = await _tickets.CambiarRecordatorioSlaAsync(id, desactivar, UsuarioId, RolCodigo, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Comentario(int id, string comentario, bool interno = false, CancellationToken ct = default)
    {
        var resp = await _tickets.AgregarComentarioAsync(id, comentario, interno, UsuarioId, RolCodigo, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    [HttpPost, ValidateAntiForgeryToken, RequestSizeLimit(110_000_000)]
    public async Task<IActionResult> SubirAdjunto(int id, string etapa, IFormFile archivo, CancellationToken ct)
    {
        var resp = await _tickets.SubirAdjuntoAsync(id, etapa, archivo, UsuarioId, RolCodigo, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    private static int ExtraerId(string? fjData, string clave)
    {
        if (string.IsNullOrWhiteSpace(fjData)) return 0;
        try
        {
            using var doc = System.Text.Json.JsonDocument.Parse(fjData);
            if (doc.RootElement.TryGetProperty(clave, out var el))
            {
                if (el.ValueKind == System.Text.Json.JsonValueKind.Number && el.TryGetInt32(out var n)) return n;
                if (el.ValueKind == System.Text.Json.JsonValueKind.String && int.TryParse(el.GetString(), out var s)) return s;
            }
        }
        catch { /* ignore */ }
        return 0;
    }
}

using System.Security.Claims;
using FaraMantenimiento.Helpers;
using FaraMantenimiento.ViewModels.Tickets;
using FM.OrigenDatos.Modelos.Adjunto;
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
    private readonly AdjuntoServicio _adjuntos;

    public TicketsController(TicketServicio tickets, CatalogoServicio catalogos, AdjuntoServicio adjuntos)
    {
        _tickets = tickets;
        _catalogos = catalogos;
        _adjuntos = adjuntos;
    }

    private int UsuarioId => AppAccess.UsuarioId(User) ?? 0;
    private string? RolCodigo => User.FindFirstValue(ClaimTypes.Role);

    private async Task<FM.OrigenDatos.Modelos.Catalogos.CatalogoCombosModelo> CombosAsync(CancellationToken ct)
    {
        var (_, c) = await _catalogos.ObtenerCombosAsync(ct);
        return c;
    }

    [HttpGet, RequierePermiso(Pantallas.TicketCrear)]
    public async Task<IActionResult> Crear(CancellationToken ct)
    {
        ViewData["Title"] = "Nuevo ticket";
        ViewBag.Combos = await CombosAsync(ct);
        return View(new TicketCrearViewModel());
    }

    [HttpPost, ValidateAntiForgeryToken, RequierePermiso(Pantallas.TicketCrear)]
    public async Task<IActionResult> Crear(TicketCrearViewModel model, List<IFormFile>? adjuntos, CancellationToken ct)
    {
        ViewBag.Combos = await CombosAsync(ct);
        if (!ModelState.IsValid) return View(model);

        var resp = await _tickets.CrearAsync(UsuarioId, model.FiSucursalId, model.FiUbicacionId, model.FcUbicacionDetalle,
            model.FiActivoId, model.FiTipoMantenimientoId, model.FiCategoriaId, model.FiPrioridadId,
            model.FcDescripcion, model.FdFechaSugerida, ct);

        if (!resp.FbSucces)
        {
            ModelState.AddModelError(string.Empty, resp.FcMensaje);
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
        TempData["Ok"] = resp.FcMensaje;
        return id > 0 ? RedirectToAction(nameof(Detalle), new { id }) : RedirectToAction(nameof(Mios));
    }

    [HttpGet, RequierePermiso(Pantallas.TicketMios)]
    public Task<IActionResult> Mios(CancellationToken ct) =>
        ListaAsync("Mis tickets", "mios", new TicketFiltro { FiSolicitanteId = UsuarioId, FiPagina = 1, FiTamano = 50 }, ct);

    [HttpGet, RequierePermiso(Pantallas.TicketBandeja)]
    public Task<IActionResult> Bandeja(string? estado, CancellationToken ct) =>
        ListaAsync("Bandeja de mantenimiento", "bandeja", new TicketFiltro
        {
            FcEstadoCodigo = estado,
            FbSoloAbiertos = string.IsNullOrWhiteSpace(estado),
            FiPagina = 1,
            FiTamano = 50
        }, ct);

    [HttpGet, RequierePermiso(Pantallas.TicketAprobacion)]
    public Task<IActionResult> Aprobacion(CancellationToken ct) =>
        ListaAsync("Aprobación", "aprobacion", new TicketFiltro { FcEstadoCodigo = EstadosTicket.EnEvaluacion, FiPagina = 1, FiTamano = 50 }, ct);

    [HttpGet, RequierePermiso(Pantallas.TicketTodos)]
    public async Task<IActionResult> Index(TicketFiltro filtro, CancellationToken ct)
    {
        filtro.FiPagina = filtro.FiPagina <= 0 ? 1 : filtro.FiPagina;
        filtro.FiTamano = filtro.FiTamano <= 0 ? 20 : filtro.FiTamano;
        return await ListaAsync("Todos los tickets", "todos", filtro, ct);
    }

    private async Task<IActionResult> ListaAsync(string titulo, string modo, TicketFiltro filtro, CancellationToken ct)
    {
        ViewData["Title"] = titulo;
        var resp = await _tickets.ListarAsync(filtro, UsuarioId, RolCodigo, ct);
        var vm = new TicketListaViewModel
        {
            Titulo = titulo,
            Modo = modo,
            Filtro = filtro,
            Items = resp.Datos,
            FjData = resp.FjData,
            Combos = await CombosAsync(ct)
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
            return RedirectToAction(nameof(Mios));
        }

        ViewData["Title"] = det.Ticket.FcNumero;
        var adj = await _tickets.ListarAdjuntosAsync(id, null, UsuarioId, RolCodigo, ct);
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
    public async Task<IActionResult> Asignar(int id, string tipoResponsable, int? tecnicoId, int? proveedorId, DateTime? fechaProgramada, CancellationToken ct)
    {
        var resp = await _tickets.AsignarAsync(id, tipoResponsable, tecnicoId, proveedorId, fechaProgramada, UsuarioId, RolCodigo, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
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
    public async Task<IActionResult> GuardarMaterial(int id, int? materialId, string descripcion, decimal cantidad, string? unidad, decimal costoUnitario, CancellationToken ct)
    {
        var resp = await _tickets.GuardarMaterialAsync(materialId, id, descripcion, cantidad, unidad, costoUnitario, UsuarioId, RolCodigo, ct);
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

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Comentario(int id, string comentario, bool interno = false, CancellationToken ct = default)
    {
        var resp = await _tickets.AgregarComentarioAsync(id, comentario, interno, UsuarioId, RolCodigo, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    [HttpPost, ValidateAntiForgeryToken, RequestSizeLimit(110_000_000)]
    public async Task<IActionResult> SubirAdjunto(int id, string etapa, IFormFile archivo, CancellationToken ct)
    {
        var resp = await _tickets.SubirAdjuntoAsync(id, etapa, archivo, UsuarioId, RolCodigo, ct);        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
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

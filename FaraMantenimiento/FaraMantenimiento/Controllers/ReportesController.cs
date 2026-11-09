using FaraMantenimiento.Helpers;
using FaraMantenimiento.Models;
using FM.OrigenDatos.Modelos.Reportes;
using FM.Programacion.Constantes;
using FM.Programacion.Servicios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FaraMantenimiento.Controllers;

[Authorize]
[RequierePermiso(Pantallas.Reportes)]
public class ReportesController : Controller
{
    private readonly ReporteServicio _reportes;
    private readonly CatalogoServicio _catalogos;
    private readonly ExportacionServicio _exportacion;

    public ReportesController(ReporteServicio reportes, CatalogoServicio catalogos, ExportacionServicio exportacion)
    {
        _reportes = reportes;
        _catalogos = catalogos;
        _exportacion = exportacion;
    }

    [HttpGet]
    public async Task<IActionResult> Index(ReporteFiltroViewModel filtro, CancellationToken ct)
    {
        ViewData["Title"] = "Reportes";
        ViewData["SinTarjeta"] = true;
        filtro.FdDesde ??= DateTime.Today.AddMonths(-3);
        filtro.FdHasta ??= DateTime.Today;
        filtro.Pestana = string.IsNullOrWhiteSpace(filtro.Pestana) ? "resumen" : filtro.Pestana.ToLowerInvariant();

        var f = filtro.AFiltro();
        // Callers: Index reportes. Unificado a ObtenerCombosAsync (etapa 4 catálogos).
        var combos = await _catalogos.ObtenerCombosAsync(ct);
        ViewBag.Filtro = filtro;
        ViewBag.Combos = _catalogos.ACombosReporte(combos.Combos);
        ViewBag.Pestana = filtro.Pestana;

        switch (filtro.Pestana)
        {
            case "tiempos":
                ViewBag.Tiempos = (await _reportes.TiemposAsync(f, ct)).Datos;
                break;
            case "sla":
                ViewBag.Sla = (await _reportes.SlaAsync(f, ct)).Datos;
                break;
            case "tipo":
                ViewBag.Tipos = (await _reportes.TipoAsync(f, ct)).Datos;
                break;
            case "mtbf":
                var mtbf = await _reportes.MtbfAsync(f, ct);
                ViewBag.MtbfActivo = mtbf.PorActivo;
                ViewBag.MtbfSucursal = mtbf.PorSucursal;
                break;
            case "reincidencia":
                var re = await _reportes.ReincidenciaAsync(f, ct);
                ViewBag.ReincidenciaResumen = re.Resumen.FirstOrDefault();
                ViewBag.ReincidenciaDetalle = re.Detalle;
                break;
            case "costos":
                var co = await _reportes.CostosAsync(f, ct);
                ViewBag.CostosSucursal = co.PorSucursal;
                ViewBag.CostosCategoria = co.PorCategoria;
                ViewBag.CostosActivo = co.PorActivo;
                break;
            case "productividad":
                var pr = await _reportes.ProductividadAsync(f, ct);
                ViewBag.ProductividadTecnicos = pr.Tecnicos;
                ViewBag.ProductividadProveedores = pr.Proveedores;
                break;
            case "satisfaccion":
                var sa = await _reportes.SatisfaccionAsync(f, ct);
                ViewBag.SatisfaccionResumen = sa.Resumen.FirstOrDefault();
                ViewBag.SatisfaccionDetalle = sa.Detalle;
                break;
            case "tendencia":
                ViewBag.Tendencia = (await _reportes.TendenciaAsync(f, ct)).Datos;
                break;
            default:
                filtro.Pestana = "resumen";
                ViewBag.Pestana = "resumen";
                ViewBag.Resumen = (await _reportes.ResumenAsync(f, ct)).Datos.FirstOrDefault();
                break;
        }

        return View();
    }

    /// <summary>Callers: UI /Reportes/HojaVida/{id}. SP: sp_reporte_activo_hojavida. Permiso REPORTES.</summary>
    [HttpGet]
    public async Task<IActionResult> HojaVida(int? id, CancellationToken ct)
    {
        ViewData["Title"] = "Hoja de vida del activo";
        ViewData["SinTarjeta"] = true;
        var combos = await _catalogos.ObtenerCombosAsync(ct);
        ViewBag.Activos = _catalogos.ACombosReporte(combos.Combos).Activos;
        ViewBag.ActivoId = id;

        if (id is null or <= 0)
        {
            ViewBag.Activo = null;
            ViewBag.Tickets = new List<ActivoHojaVidaTicketModelo>();
            ViewBag.Totales = null;
            return View();
        }

        var r = await _reportes.HojaVidaAsync(id.Value, ct);
        if (!r.Cabecera.FbSucces)
        {
            TempData["Error"] = r.Cabecera.FcMensaje;
            ViewBag.Activo = null;
            ViewBag.Tickets = new List<ActivoHojaVidaTicketModelo>();
            ViewBag.Totales = null;
            return View();
        }

        ViewBag.Activo = r.Activo.FirstOrDefault();
        ViewBag.Tickets = r.Tickets;
        ViewBag.Totales = r.Totales.FirstOrDefault();
        return View();
    }

    /// <summary>Callers: botón Exportar PDF en HojaVida. Schema: ActivoHojaVida*.</summary>
    [HttpGet]
    public async Task<IActionResult> ExportarHojaVidaPdf(int id, CancellationToken ct)
    {
        if (id <= 0) return BadRequest();
        var r = await _reportes.HojaVidaAsync(id, ct);
        if (!r.Cabecera.FbSucces || r.Activo.Count == 0)
            return NotFound(r.Cabecera.FcMensaje);

        var activo = r.Activo[0];
        var bytes = _exportacion.PdfHojaVida(activo, r.Tickets, r.Totales.FirstOrDefault());
        return File(bytes, "application/pdf",
            $"hoja_vida_{activo.FcCodigo}_{DateTime.Now:yyyyMMdd}.pdf");
    }

    [HttpGet]
    public async Task<IActionResult> ExportarExcel(ReporteFiltroViewModel filtro, string indicador, CancellationToken ct)
    {
        var (titulo, cols, filas) = await ArmarTablaAsync(filtro, indicador, ct);
        var bytes = _exportacion.ExcelTabla(titulo, cols, filas);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            $"reporte_{indicador}_{DateTime.Now:yyyyMMdd}.xlsx");
    }

    [HttpGet]
    public async Task<IActionResult> ExportarPdf(ReporteFiltroViewModel filtro, string indicador, CancellationToken ct)
    {
        var (titulo, cols, filas) = await ArmarTablaAsync(filtro, indicador, ct);
        var sub = $"Del {ExportacionServicio.FormatoFecha(filtro.FdDesde)} al {ExportacionServicio.FormatoFecha(filtro.FdHasta)}";
        var bytes = _exportacion.PdfTabla(titulo, sub, cols, filas);
        return File(bytes, "application/pdf", $"reporte_{indicador}_{DateTime.Now:yyyyMMdd}.pdf");
    }

    private async Task<(string Titulo, IReadOnlyList<string> Cols, List<IReadOnlyList<string>> Filas)> ArmarTablaAsync(
        ReporteFiltroViewModel filtro, string indicador, CancellationToken ct)
    {
        filtro.FdDesde ??= DateTime.Today.AddMonths(-3);
        filtro.FdHasta ??= DateTime.Today;
        var f = filtro.AFiltro();
        indicador = (indicador ?? "resumen").ToLowerInvariant();

        switch (indicador)
        {
            case "tiempos":
            {
                var d = (await _reportes.TiemposAsync(f, ct)).Datos;
                return ("Tiempos de respuesta y solución (MTTR)",
                    new[] { "Prioridad", "Tickets", "Resp. (h)", "Solución (h)", "MTTR (h)" },
                    d.Select(x => (IReadOnlyList<string>)new[]
                    {
                        x.FcPrioridadNombre, x.FiTickets.ToString(),
                        x.FnHorasRespuestaPromedio?.ToString("0.##") ?? "-",
                        x.FnHorasSolucionPromedio?.ToString("0.##") ?? "-",
                        x.FnMttrHoras?.ToString("0.##") ?? "-"
                    }).ToList());
            }
            case "sla":
            {
                var d = (await _reportes.SlaAsync(f, ct)).Datos;
                return ("Cumplimiento de SLA por prioridad",
                    new[] { "Prioridad", "Tickets", "% Resp.", "% Solución" },
                    d.Select(x => (IReadOnlyList<string>)new[]
                    {
                        x.FcPrioridadNombre, x.FiTickets.ToString(),
                        (x.FnPctSlaRespuesta?.ToString("0.##") ?? "-") + "%",
                        (x.FnPctSlaSolucion?.ToString("0.##") ?? "-") + "%"
                    }).ToList());
            }
            case "costos":
            {
                var co = await _reportes.CostosAsync(f, ct);
                var all = co.PorSucursal.Concat(co.PorCategoria).Concat(co.PorActivo).ToList();
                return ("Costos",
                    new[] { "Agrupación", "Código", "Nombre", "Tickets", "Mano obra", "Materiales", "Proveedor", "Total" },
                    all.Select(x => (IReadOnlyList<string>)new[]
                    {
                        x.FcAgrupacion, x.FcCodigo, x.FcNombre, x.FiTickets.ToString(),
                        ExportacionServicio.FormatoMoneda(x.FnCostoManoObra),
                        ExportacionServicio.FormatoMoneda(x.FnCostoMateriales),
                        ExportacionServicio.FormatoMoneda(x.FnCostoProveedor),
                        ExportacionServicio.FormatoMoneda(x.FnCostoTotal)
                    }).ToList());
            }
            case "productividad":
            {
                var pr = await _reportes.ProductividadAsync(f, ct);
                var all = pr.Tecnicos.Concat(pr.Proveedores).ToList();
                return ("Productividad",
                    new[] { "Tipo", "Código", "Nombre", "Tickets", "Horas", "Solución prom. (h)" },
                    all.Select(x => (IReadOnlyList<string>)new[]
                    {
                        x.FcTipoResponsable, x.FcCodigo, x.FcNombre, x.FiTickets.ToString(),
                        x.FnHorasTrabajadas.ToString("0.##"),
                        x.FnHorasSolucionPromedio?.ToString("0.##") ?? "-"
                    }).ToList());
            }
            case "tendencia":
            {
                var d = (await _reportes.TendenciaAsync(f, ct)).Datos;
                return ("Tendencia mensual",
                    new[] { "Periodo", "Recibidos", "Cerrados", "Abiertos", "MTTR (h)" },
                    d.Select(x => (IReadOnlyList<string>)new[]
                    {
                        x.FcPeriodoEtiqueta, x.FiRecibidos.ToString(), x.FiCerrados.ToString(),
                        x.FiAbiertos.ToString(), x.FnMttrHoras?.ToString("0.##") ?? "-"
                    }).ToList());
            }
            default:
            {
                var r = (await _reportes.ResumenAsync(f, ct)).Datos.FirstOrDefault() ?? new ReporteResumenModelo();
                return ("Resumen de tickets",
                    new[] { "Indicador", "Valor" },
                    new List<IReadOnlyList<string>>
                    {
                        new[] { "Recibidos", r.FiRecibidos.ToString() },
                        new[] { "Abiertos", r.FiAbiertos.ToString() },
                        new[] { "Cerrados", r.FiCerrados.ToString() },
                        new[] { "Backlog", r.FiBacklog.ToString() },
                        new[] { "Reincidentes", r.FiReincidentes.ToString() },
                        new[] { "Resp. prom. (h)", r.FnHorasRespuestaPromedio?.ToString("0.##") ?? "-" },
                        new[] { "Solución prom. (h)", r.FnHorasSolucionPromedio?.ToString("0.##") ?? "-" },
                        new[] { "% SLA solución", (r.FnPctSlaSolucion?.ToString("0.##") ?? "-") + "%" },
                        new[] { "Satisfacción", r.FnSatisfaccionPromedio?.ToString("0.##") ?? "-" }
                    });
            }
        }
    }
}

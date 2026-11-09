using FaraMantenimiento.Helpers;
using FaraMantenimiento.Models;
using FM.Programacion.Constantes;
using FM.Programacion.Servicios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

namespace FaraMantenimiento.Controllers;

[Authorize]
[RequierePermiso(Pantallas.Dashboard)]
public class DashboardController : Controller
{
    private readonly ReporteServicio _reportes;
    private readonly CatalogoServicio _catalogos;

    public DashboardController(ReporteServicio reportes, CatalogoServicio catalogos)
    {
        _reportes = reportes;
        _catalogos = catalogos;
    }

    [HttpGet]
    public async Task<IActionResult> Index(ReporteFiltroViewModel filtro, CancellationToken ct)
    {
        ViewData["Title"] = "Dashboard";
        ViewData["SinTarjeta"] = true;
        filtro.FdDesde ??= DateTime.Today.AddMonths(-3);
        filtro.FdHasta ??= DateTime.Today;

        var f = filtro.AFiltro();
        var resumen = await _reportes.ResumenAsync(f, ct);
        var tendencia = await _reportes.TendenciaAsync(f, ct);
        var sla = await _reportes.SlaAsync(f, ct);
        var tipo = await _reportes.TipoAsync(f, ct);
        // Unificado a ObtenerCombosAsync (etapa 4); adapta a modelo legacy de Views/Reportes.
        var combos = await _catalogos.ObtenerCombosAsync(ct);

        ViewBag.Filtro = filtro;
        ViewBag.Combos = _catalogos.ACombosReporte(combos.Combos);
        ViewBag.Resumen = resumen.Datos.FirstOrDefault();
        ViewBag.TendenciaJson = JsonSerializer.Serialize(tendencia.Datos.Select(x => new
        {
            periodo = x.FcPeriodoEtiqueta,
            recibidos = x.FiRecibidos,
            cerrados = x.FiCerrados,
            mttr = x.FnMttrHoras
        }));
        ViewBag.SlaJson = JsonSerializer.Serialize(sla.Datos.Select(x => new
        {
            nombre = x.FcPrioridadNombre,
            pct = x.FnPctSlaSolucion ?? 0
        }));
        ViewBag.TipoJson = JsonSerializer.Serialize(tipo.Datos.Select(x => new
        {
            nombre = x.FcTipoNombre,
            tickets = x.FiTickets,
            preventivo = x.FbEsPreventivo
        }));

        if (!resumen.FbSucces) TempData["Error"] = resumen.FcMensaje;
        return View();
    }
}

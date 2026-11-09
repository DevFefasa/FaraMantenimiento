using FaraMantenimiento.Helpers;
using FaraMantenimiento.ViewModels.Preventivos;
using FM.Programacion.Constantes;
using FM.Programacion.Servicios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FaraMantenimiento.Controllers;

// Callers: UI rutas /Preventivos (menu lo agrega coordinador en _Sidebar)
// API: Index, Calendario, Obtener, Guardar, Activar, GenerarAhora con [RequierePermiso(PREVENTIVOS)]
// User instruction: "Web Controllers/PreventivosController + Views/Preventivos/**" ... "[RequierePermiso(\"PREVENTIVOS\")]"

[Authorize]
[RequierePermiso(Pantallas.Preventivos)]
public class PreventivosController : Controller
{
    private readonly PreventivoServicio _preventivos;
    private readonly CatalogoServicio _catalogos;

    public PreventivosController(PreventivoServicio preventivos, CatalogoServicio catalogos)
    {
        _preventivos = preventivos;
        _catalogos = catalogos;
    }

    private int UsuarioId => AppAccess.UsuarioId(User) ?? 0;

    private async Task<FM.OrigenDatos.Modelos.Catalogos.CatalogoCombosModelo> CombosAsync(CancellationToken ct)
    {
        var (_, c) = await _catalogos.ObtenerCombosAsync(ct);
        return c;
    }

    [HttpGet]
    public async Task<IActionResult> Index(int? sucursalId, CancellationToken ct)
    {
        ViewData["Title"] = "Planes preventivos";
        var resp = await _preventivos.ListarAsync(sucursalId, soloActivos: false, ct);
        var vm = new PreventivoListaViewModel
        {
            SucursalId = sucursalId,
            Planes = resp.Datos,
            Combos = await CombosAsync(ct)
        };
        return View(vm);
    }

    [HttpGet]
    public async Task<IActionResult> Calendario(int? anio, int? mes, int? sucursalId, CancellationToken ct)
    {
        var hoy = DateTime.Today;
        var y = anio ?? hoy.Year;
        var m = mes ?? hoy.Month;
        if (m < 1) { m = 12; y--; }
        if (m > 12) { m = 1; y++; }

        var desde = new DateTime(y, m, 1);
        var hasta = desde.AddMonths(1).AddDays(-1);

        ViewData["Title"] = "Calendario preventivo";
        var cal = await _preventivos.CalendarioAsync(desde, hasta, ct);
        var (cabCumpl, resumen, detalle) = await _preventivos.CumplimientoAsync(desde, hasta, sucursalId, ct);

        var vm = new PreventivoCalendarioViewModel
        {
            Anio = y,
            Mes = m,
            Desde = desde,
            Hasta = hasta,
            SucursalId = sucursalId,
            Eventos = cal.FbSucces ? cal.Datos : Array.Empty<FM.OrigenDatos.Modelos.Preventivos.PreventivoCalendarioItemModelo>(),
            Cumplimiento = cabCumpl.FbSucces ? resumen : new(),
            CumplimientoDetalle = cabCumpl.FbSucces ? detalle : new(),
            Combos = await CombosAsync(ct)
        };
        return View(vm);
    }

    [HttpGet]
    public async Task<IActionResult> Obtener(int id, CancellationToken ct)
    {
        var det = await _preventivos.ObtenerAsync(id, ct);
        if (!det.Cabecera.FbSucces || det.Plan == null)
            return Json(new { det.Cabecera.FiCodigo, det.Cabecera.FcMensaje, det.Cabecera.FbSucces });
        return Json(new { det.Cabecera.FiCodigo, det.Cabecera.FcMensaje, det.Cabecera.FbSucces, plan = det.Plan, ejecuciones = det.Ejecuciones });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Guardar(PreventivoGuardarViewModel model, CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return Json(new { FiCodigo = 400, FcMensaje = "Datos incompletos", FbSucces = false });

        var resp = await _preventivos.GuardarAsync(
            model.FiId, model.FcNombre, model.FiActivoId, model.FiSucursalId, model.FiUbicacionId,
            model.FiCategoriaId, model.FiPrioridadId, model.FcDescripcion, model.FiFrecuenciaDias,
            model.FdProximaFecha, model.FiDiasAnticipacion, model.FiTecnicoId, model.FiProveedorId,
            UsuarioId, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Activar(int id, bool activo, CancellationToken ct)
    {
        var resp = await _preventivos.ActivarAsync(id, activo, UsuarioId, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> GenerarAhora(CancellationToken ct)
    {
        var resp = await _preventivos.GenerarTicketsAsync(UsuarioId, DateTime.Today, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }
}

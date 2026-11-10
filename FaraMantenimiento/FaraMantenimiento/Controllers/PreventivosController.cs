using FaraMantenimiento.Helpers;
using FaraMantenimiento.ViewModels.Preventivos;
using FM.OrigenDatos.Modelos.Preventivos;
using FM.Programacion.Constantes;
using FM.Programacion.Servicios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FaraMantenimiento.Controllers;

// Callers: UI /Preventivos; Views/Preventivos/Index+Calendario+Formulario+_FormularioPlan; fara-modal.js
// API: Index, Calendario, Crear, Editar, Guardar, Activar, GenerarAhora
// Schema: PreventivoServicio; EsModal → PartialView/Json; EstadosLeyenda en Calendario
// Confirm: reescribe Controllers/PreventivosController.cs (ya existía)
// User instruction: "PREVENTIVOS: el usuario no puede hacer el CRUD de planes... mismo patron modal/pagina"

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
        var estados = (await _catalogos.EstadoListarAsync(true, ct)).Datos;

        var vm = new PreventivoCalendarioViewModel
        {
            Anio = y,
            Mes = m,
            Desde = desde,
            Hasta = hasta,
            SucursalId = sucursalId,
            Eventos = cal.FbSucces ? cal.Datos : Array.Empty<PreventivoCalendarioItemModelo>(),
            Cumplimiento = cabCumpl.FbSucces ? resumen : new(),
            CumplimientoDetalle = cabCumpl.FbSucces ? detalle : new(),
            Combos = await CombosAsync(ct),
            EstadosLeyenda = estados
        };
        return View(vm);
    }

    [HttpGet]
    public async Task<IActionResult> Crear(CancellationToken ct)
    {
        var vm = new PreventivoGuardarViewModel
        {
            FdProximaFecha = DateTime.Today.AddDays(7),
            FiFrecuenciaDias = 30,
            FiDiasAnticipacion = 7
        };
        ViewBag.Combos = await CombosAsync(ct);
        ViewData["Title"] = "Nuevo plan";
        return Request.EsModal() ? PartialView("_FormularioPlan", vm) : View("Formulario", vm);
    }

    [HttpGet]
    public async Task<IActionResult> Editar(int id, CancellationToken ct)
    {
        var det = await _preventivos.ObtenerAsync(id, ct);
        if (!det.Cabecera.FbSucces || det.Plan == null)
        {
            TempData["Error"] = det.Cabecera.FcMensaje ?? "Plan no encontrado";
            return RedirectToAction(nameof(Index));
        }

        var p = det.Plan;
        var vm = new PreventivoGuardarViewModel
        {
            FiId = p.FiId,
            FcNombre = p.FcNombre,
            FiActivoId = p.FiActivoId,
            FiSucursalId = p.FiSucursalId,
            FiUbicacionId = p.FiUbicacionId,
            FiCategoriaId = p.FiCategoriaId,
            FiPrioridadId = p.FiPrioridadId,
            FcDescripcion = p.FcDescripcion,
            FiFrecuenciaDias = p.FiFrecuenciaDias,
            FdProximaFecha = p.FdProximaFecha,
            FiDiasAnticipacion = p.FiDiasAnticipacion,
            FiTecnicoId = p.FiTecnicoId,
            FiProveedorId = p.FiProveedorId
        };
        ViewBag.Combos = await CombosAsync(ct);
        ViewData["Title"] = "Editar plan";
        return Request.EsModal() ? PartialView("_FormularioPlan", vm) : View("Formulario", vm);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Guardar(PreventivoGuardarViewModel model, CancellationToken ct)
    {
        if (!ModelState.IsValid)
        {
            if (Request.EsModal())
                return Json(new { FiCodigo = 400, FcMensaje = "Datos incompletos", FbSucces = false });
            ViewBag.Combos = await CombosAsync(ct);
            ViewData["Title"] = model.FiId is > 0 ? "Editar plan" : "Nuevo plan";
            return View("Formulario", model);
        }

        var resp = await _preventivos.GuardarAsync(
            model.FiId, model.FcNombre, model.FiActivoId, model.FiSucursalId, model.FiUbicacionId,
            model.FiCategoriaId, model.FiPrioridadId, model.FcDescripcion, model.FiFrecuenciaDias,
            model.FdProximaFecha, model.FiDiasAnticipacion, model.FiTecnicoId, model.FiProveedorId,
            UsuarioId, ct);

        if (Request.EsModal())
            return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });

        if (resp.FbSucces)
        {
            TempData["Exito"] = resp.FcMensaje;
            return RedirectToAction(nameof(Index));
        }

        TempData["Error"] = resp.FcMensaje;
        ViewBag.Combos = await CombosAsync(ct);
        ViewData["Title"] = model.FiId is > 0 ? "Editar plan" : "Nuevo plan";
        return View("Formulario", model);
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

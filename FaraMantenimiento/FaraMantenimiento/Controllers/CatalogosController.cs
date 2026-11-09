using FaraMantenimiento.Helpers;
using FM.Programacion.Constantes;
using FM.Programacion.Servicios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FaraMantenimiento.Controllers;

// Callers: UI /Catalogos (menu en _Sidebar lo agrega otro agente)
// API: Index, Entidad, Obtener, Guardar, Activar, PlantillaActivos, CargarActivos
// Schema: CRUD vía CatalogoServicio / sp_catalogo_*
// User instruction: "Web Controllers/CatalogosController + Views/Catalogos/**" + [RequierePermiso("CATALOGOS")]

[Authorize]
[RequierePermiso(Pantallas.Catalogos)]
public class CatalogosController : Controller
{
    private readonly CatalogoServicio _catalogos;

    public CatalogosController(CatalogoServicio catalogos) => _catalogos = catalogos;

    private int UsuarioId => AppAccess.UsuarioId(User) ?? 0;

    [HttpGet]
    public IActionResult Index()
    {
        ViewData["Title"] = "Catálogos";
        return View();
    }

    [HttpGet]
    public async Task<IActionResult> Entidad(string tipo, CancellationToken ct)
    {
        tipo = (tipo ?? "").Trim().ToLowerInvariant();
        var validos = new HashSet<string> { "regiones", "sucursales", "ubicaciones", "activos", "tipos", "categorias", "prioridades", "estados", "motivos", "proveedores", "tecnicos", "parametros" };
        if (!validos.Contains(tipo))
        {
            TempData["Error"] = "Catálogo no válido";
            return RedirectToAction(nameof(Index));
        }

        ViewData["Title"] = Titulo(tipo);
        ViewData["Tipo"] = tipo;
        ViewBag.Combos = (await _catalogos.ObtenerCombosAsync(ct)).Combos;

        object datos = tipo switch
        {
            "regiones" => (await _catalogos.RegionListarAsync(false, ct)).Datos,
            "sucursales" => (await _catalogos.SucursalListarAsync(false, null, ct)).Datos,
            "ubicaciones" => (await _catalogos.UbicacionListarAsync(false, null, ct)).Datos,
            "activos" => (await _catalogos.ActivoListarAsync(false, null, null, ct)).Datos,
            "tipos" => (await _catalogos.TipoListarAsync(false, ct)).Datos,
            "categorias" => (await _catalogos.CategoriaListarAsync(false, ct)).Datos,
            "prioridades" => (await _catalogos.PrioridadListarAsync(false, ct)).Datos,
            "estados" => (await _catalogos.EstadoListarAsync(false, ct)).Datos,
            "motivos" => (await _catalogos.MotivoListarAsync(false, ct)).Datos,
            "proveedores" => (await _catalogos.ProveedorListarAsync(false, ct)).Datos,
            "tecnicos" => (await _catalogos.TecnicoListarAsync(false, null, ct)).Datos,
            "parametros" => (await _catalogos.ParametroListarAsync(false, ct)).Datos,
            _ => Array.Empty<object>()
        };
        return View(datos);
    }

    [HttpGet]
    public async Task<IActionResult> Obtener(string tipo, int id, CancellationToken ct)
    {
        object? item = tipo?.ToLowerInvariant() switch
        {
            "regiones" => (await _catalogos.RegionObtenerAsync(id, ct)).Datos.FirstOrDefault(),
            "sucursales" => (await _catalogos.SucursalObtenerAsync(id, ct)).Datos.FirstOrDefault(),
            "ubicaciones" => (await _catalogos.UbicacionObtenerAsync(id, ct)).Datos.FirstOrDefault(),
            "activos" => (await _catalogos.ActivoObtenerAsync(id, ct)).Datos.FirstOrDefault(),
            "tipos" => (await _catalogos.TipoObtenerAsync(id, ct)).Datos.FirstOrDefault(),
            "categorias" => (await _catalogos.CategoriaObtenerAsync(id, ct)).Datos.FirstOrDefault(),
            "prioridades" => (await _catalogos.PrioridadObtenerAsync(id, ct)).Datos.FirstOrDefault(),
            "estados" => (await _catalogos.EstadoObtenerAsync(id, ct)).Datos.FirstOrDefault(),
            "motivos" => (await _catalogos.MotivoObtenerAsync(id, ct)).Datos.FirstOrDefault(),
            "proveedores" => (await _catalogos.ProveedorObtenerAsync(id, ct)).Datos.FirstOrDefault(),
            "tecnicos" => (await _catalogos.TecnicoObtenerAsync(id, ct)).Datos.FirstOrDefault(),
            "parametros" => (await _catalogos.ParametroObtenerAsync(id, ct)).Datos.FirstOrDefault(),
            _ => null
        };
        if (item == null) return Json(new { FiCodigo = 404, FcMensaje = "No encontrado", FbSucces = false });
        return Json(new { FiCodigo = 200, FcMensaje = "OK", FbSucces = true, item });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Guardar(string tipo, CancellationToken ct)
    {
        var f = Request.Form;
        int? id = int.TryParse(f["fiId"], out var i) && i > 0 ? i : null;
        var uid = UsuarioId;
        var resp = tipo?.ToLowerInvariant() switch
        {
            "regiones" => await _catalogos.RegionGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, uid, ct),
            "sucursales" => await _catalogos.SucursalGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, f["fcTipo"]!, int.Parse(f["fiRegionId"]!), f["fcDireccion"], f["fcTelefono"], uid, ct),
            "ubicaciones" => await _catalogos.UbicacionGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, int.Parse(f["fiSucursalId"]!), uid, ct),
            "activos" => await _catalogos.ActivoGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, f["fcMarca"], f["fcModelo"], f["fcSerie"],
                int.Parse(f["fiSucursalId"]!), ParseOpt(f["fiUbicacionId"]), ParseOpt(f["fiCategoriaId"]), ParseDate(f["fdFechaInstalacion"]), uid, ct),
            "tipos" => await _catalogos.TipoGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, Flag(f["fbRequiereAprobacion"]), Flag(f["fbEsPreventivo"]), Flag(f["fbEsPostFalla"]), Flag(f["fbRequiereFechaSugerida"]), ParseInt(f["fiOrden"]), uid, ct),
            "categorias" => await _catalogos.CategoriaGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, ParseInt(f["fiOrden"]), uid, ct),
            "prioridades" => await _catalogos.PrioridadGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, ParseInt(f["fiHorasRespuesta"]), ParseInt(f["fiHorasSolucion"]), f["fcColor"], ParseInt(f["fiOrden"]), uid, ct),
            "estados" => await _catalogos.EstadoGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, ParseInt(f["fiOrden"]), f["fcColor"], Flag(f["fbFinal"]), uid, ct),
            "motivos" => await _catalogos.MotivoGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, ParseInt(f["fiOrden"]), uid, ct),
            "proveedores" => await _catalogos.ProveedorGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, f["fcRtn"], f["fcContacto"], f["fcTelefono"], f["fcCorreo"], f["fcEspecialidad"], uid, ct),
            "tecnicos" => await _catalogos.TecnicoGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, ParseOpt(f["fiUsuarioId"]), f["fcTelefono"], ParseOpt(f["fiCategoriaId"]), uid, ct),
            "parametros" => await _catalogos.ParametroGuardarAsync(id, f["fcClave"]!, f["fcValor"]!, f["fcDescripcion"], uid, ct),
            _ => new FM.OrigenDatos.Conexion.RespuestaSp { FiCodigo = 400, FcMensaje = "Catálogo no válido", FbSucces = false }
        };
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Activar(string tipo, int id, bool activo, CancellationToken ct)
    {
        var uid = UsuarioId;
        var resp = tipo?.ToLowerInvariant() switch
        {
            "regiones" => await _catalogos.RegionActivarAsync(id, activo, uid, ct),
            "sucursales" => await _catalogos.SucursalActivarAsync(id, activo, uid, ct),
            "ubicaciones" => await _catalogos.UbicacionActivarAsync(id, activo, uid, ct),
            "activos" => await _catalogos.ActivoActivarAsync(id, activo, uid, ct),
            "tipos" => await _catalogos.TipoActivarAsync(id, activo, uid, ct),
            "categorias" => await _catalogos.CategoriaActivarAsync(id, activo, uid, ct),
            "prioridades" => await _catalogos.PrioridadActivarAsync(id, activo, uid, ct),
            "estados" => await _catalogos.EstadoActivarAsync(id, activo, uid, ct),
            "motivos" => await _catalogos.MotivoActivarAsync(id, activo, uid, ct),
            "proveedores" => await _catalogos.ProveedorActivarAsync(id, activo, uid, ct),
            "tecnicos" => await _catalogos.TecnicoActivarAsync(id, activo, uid, ct),
            "parametros" => await _catalogos.ParametroActivarAsync(id, activo, uid, ct),
            _ => new FM.OrigenDatos.Conexion.RespuestaSp { FiCodigo = 400, FcMensaje = "Catálogo no válido", FbSucces = false }
        };
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    [HttpGet]
    public IActionResult PlantillaActivos()
    {
        var bytes = _catalogos.PlantillaActivosExcel();
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "plantilla_activos.xlsx");
    }

    [HttpPost, ValidateAntiForgeryToken, RequestSizeLimit(20_000_000)]
    public async Task<IActionResult> CargarActivos(IFormFile archivo, CancellationToken ct)
    {
        var resp = await _catalogos.CargarActivosExcelAsync(archivo, UsuarioId, ct);
        return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });
    }

    private static string Titulo(string tipo) => tipo switch
    {
        "regiones" => "Regiones",
        "sucursales" => "Sucursales / áreas / departamentos",
        "ubicaciones" => "Ubicaciones",
        "activos" => "Activos",
        "tipos" => "Tipos de mantenimiento",
        "categorias" => "Categorías",
        "prioridades" => "Prioridades",
        "estados" => "Estados",
        "motivos" => "Motivos de espera",
        "proveedores" => "Proveedores",
        "tecnicos" => "Técnicos",
        "parametros" => "Parámetros",
        _ => "Catálogo"
    };

    private static bool Flag(string? v) => string.Equals(v, "true", StringComparison.OrdinalIgnoreCase) || v == "1" || v == "on";
    private static int ParseInt(string? v) => int.TryParse(v, out var n) ? n : 0;
    private static int? ParseOpt(string? v) => int.TryParse(v, out var n) && n > 0 ? n : null;
    private static DateTime? ParseDate(string? v) => DateTime.TryParse(v, out var d) ? d.Date : null;
}

using FaraMantenimiento.Helpers;
using FaraMantenimiento.ViewModels.Catalogos;
using FM.OrigenDatos.Modelos.Catalogos;
using FM.Programacion.Constantes;
using FM.Programacion.Servicios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FaraMantenimiento.Controllers;

// Callers: UI /Catalogos; Views/Catalogos/Entidad+Formulario+_FormularioCatalogo; fara-modal.js
// API: Index, Entidad, Crear, Editar, Guardar, Activar, PlantillaActivos, CargarActivos
// Schema: sp_catalogo_* via CatalogoServicio; EsModal → Partial/Json
// Confirm: archivo existente Controllers/CatalogosController.cs (reescritura, no duplicado)
// User instruction: "CATALOGOS NO FUNCIONAN... Corrigelo... patron modal-en-PC / pagina-en-telefono... Request.EsModal()"

[Authorize]
[RequierePermiso(Pantallas.Catalogos)]
public class CatalogosController : Controller
{
    private static readonly HashSet<string> TiposValidos = new(StringComparer.OrdinalIgnoreCase)
    {
        // User instruction: "agrega Áreas y Departamentos al módulo Catálogos"
        "regiones", "sucursales", "areas", "departamentos", "ubicaciones", "activos", "tipos", "categorias",
        "prioridades", "estados", "motivos", "proveedores", "tecnicos", "parametros"
    };

    // Callers: DI; Views/Catalogos/_FormularioCatalogo tecnicos
    // API: ViewBag.UsuariosSistema; tecnico.fiUsuarioId vía sp_catalogo_tecnico_guardar
    // User instruction: "Agrega al formulario un select Usuario del sistema (opcional, usuarios activos)"
    private readonly CatalogoServicio _catalogos;
    private readonly SeguridadServicio _seguridad;

    public CatalogosController(CatalogoServicio catalogos, SeguridadServicio seguridad)
    {
        _catalogos = catalogos;
        _seguridad = seguridad;
    }

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
        tipo = NormalizarTipo(tipo);
        if (tipo == null)
        {
            TempData["Error"] = "Catálogo no válido";
            return RedirectToAction(nameof(Index));
        }

        ViewData["Title"] = Titulo(tipo);
        ViewData["Tipo"] = tipo;

        object datos = tipo switch
        {
            "regiones" => (await _catalogos.RegionListarAsync(false, ct)).Datos,
            "sucursales" => (await _catalogos.SucursalListarAsync(false, null, ct)).Datos,
            "areas" => (await _catalogos.AreaListarAsync(false, ct)).Datos,
            "departamentos" => (await _catalogos.DepartamentoListarAsync(false, null, ct)).Datos,
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
    public async Task<IActionResult> Crear(string tipo, CancellationToken ct)
    {
        tipo = NormalizarTipo(tipo);
        if (tipo == null) return BadRequest("Catálogo no válido");
        if (tipo == "estados")
        {
            TempData["Error"] = "Los estados solo se pueden editar";
            return RedirectToAction(nameof(Entidad), new { tipo });
        }

        var vm = await ConstruirFormularioAsync(tipo, null, ct);
        return Request.EsModal() ? PartialView("_FormularioCatalogo", vm) : View("Formulario", vm);
    }

    [HttpGet]
    public async Task<IActionResult> Editar(string tipo, int id, CancellationToken ct)
    {
        tipo = NormalizarTipo(tipo);
        if (tipo == null || id <= 0) return BadRequest("Catálogo no válido");

        var vm = await ConstruirFormularioAsync(tipo, id, ct);
        if (vm.FiId <= 0)
        {
            TempData["Error"] = "Registro no encontrado";
            return RedirectToAction(nameof(Entidad), new { tipo });
        }

        return Request.EsModal() ? PartialView("_FormularioCatalogo", vm) : View("Formulario", vm);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Guardar(string tipo, CancellationToken ct)
    {
        tipo = NormalizarTipo(tipo) ?? "";
        var f = Request.Form;
        int? id = int.TryParse(f["fiId"], out var i) && i > 0 ? i : null;
        var uid = UsuarioId;

        var resp = tipo switch
        {
            "regiones" => await _catalogos.RegionGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, uid, ct),
            "sucursales" => await _catalogos.SucursalGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, f["fcTipo"]!, ParseInt(f["fiRegionId"]), f["fcDireccion"], f["fcTelefono"], uid, ct),
            "areas" => await _catalogos.AreaGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, uid, ct),
            "departamentos" => await _catalogos.DepartamentoGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, ParseInt(f["fiAreaId"]), uid, ct),
            "ubicaciones" => await _catalogos.UbicacionGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, ParseInt(f["fiSucursalId"]), uid, ct),
            "activos" => await _catalogos.ActivoGuardarAsync(id, f["fcCodigo"]!, f["fcNombre"]!, f["fcMarca"], f["fcModelo"], f["fcSerie"],
                ParseInt(f["fiSucursalId"]), ParseOpt(f["fiUbicacionId"]), ParseOpt(f["fiCategoriaId"]), ParseDate(f["fdFechaInstalacion"]), uid, ct),
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

        if (Request.EsModal())
            return Json(new { resp.FiCodigo, resp.FcMensaje, resp.FbSucces, resp.FjData });

        if (resp.FbSucces)
        {
            TempData["Exito"] = resp.FcMensaje;
            return RedirectToAction(nameof(Entidad), new { tipo });
        }

        TempData["Error"] = resp.FcMensaje;
        var vm = await ConstruirFormularioAsync(tipo, id, ct);
        RellenarDesdeForm(vm, f);
        return View("Formulario", vm);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Activar(string tipo, int id, bool activo, CancellationToken ct)
    {
        tipo = NormalizarTipo(tipo) ?? "";
        var uid = UsuarioId;
        var resp = tipo switch
        {
            "regiones" => await _catalogos.RegionActivarAsync(id, activo, uid, ct),
            "sucursales" => await _catalogos.SucursalActivarAsync(id, activo, uid, ct),
            "areas" => await _catalogos.AreaActivarAsync(id, activo, uid, ct),
            "departamentos" => await _catalogos.DepartamentoActivarAsync(id, activo, uid, ct),
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

    private async Task<CatalogoFormViewModel> ConstruirFormularioAsync(string tipo, int? id, CancellationToken ct)
    {
        var combos = (await _catalogos.ObtenerCombosAsync(ct)).Combos;
        var vm = new CatalogoFormViewModel
        {
            Tipo = tipo,
            Titulo = id is > 0 ? $"Editar · {Titulo(tipo)}" : $"Nuevo · {Titulo(tipo)}",
            Combos = combos
        };

        // User instruction: "select Usuario del sistema (opcional, usuarios activos)"
        if (tipo == "tecnicos")
        {
            var usuarios = await _seguridad.ListarUsuariosAsync(soloActivos: true, ct);
            ViewBag.UsuariosSistema = (usuarios.Datos ?? new List<FM.OrigenDatos.Modelos.Seguridad.UsuarioModelo>())
                .OrderBy(u => u.FcNombre)
                .ToList();
        }

        if (id is null or <= 0) return vm;

        switch (tipo)
        {
            case "regiones":
                MapRegion(vm, (await _catalogos.RegionObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
            case "sucursales":
                MapSucursal(vm, (await _catalogos.SucursalObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
            case "areas":
                MapArea(vm, (await _catalogos.AreaObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
            case "departamentos":
                MapDepartamento(vm, (await _catalogos.DepartamentoObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
            case "ubicaciones":
                MapUbicacion(vm, (await _catalogos.UbicacionObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
            case "activos":
                MapActivo(vm, (await _catalogos.ActivoObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
            case "tipos":
                MapTipo(vm, (await _catalogos.TipoObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
            case "categorias":
                MapCategoria(vm, (await _catalogos.CategoriaObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
            case "prioridades":
                MapPrioridad(vm, (await _catalogos.PrioridadObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
            case "estados":
                MapEstado(vm, (await _catalogos.EstadoObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
            case "motivos":
                MapMotivo(vm, (await _catalogos.MotivoObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
            case "proveedores":
                MapProveedor(vm, (await _catalogos.ProveedorObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
            case "tecnicos":
                MapTecnico(vm, (await _catalogos.TecnicoObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
            case "parametros":
                MapParametro(vm, (await _catalogos.ParametroObtenerAsync(id.Value, ct)).Datos.FirstOrDefault());
                break;
        }

        return vm;
    }

    private static void MapRegion(CatalogoFormViewModel vm, RegionModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcCodigo = x.FcCodigo; vm.FcNombre = x.FcNombre;
    }
    private static void MapArea(CatalogoFormViewModel vm, AreaModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcCodigo = x.FcCodigo; vm.FcNombre = x.FcNombre;
    }
    private static void MapDepartamento(CatalogoFormViewModel vm, DepartamentoModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcCodigo = x.FcCodigo; vm.FcNombre = x.FcNombre; vm.FiAreaId = x.FiAreaId;
    }
    private static void MapSucursal(CatalogoFormViewModel vm, SucursalModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcCodigo = x.FcCodigo; vm.FcNombre = x.FcNombre; vm.FcTipo = x.FcTipo;
        vm.FiRegionId = x.FiRegionId; vm.FcDireccion = x.FcDireccion; vm.FcTelefono = x.FcTelefono;
    }
    private static void MapUbicacion(CatalogoFormViewModel vm, UbicacionModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcCodigo = x.FcCodigo; vm.FcNombre = x.FcNombre; vm.FiSucursalId = x.FiSucursalId;
    }
    private static void MapActivo(CatalogoFormViewModel vm, ActivoModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcCodigo = x.FcCodigo; vm.FcNombre = x.FcNombre;
        vm.FcMarca = x.FcMarca; vm.FcModelo = x.FcModelo; vm.FcSerie = x.FcSerie;
        vm.FiSucursalId = x.FiSucursalId; vm.FiUbicacionId = x.FiUbicacionId; vm.FiCategoriaId = x.FiCategoriaId;
        vm.FdFechaInstalacion = x.FdFechaInstalacion;
    }
    private static void MapTipo(CatalogoFormViewModel vm, TipoMantenimientoModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcCodigo = x.FcCodigo; vm.FcNombre = x.FcNombre; vm.FiOrden = x.FiOrden;
        vm.FbRequiereAprobacion = x.FbRequiereAprobacion; vm.FbEsPreventivo = x.FbEsPreventivo;
        vm.FbEsPostFalla = x.FbEsPostFalla; vm.FbRequiereFechaSugerida = x.FbRequiereFechaSugerida;
    }
    private static void MapCategoria(CatalogoFormViewModel vm, CategoriaModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcCodigo = x.FcCodigo; vm.FcNombre = x.FcNombre; vm.FiOrden = x.FiOrden;
    }
    private static void MapPrioridad(CatalogoFormViewModel vm, PrioridadModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcCodigo = x.FcCodigo; vm.FcNombre = x.FcNombre;
        vm.FiHorasRespuesta = x.FiHorasRespuesta; vm.FiHorasSolucion = x.FiHorasSolucion;
        vm.FcColor = x.FcColor; vm.FiOrden = x.FiOrden;
    }
    private static void MapEstado(CatalogoFormViewModel vm, EstadoModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcCodigo = x.FcCodigo; vm.FcNombre = x.FcNombre;
        vm.FiOrden = x.FiOrden; vm.FcColor = x.FcColor; vm.FbFinal = x.FbFinal;
    }
    private static void MapMotivo(CatalogoFormViewModel vm, MotivoEsperaModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcCodigo = x.FcCodigo; vm.FcNombre = x.FcNombre; vm.FiOrden = x.FiOrden;
    }
    private static void MapProveedor(CatalogoFormViewModel vm, ProveedorModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcCodigo = x.FcCodigo; vm.FcNombre = x.FcNombre;
        vm.FcRtn = x.FcRtn; vm.FcContacto = x.FcContacto; vm.FcTelefono = x.FcTelefono;
        vm.FcCorreo = x.FcCorreo; vm.FcEspecialidad = x.FcEspecialidad;
    }
    private static void MapTecnico(CatalogoFormViewModel vm, TecnicoModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcCodigo = x.FcCodigo; vm.FcNombre = x.FcNombre;
        vm.FiUsuarioId = x.FiUsuarioId; vm.FcTelefono = x.FcTelefono; vm.FiCategoriaId = x.FiCategoriaId;
    }
    private static void MapParametro(CatalogoFormViewModel vm, ParametroModelo? x)
    {
        if (x == null) return;
        vm.FiId = x.FiId; vm.FcClave = x.FcClave; vm.FcValor = x.FcValor; vm.FcDescripcion = x.FcDescripcion;
    }

    private static void RellenarDesdeForm(CatalogoFormViewModel vm, IFormCollection f)
    {
        vm.FcCodigo = f["fcCodigo"];
        vm.FcNombre = f["fcNombre"];
        vm.FcClave = f["fcClave"];
        vm.FcValor = f["fcValor"];
        vm.FcDescripcion = f["fcDescripcion"];
        vm.FcTipo = f["fcTipo"];
        vm.FcDireccion = f["fcDireccion"];
        vm.FcTelefono = f["fcTelefono"];
        vm.FcColor = f["fcColor"];
        vm.FcRtn = f["fcRtn"];
        vm.FcContacto = f["fcContacto"];
        vm.FcCorreo = f["fcCorreo"];
        vm.FcEspecialidad = f["fcEspecialidad"];
        vm.FcMarca = f["fcMarca"];
        vm.FcModelo = f["fcModelo"];
        vm.FcSerie = f["fcSerie"];
        vm.FiRegionId = ParseOpt(f["fiRegionId"]);
        vm.FiAreaId = ParseOpt(f["fiAreaId"]);
        vm.FiSucursalId = ParseOpt(f["fiSucursalId"]);
        vm.FiUbicacionId = ParseOpt(f["fiUbicacionId"]);
        vm.FiCategoriaId = ParseOpt(f["fiCategoriaId"]);
        vm.FiUsuarioId = ParseOpt(f["fiUsuarioId"]);
        vm.FiOrden = ParseInt(f["fiOrden"]);
        vm.FiHorasRespuesta = ParseInt(f["fiHorasRespuesta"]);
        vm.FiHorasSolucion = ParseInt(f["fiHorasSolucion"]);
        vm.FdFechaInstalacion = ParseDate(f["fdFechaInstalacion"]);
        vm.FbFinal = Flag(f["fbFinal"]);
        vm.FbRequiereAprobacion = Flag(f["fbRequiereAprobacion"]);
        vm.FbEsPreventivo = Flag(f["fbEsPreventivo"]);
        vm.FbEsPostFalla = Flag(f["fbEsPostFalla"]);
        vm.FbRequiereFechaSugerida = Flag(f["fbRequiereFechaSugerida"]);
    }

    private static string? NormalizarTipo(string? tipo)
    {
        tipo = (tipo ?? "").Trim().ToLowerInvariant();
        return TiposValidos.Contains(tipo) ? tipo : null;
    }

    private static string Titulo(string tipo) => tipo switch
    {
        "regiones" => "Regiones",
        "sucursales" => "Sucursales",
        "areas" => "Áreas",
        "departamentos" => "Departamentos",
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

// Callers: menú Seguridad; Views/Seguridad/*
// API: /Seguridad, /Seguridad/Roles, /Seguridad/Pantallas (+ CRUD modal)
// User instruction: Controllers/SeguridadController.cs + URLs fijas + modal PC/teléfono
using FaraMantenimiento.Helpers;
using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Seguridad;
using FM.Programacion.Constantes;
using FM.Programacion.Servicios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FaraMantenimiento.Controllers;

[Authorize]
// Callers: menú Seguridad. Fix: método Pantallas() sombreaba Constantes.Pantallas en el atributo.
// User instruction (cursor1): "dotnet build ... sin errores" — califica constante para compilar.
[RequierePermiso(FM.Programacion.Constantes.Pantallas.Seguridad)]
public class SeguridadController : Controller

{
    private readonly SeguridadServicio _seguridad;
    private readonly CatalogoServicio _catalogos;

    // Callers: Views/Seguridad/_FormularioUsuario (combos sucursal/área/depto)
    // User instruction: "campos Sucursal, Área y Departamento en _FormularioUsuario.cshtml"
    public SeguridadController(SeguridadServicio seguridad, CatalogoServicio catalogos)
    {
        _seguridad = seguridad;
        _catalogos = catalogos;
    }

    private int ActorId => AppAccess.UsuarioId(User) ?? 0;

    private IActionResult Respuesta(RespuestaSp resp, string redirectAction, object? routeValues = null)
    {
        if (Request.EsModal())
            return Json(resp);
        TempData[resp.FbSucces ? "Exito" : "Error"] = resp.FcMensaje;
        return RedirectToAction(redirectAction, routeValues);
    }

    [HttpGet]
    public async Task<IActionResult> Index()
    {
        ViewData["Title"] = "Usuarios";
        ViewData["SeguridadTab"] = "usuarios";
        var usuarios = await _seguridad.ListarUsuariosAsync(soloActivos: false);
        return View(usuarios.Datos);
    }

    // Callers: Views/Seguridad/_FormularioUsuario; menu Seguridad
    // API: GET/POST /Seguridad/Usuario; ViewBag.UsuariosJefe; form fiJefeId
    // Schema: usuario.fiJefeId → FcJefeNombre via sp_seguridad_usuario_*
    // User instruction: "select2 Jefe inmediato (opcional, usuarios activos, sin el propio usuario)"
    [HttpGet]
    public async Task<IActionResult> Usuario(int? id)
    {
        ViewData["Title"] = id is > 0 ? "Editar usuario" : "Nuevo usuario";
        var roles = await _seguridad.ListarRolesAsync();
        ViewBag.Roles = roles.Datos ?? new List<RolModelo>();
        var (_, combos) = await _catalogos.ObtenerCombosAsync();
        ViewBag.Combos = combos;
        UsuarioModelo modelo;
        if (id is > 0)
        {
            var resp = await _seguridad.ObtenerUsuarioAsync(id.Value);
            if (!resp.FbSucces || resp.Datos.FirstOrDefault() is not { } u)
            {
                TempData["Error"] = resp.FcMensaje;
                return RedirectToAction(nameof(Index));
            }
            modelo = u;
        }
        else
        {
            modelo = new UsuarioModelo { FbActivo = true };
        }

        var usuarios = await _seguridad.ListarUsuariosAsync(soloActivos: true);
        ViewBag.UsuariosJefe = (usuarios.Datos ?? new List<UsuarioModelo>())
            .Where(x => x.FiId != modelo.FiId)
            .OrderBy(x => x.FcNombre)
            .ToList();

        if (Request.EsModal())
            return PartialView("_FormularioUsuario", modelo);
        return View(modelo);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Usuario(
        int? fiId, string fcUsuario, string? fcActiveDirectory, string fcNombre, string? fcCorreo, string? fcTelefono,
        int fiRolId, int? fiSucursalId, int? fiAreaId, int? fiDepartamentoId, int? fiJefeId, string? contrasenaNueva)
    {
        var resp = await _seguridad.GuardarUsuarioAsync(
            fiId, fcUsuario, fcActiveDirectory, fcNombre, fcCorreo, fcTelefono, fiRolId, fiSucursalId, fiAreaId, fiDepartamentoId, fiJefeId, contrasenaNueva, ActorId);
        if (!resp.FbSucces && !Request.EsModal())
        {
            TempData["Error"] = resp.FcMensaje;
            return RedirectToAction(nameof(Usuario), new { id = fiId });
        }
        return Respuesta(resp, nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> ActivarUsuario(int id, bool activo)
    {
        var resp = await _seguridad.ActivarUsuarioAsync(id, activo, ActorId);
        return Respuesta(resp, nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Roles()
    {
        ViewData["Title"] = "Roles";
        ViewData["SeguridadTab"] = "roles";
        var roles = await _seguridad.ListarRolesAsync(soloActivos: false);
        return View(roles.Datos);
    }

    [HttpGet]
    public async Task<IActionResult> Rol(int? id)
    {
        ViewData["Title"] = id is > 0 ? "Editar rol" : "Nuevo rol";
        RolModelo modelo;
        if (id is > 0)
        {
            var resp = await _seguridad.ObtenerRolAsync(id.Value);
            if (!resp.FbSucces || resp.Datos.FirstOrDefault() is not { } r)
            {
                TempData["Error"] = resp.FcMensaje;
                return RedirectToAction(nameof(Roles));
            }
            modelo = r;
        }
        else
        {
            modelo = new RolModelo { FbActivo = true };
        }

        if (Request.EsModal())
            return PartialView("_FormularioRol", modelo);
        return View(modelo);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Rol(int? fiId, string fcCodigo, string fcNombre, string? fcDescripcion)
    {
        var resp = await _seguridad.GuardarRolAsync(fiId, fcCodigo, fcNombre, fcDescripcion, ActorId);
        if (!resp.FbSucces && !Request.EsModal())
        {
            TempData["Error"] = resp.FcMensaje;
            return RedirectToAction(nameof(Rol), new { id = fiId });
        }
        return Respuesta(resp, nameof(Roles));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> ActivarRol(int id, bool activo)
    {
        var resp = await _seguridad.ActivarRolAsync(id, activo, ActorId);
        return Respuesta(resp, nameof(Roles));
    }

    [HttpGet]
    public async Task<IActionResult> RolPermisos(int id)
    {
        ViewData["Title"] = "Permisos del rol";
        ViewData["SeguridadTab"] = "roles";
        var (cab, rol, pantallas) = await _seguridad.ObtenerRolPermisosAsync(id);
        if (!cab.FbSucces || rol.FirstOrDefault() is not { } r)
        {
            TempData["Error"] = cab.FcMensaje;
            return RedirectToAction(nameof(Roles));
        }
        ViewBag.Rol = r;
        return View(pantallas);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> RolPermisos(int id, string[]? pantallas)
    {
        var resp = await _seguridad.GuardarRolPermisosAsync(id, pantallas ?? Array.Empty<string>(), ActorId);
        TempData[resp.FbSucces ? "Exito" : "Error"] = resp.FcMensaje;
        return RedirectToAction(nameof(RolPermisos), new { id });
    }

    [HttpGet]
    public async Task<IActionResult> Pantallas()
    {
        ViewData["Title"] = "Permisos (pantallas)";
        ViewData["SeguridadTab"] = "pantallas";
        var lista = await _seguridad.ListarPantallasAsync(soloActivos: false);
        return View(lista.Datos);
    }

    [HttpGet]
    public async Task<IActionResult> Pantalla(int? id)
    {
        ViewData["Title"] = id is > 0 ? "Editar pantalla" : "Nueva pantalla";
        PantallaModelo modelo;
        if (id is > 0)
        {
            var resp = await _seguridad.ObtenerPantallaAsync(id.Value);
            if (!resp.FbSucces || resp.Datos.FirstOrDefault() is not { } p)
            {
                TempData["Error"] = resp.FcMensaje;
                return RedirectToAction(nameof(Pantallas));
            }
            modelo = p;
        }
        else
        {
            modelo = new PantallaModelo { FbActivo = true };
        }

        ViewBag.EsProtegida = FM.Programacion.Constantes.Pantallas.EsProtegida(modelo.FcCodigo);
        if (Request.EsModal())
            return PartialView("_FormularioPantalla", modelo);
        return View(modelo);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Pantalla(int? fiId, string fcCodigo, string fcNombre, string? fcDescripcion, int fiOrden)
    {
        var resp = await _seguridad.GuardarPantallaAsync(fiId, fcCodigo, fcNombre, fcDescripcion, fiOrden, ActorId);
        if (!resp.FbSucces && !Request.EsModal())
        {
            TempData["Error"] = resp.FcMensaje;
            return RedirectToAction(nameof(Pantalla), new { id = fiId });
        }
        return Respuesta(resp, nameof(Pantallas));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> ActivarPantalla(int id, bool activo)
    {
        var resp = await _seguridad.ActivarPantallaAsync(id, activo, ActorId);
        return Respuesta(resp, nameof(Pantallas));
    }
}

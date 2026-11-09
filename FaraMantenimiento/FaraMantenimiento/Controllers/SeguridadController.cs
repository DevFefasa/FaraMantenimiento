using FaraMantenimiento.Helpers;
using FM.Programacion.Constantes;
using FM.Programacion.Servicios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FaraMantenimiento.Controllers;

[Authorize]
[RequierePermiso(Pantallas.Seguridad)]
public class SeguridadController : Controller
{
    private readonly SeguridadServicio _seguridad;

    public SeguridadController(SeguridadServicio seguridad) => _seguridad = seguridad;

    [HttpGet]
    public async Task<IActionResult> Index()
    {
        ViewData["Title"] = "Usuarios";
        var usuarios = await _seguridad.ListarUsuariosAsync(soloActivos: false);
        var roles = await _seguridad.ListarRolesAsync();
        ViewBag.Roles = roles.Datos;
        return View(usuarios.Datos);
    }

    [HttpGet]
    public async Task<IActionResult> Usuario(int? id)
    {
        ViewData["Title"] = id is > 0 ? "Editar usuario" : "Nuevo usuario";
        var roles = await _seguridad.ListarRolesAsync();
        ViewBag.Roles = roles.Datos;
        if (id is > 0)
        {
            var resp = await _seguridad.ObtenerUsuarioAsync(id.Value);
            if (!resp.FbSucces || resp.Datos.FirstOrDefault() is not { } u)
            {
                TempData["Error"] = resp.FcMensaje;
                return RedirectToAction(nameof(Index));
            }
            return View(u);
        }
        return View(new FM.OrigenDatos.Modelos.Seguridad.UsuarioModelo { FbEsLocal = true, FbActivo = true });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Usuario(
        int? fiId, string fcUsuario, string fcNombre, string? fcCargo, string? fcCorreo, string? fcTelefono,
        int fiRolId, int? fiSucursalId, bool fbEsLocal, string? contrasenaNueva)
    {
        var actor = AppAccess.UsuarioId(User) ?? 0;
        var resp = await _seguridad.GuardarUsuarioAsync(fiId, fcUsuario, fcNombre, fcCargo, fcCorreo, fcTelefono,
            fiRolId, fiSucursalId, fbEsLocal, contrasenaNueva, actor);
        if (!resp.FbSucces)
        {
            TempData["Error"] = resp.FcMensaje;
            return RedirectToAction(nameof(Usuario), new { id = fiId });
        }
        TempData["Ok"] = resp.FcMensaje;
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> ActivarUsuario(int id, bool activo)
    {
        var actor = AppAccess.UsuarioId(User) ?? 0;
        var resp = await _seguridad.ActivarUsuarioAsync(id, activo, actor);
        TempData[resp.FbSucces ? "Ok" : "Error"] = resp.FcMensaje;
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Roles()
    {
        ViewData["Title"] = "Roles y permisos";
        var roles = await _seguridad.ListarRolesAsync(soloActivos: false);
        return View(roles.Datos);
    }

    [HttpGet]
    public async Task<IActionResult> RolPermisos(int id)
    {
        ViewData["Title"] = "Permisos del rol";
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
        var actor = AppAccess.UsuarioId(User) ?? 0;
        var resp = await _seguridad.GuardarRolPermisosAsync(id, pantallas ?? Array.Empty<string>(), actor);
        TempData[resp.FbSucces ? "Ok" : "Error"] = resp.FcMensaje;
        return RedirectToAction(nameof(RolPermisos), new { id });
    }
}

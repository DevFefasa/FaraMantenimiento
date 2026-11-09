using System.Security.Claims;
using FaraMantenimiento.Helpers;
using FaraMantenimiento.Models;
using FM.Programacion.Servicios;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FaraMantenimiento.Controllers;

public class AccountController : Controller
{
    private readonly SeguridadServicio _seguridad;

    public AccountController(SeguridadServicio seguridad) => _seguridad = seguridad;

    private string? Ip => HttpContext.Connection.RemoteIpAddress?.ToString();

    [HttpGet, AllowAnonymous]
    public IActionResult Login(string? returnUrl = null)
    {
        if (User.Identity?.IsAuthenticated == true)
            return RedirectToAction("Index", "Home");
        return View(new LoginViewModel { ReturnUrl = returnUrl });
    }

    [HttpPost, AllowAnonymous, ValidateAntiForgeryToken, EnableRateLimiting(AppAccess.PoliticaLogin)]
    public async Task<IActionResult> Login(LoginViewModel model)
    {
        if (!ModelState.IsValid) return View(model);

        var (cab, usuario, debeCrearClave) = await _seguridad.AutenticarAsync(model.Usuario, model.Contrasena, Ip);
        if (!cab.FbSucces || usuario == null)
        {
            ModelState.AddModelError(string.Empty, string.IsNullOrWhiteSpace(cab.FcMensaje)
                ? "Usuario o contraseña incorrectos."
                : cab.FcMensaje);
            return View(model);
        }

        var permisos = await _seguridad.PermisosUsuarioAsync(usuario.FiId);
        var claims = new List<Claim>
        {
            new(ClaimTypes.Name, usuario.FcUsuario),
            new(AppAccess.NombreClaim, usuario.FcNombre),
            new(ClaimTypes.Role, usuario.FcRolCodigo ?? ""),
            new(AppAccess.FiIdClaim, usuario.FiId.ToString()),
            new(AppAccess.RolIdClaim, usuario.FiRolId.ToString())
        };
        if (usuario.FbEsLocal)
            claims.Add(new Claim(AppAccess.EsLocalClaim, "1"));
        if (permisos.FbSucces)
        {
            foreach (var p in permisos.Datos)
                claims.Add(new Claim(AppAccess.PermisoClaim, p.FcPantalla));
        }

        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        await HttpContext.SignInAsync(
            CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(identity),
            new AuthenticationProperties
            {
                IsPersistent = model.Recordar,
                ExpiresUtc = DateTimeOffset.UtcNow.AddHours(8)
            });

        // Entró con la clave maestra: debe crear su clave propia.
        if (debeCrearClave)
        {
            TempData["Error"] = "Debe crear su clave personal antes de continuar.";
            return RedirectToAction(nameof(CambiarClave));
        }

        if (!string.IsNullOrEmpty(model.ReturnUrl) && Url.IsLocalUrl(model.ReturnUrl)
            && !model.ReturnUrl.StartsWith("/Account/", StringComparison.OrdinalIgnoreCase))
            return Redirect(model.ReturnUrl);

        return RedirectToAction("Index", "Home");
    }

    [Authorize, HttpGet]
    public async Task<IActionResult> CambiarClave(CancellationToken ct)
    {
        if (!User.HasClaim(AppAccess.EsLocalClaim, "1"))
        {
            TempData["Error"] = "Los usuarios de dominio cambian su clave en Active Directory.";
            return RedirectToAction("Index", "Home");
        }
        ViewData["Title"] = "Cambiar clave";
        ViewBag.SinClave = await _seguridad.UsuarioLocalSinClaveAsync(User.Identity?.Name ?? "", ct);
        return View();
    }

    [Authorize, HttpPost, ValidateAntiForgeryToken, EnableRateLimiting(AppAccess.PoliticaLogin)]
    public async Task<IActionResult> CambiarClave(string? claveActual, string claveNueva, string claveConfirmacion, CancellationToken ct)
    {
        var fiId = AppAccess.UsuarioId(User) ?? 0;
        var resp = await _seguridad.CambiarClavePropiaAsync(fiId, claveActual, claveNueva ?? "", claveConfirmacion ?? "", Ip, ct);
        if (!resp.FbSucces)
        {
            TempData["Error"] = resp.FcMensaje;
            return RedirectToAction(nameof(CambiarClave));
        }
        TempData["Ok"] = resp.FcMensaje;
        return RedirectToAction("Index", "Home");
    }

    [AllowAnonymous, HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout()
    {
        var fiId = AppAccess.UsuarioId(User);
        if (fiId != null)
            await _seguridad.RegistrarLogoutAsync(fiId, User.Identity?.Name, Ip);
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return RedirectToAction(nameof(Login));
    }

    [AllowAnonymous, HttpGet, ActionName("Logout")]
    public IActionResult LogoutGet() =>
        User.Identity?.IsAuthenticated == true
            ? RedirectToAction("Index", "Home")
            : RedirectToAction(nameof(Login));

    [Authorize, HttpGet]
    public IActionResult AccessDenied()
    {
        Response.StatusCode = 403;
        return View();
    }
}

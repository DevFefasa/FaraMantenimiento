using System.Security.Claims;
using FM.Programacion.Servicios;
using Microsoft.AspNetCore.Authentication;

namespace FaraMantenimiento.Helpers;

/// <summary>
/// Relee rol y permisos en cada petición (no quedan congelados en la cookie).
/// Si el usuario o su rol están inactivos, la petición queda anónima y se borra la cookie.
/// </summary>
public sealed class PermisosClaimsTransformation : IClaimsTransformation
{
    private const string MarcaRevisado = "fara-sesion-revisada";

    private readonly SeguridadServicio _seguridad;
    private readonly IHttpContextAccessor _http;

    public PermisosClaimsTransformation(SeguridadServicio seguridad, IHttpContextAccessor http)
    {
        _seguridad = seguridad;
        _http = http;
    }

    private static ClaimsPrincipal Anonimo() => new(new ClaimsIdentity());

    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        if (principal.Identity?.IsAuthenticated != true)
            return principal;

        // Cookie sin id de usuario (formato viejo o manipulada): no se acepta.
        if (!int.TryParse(principal.FindFirst(AppAccess.FiIdClaim)?.Value, out var fiId) || fiId <= 0)
            return CerrarSesion();

        var ctx = _http.HttpContext;
        if (ctx?.Items[MarcaRevisado] is ClaimsPrincipal yaRevisado)
            return yaRevisado;

        var sesion = await _seguridad.ObtenerSesionVigenteAsync(fiId);
        if (sesion == null)
            return CerrarSesion();

        var rolCookie = principal.FindFirst(ClaimTypes.Role)?.Value ?? "";
        var rolIdCookie = principal.FindFirst(AppAccess.RolIdClaim)?.Value ?? "";
        var enCookie = principal.FindAll(AppAccess.PermisoClaim).Select(c => c.Value).ToHashSet(StringComparer.OrdinalIgnoreCase);

        ClaimsPrincipal resultado = principal;
        if (!enCookie.SetEquals(sesion.Permisos)
            || !string.Equals(rolCookie, sesion.FcRolCodigo, StringComparison.OrdinalIgnoreCase)
            || rolIdCookie != sesion.FiRolId.ToString())
        {
            var identidad = new ClaimsIdentity(
                principal.Claims.Where(c => c.Type != AppAccess.PermisoClaim && c.Type != ClaimTypes.Role && c.Type != AppAccess.RolIdClaim),
                principal.Identity!.AuthenticationType,
                ClaimTypes.Name,
                ClaimTypes.Role);
            identidad.AddClaim(new Claim(ClaimTypes.Role, sesion.FcRolCodigo));
            identidad.AddClaim(new Claim(AppAccess.RolIdClaim, sesion.FiRolId.ToString()));
            foreach (var p in sesion.Permisos)
                identidad.AddClaim(new Claim(AppAccess.PermisoClaim, p));
            resultado = new ClaimsPrincipal(identidad);
        }

        if (ctx != null) ctx.Items[MarcaRevisado] = resultado;
        return resultado;
    }

    private ClaimsPrincipal CerrarSesion()
    {
        var ctx = _http.HttpContext;
        if (ctx != null && !ctx.Response.HasStarted)
            ctx.Response.Cookies.Delete(Program.NombreCookie);
        return Anonimo();
    }
}

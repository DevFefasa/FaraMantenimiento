using System.Security.Claims;
using FM.Programacion.Constantes;

namespace FaraMantenimiento.Helpers;

public static class AppAccess
{
    public const string PermisoClaim = Pantallas.ClaimType;
    public const string NombreClaim = "nombre";
    public const string FiIdClaim = "fiId";
    public const string RolIdClaim = "fiRolId";
    public const string EsLocalClaim = "esLocal";

    /// <summary>Política de rate limiting para login y cambio de clave.</summary>
    public const string PoliticaLogin = "login";

    // El rol y los permisos los refresca PermisosClaimsTransformation en cada petición.
    public static bool TienePermiso(ClaimsPrincipal user, string pantalla) =>
        user.Identity?.IsAuthenticated == true &&
        (user.IsInRole(Roles.Admin) ||
         user.HasClaim(PermisoClaim, pantalla));

    public static int? UsuarioId(ClaimsPrincipal user) =>
        int.TryParse(user.FindFirstValue(FiIdClaim), out var id) ? id : null;

    /// <summary>Permisos (pantallas) vigentes del usuario.</summary>
    public static IReadOnlyCollection<string> Permisos(ClaimsPrincipal user) =>
        user.FindAll(PermisoClaim).Select(c => c.Value).ToArray();
}

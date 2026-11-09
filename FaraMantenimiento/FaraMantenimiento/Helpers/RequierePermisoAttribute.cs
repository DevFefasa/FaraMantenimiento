using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace FaraMantenimiento.Helpers;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
public sealed class RequierePermisoAttribute : Attribute, IAuthorizationFilter
{
    private readonly string[] _pantallas;

    public RequierePermisoAttribute(params string[] pantallas) => _pantallas = pantallas;

    public void OnAuthorization(AuthorizationFilterContext context)
    {
        var user = context.HttpContext.User;
        if (user.Identity?.IsAuthenticated != true)
        {
            context.Result = new ChallengeResult();
            return;
        }

        if (_pantallas.Length == 0 || _pantallas.Any(p => AppAccess.TienePermiso(user, p)))
            return;

        context.Result = new ForbidResult();
    }
}

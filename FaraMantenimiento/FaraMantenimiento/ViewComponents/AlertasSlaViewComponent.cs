using FM.Programacion.Servicios;
using Microsoft.AspNetCore.Mvc;

namespace FaraMantenimiento.ViewComponents;

/// <summary>
/// Callers: Views/Shared/_Header.cshtml (@await Component.InvokeAsync("AlertasSla")).
/// API: SlaServicio.ContarAlertasPendientesAsync → int.
/// Schema: conteo de slaalerta pendientes (soloNoNotificadas).
/// Instrucción: «campana con badge rojo… TICKET_BANDEJA o TICKET_TODOS… /Tickets/Bandeja… try/catch».
/// </summary>
public class AlertasSlaViewComponent : ViewComponent
{
    private readonly SlaServicio _sla;

    public AlertasSlaViewComponent(SlaServicio sla) => _sla = sla;

    public async Task<IViewComponentResult> InvokeAsync()
    {
        try
        {
            var user = HttpContext?.User;
            if (user?.Identity?.IsAuthenticated != true)
                return Content(string.Empty);

            var puede = user.HasClaim("permiso", "TICKET_BANDEJA") || user.HasClaim("permiso", "TICKET_TODOS");
            if (!puede)
                return Content(string.Empty);

            var total = await _sla.ContarAlertasPendientesAsync(HttpContext?.RequestAborted ?? default);
            return View(total);
        }
        catch
        {
            return Content(string.Empty);
        }
    }
}

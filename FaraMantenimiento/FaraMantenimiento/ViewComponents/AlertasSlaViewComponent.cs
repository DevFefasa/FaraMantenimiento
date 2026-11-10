using FaraMantenimiento.Helpers;
using FM.OrigenDatos.Modelos.Sla;
using FM.Programacion.Servicios;
using Microsoft.AspNetCore.Mvc;

namespace FaraMantenimiento.ViewComponents;

/// <summary>Modelo de la campana: total pendiente y últimas alertas.</summary>
public class AlertasSlaVista
{
    public int Total { get; set; }
    public List<SlaAlertaModelo> Alertas { get; set; } = new();
}

/// <summary>
/// Campana del header (dropdown con las últimas alertas SLA pendientes).
/// Solo para quien tiene TICKET_BANDEJA o TICKET_TODOS (claims releídos en cada petición).
/// </summary>
public class AlertasSlaViewComponent : ViewComponent
{
    private const int Limite = 8;
    private readonly SlaServicio _sla;

    public AlertasSlaViewComponent(SlaServicio sla) => _sla = sla;

    public async Task<IViewComponentResult> InvokeAsync()
    {
        try
        {
            var user = HttpContext?.User;
            if (user?.Identity?.IsAuthenticated != true)
                return Content(string.Empty);

            var puede = user.HasClaim(AppAccess.PermisoClaim, "TICKET_BANDEJA") || user.HasClaim(AppAccess.PermisoClaim, "TICKET_TODOS");
            if (!puede)
                return Content(string.Empty);

            var ct = HttpContext?.RequestAborted ?? default;
            var total = await _sla.ContarAlertasPendientesAsync(ct);
            var alertas = total > 0 ? await _sla.ListarAlertasPendientesAsync(Limite, ct) : new List<SlaAlertaModelo>();
            return View(new AlertasSlaVista { Total = total, Alertas = alertas });
        }
        catch
        {
            return Content(string.Empty);
        }
    }
}

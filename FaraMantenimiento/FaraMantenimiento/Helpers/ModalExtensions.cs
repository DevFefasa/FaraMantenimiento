using Microsoft.AspNetCore.Http;

namespace FaraMantenimiento.Helpers;

/// <summary>
/// Patrón "modal en computadora / página en teléfono" (ver docs/CONVENCIONES.md §4.1).
/// wwwroot/js/fara-modal.js envía la cabecera X-Fara-Modal: 1 cuando abre el formulario en un modal.
/// GET:  return Request.EsModal() ? PartialView("_Formulario", vm) : View(vm);
/// POST: if (Request.EsModal()) return Json(respuestaEstandar); else TempData["Exito"/"Error"] + Redirect.
/// </summary>
public static class ModalExtensions
{
    public const string Cabecera = "X-Fara-Modal";

    public static bool EsModal(this HttpRequest request) =>
        request.Headers.TryGetValue(Cabecera, out var v) && v == "1";
}

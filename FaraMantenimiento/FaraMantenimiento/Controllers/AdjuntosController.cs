using System.Security.Claims;
using FaraMantenimiento.Helpers;
using FM.OrigenDatos.Conexion;
using FM.Programacion.Servicios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FaraMantenimiento.Controllers;

/// <summary>
/// Adjuntos genéricos. Hoy solo existe la entidad TICKET y todo pasa por TicketServicio,
/// que valida que el usuario pueda ver o editar el ticket dueño del archivo.
/// </summary>
[Authorize]
[RequestSizeLimit(110_000_000)]
public class AdjuntosController : Controller
{
    private readonly TicketServicio _tickets;

    public AdjuntosController(TicketServicio tickets) => _tickets = tickets;

    private int UsuarioId => AppAccess.UsuarioId(User) ?? 0;
    private string? RolCodigo => User.FindFirstValue(ClaimTypes.Role);

    private static RespuestaSp EntidadNoValida() =>
        new() { FiCodigo = 400, FcMensaje = "Entidad de adjunto no válida", FbSucces = false };

    // Respuesta estándar AJAX (código HTTP 200; el resultado va en fiCodigo/fbSucces).
    private IActionResult Respuesta(RespuestaSp r, object? datos = null) =>
        Json(new { r.FiCodigo, r.FcMensaje, r.FbSucces, r.FjData, datos });

    [HttpGet]
    public async Task<IActionResult> Listar(string entidad, int entidadId, string? etapa = null, CancellationToken ct = default)
    {
        if (AdjuntoServicio.NormalizarEntidad(entidad) != AdjuntoServicio.EntidadTicket)
            return Respuesta(EntidadNoValida());
        var resp = await _tickets.ListarAdjuntosAsync(entidadId, etapa, UsuarioId, RolCodigo, ct);
        return Respuesta(resp, resp.Datos);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Subir(string entidad, int entidadId, string etapa, IFormFile archivo, CancellationToken ct = default)
    {
        if (AdjuntoServicio.NormalizarEntidad(entidad) != AdjuntoServicio.EntidadTicket)
            return Respuesta(EntidadNoValida());
        var resp = await _tickets.SubirAdjuntoAsync(entidadId, etapa, archivo, UsuarioId, RolCodigo, ct);
        return Respuesta(resp);
    }

    [HttpGet]
    public async Task<IActionResult> Ver(int id, CancellationToken ct = default)
    {
        var (cab, adj, ruta) = await _tickets.ObtenerAdjuntoParaDescargaAsync(id, UsuarioId, RolCodigo, ct);
        if (cab.FiCodigo is 401 or 403) return Forbid();
        if (!cab.FbSucces || adj == null || ruta == null)
            return NotFound(cab.FcMensaje);
        // MIME según extensión (no el que envió el cliente) y siempre como descarga/adjunto.
        return PhysicalFile(ruta, AdjuntoServicio.MimeDescarga(adj), adj.FcNombreOriginal);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Eliminar(int id, CancellationToken ct = default)
    {
        var resp = await _tickets.EliminarAdjuntoAsync(id, UsuarioId, RolCodigo, ct);
        return Respuesta(resp);
    }
}

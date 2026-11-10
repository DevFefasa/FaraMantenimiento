using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Correo;

namespace FM.OrigenDatos.Repositorios;

/// <summary>Bandeja de correos (correopendiente) y datos para plantillas. Solo ejecuta SP.</summary>
public class CorreoRepositorio
{
    private readonly IEjecutorSp _sp;

    public CorreoRepositorio(IEjecutorSp sp) => _sp = sp;

    public Task<RespuestaSp> EncolarAsync(string para, string asunto, string cuerpoCifrado, string tipo, string formato,
        int? fiTicketId, int? fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_correo_encolar", new
        {
            p_fcPara = para,
            p_fcAsunto = asunto,
            p_fcCuerpoCifrado = cuerpoCifrado,
            p_fcTipo = tipo,
            p_fcFormato = formato,
            p_fiTicketId = fiTicketId,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    public Task<RespuestaSp<CorreoBandejaModelo>> PendientesAsync(int limite, int maxIntentos, CancellationToken ct = default) =>
        _sp.EjecutarAsync<CorreoBandejaModelo>("sp_correo_pendientes_listar", new { p_fiLimite = limite, p_fiMaxIntentos = maxIntentos }, ct);

    public Task<RespuestaSp> MarcarEnviadoAsync(int fiId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_correo_marcar_enviado", new { p_fiId = fiId }, ct);

    public Task<RespuestaSp> MarcarErrorAsync(int fiId, string error, int maxIntentos, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_correo_marcar_error", new { p_fiId = fiId, p_fcError = error, p_fiMaxIntentos = maxIntentos }, ct);

    public Task<(RespuestaSp Cabecera, List<CorreoTicketModelo> Ticket, List<CorreoDestinatarioModelo> Destinatarios)> TicketDatosAsync(
        int fiTicketId, CancellationToken ct = default) =>
        _sp.EjecutarDosAsync<CorreoTicketModelo, CorreoDestinatarioModelo>("sp_correo_ticket_datos", new { p_fiTicketId = fiTicketId }, ct);

    public Task<RespuestaSp<CorreoSlaAlertaModelo>> SlaAlertasPendientesAsync(int limite, CancellationToken ct = default) =>
        _sp.EjecutarAsync<CorreoSlaAlertaModelo>("sp_correo_sla_alertas_pendientes", new { p_fiLimite = limite }, ct);

    public Task<RespuestaSp> SlaAlertaMarcarAsync(int fiId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_correo_sla_alerta_marcar", new { p_fiId = fiId }, ct);
}

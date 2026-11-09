using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Sla;
using FM.OrigenDatos.Repositorios;

namespace FM.Programacion.Servicios;

// Callers: SlaTarea; futuro bandeja via ContarAlertasPendientesAsync
// API: RevisarVencimientosAsync, CierreAutomaticoAsync, ListarAlertasAsync, ContarAlertasPendientesAsync
// Schema: slaalerta / ticket SLA flags
// User instruction: Fase 3 SLA + "agrega SOLO un metodo en SlaServicio" para contador; no edites Views/Shared

public class SlaServicio
{
    private readonly TicketRepositorio _tickets;

    public SlaServicio(TicketRepositorio tickets) => _tickets = tickets;

    public Task<RespuestaSp> RevisarVencimientosAsync(DateTime? ahora = null, CancellationToken ct = default) =>
        _tickets.SlaRevisarVencimientosAsync(ahora ?? DateTime.Now, ct);

    public Task<RespuestaSp> CierreAutomaticoAsync(DateTime? ahora = null, CancellationToken ct = default) =>
        _tickets.SlaCierreAutomaticoAsync(ahora ?? DateTime.Now, ct);

    public Task<RespuestaSp<SlaAlertaModelo>> ListarAlertasAsync(bool soloNoNotificadas = true, int limite = 100, CancellationToken ct = default) =>
        _tickets.SlaAlertasListarAsync(soloNoNotificadas, limite, ct);

    /// <summary>Contador de alertas SLA pendientes (para bandeja). Correos no se envían aún.</summary>
    public async Task<int> ContarAlertasPendientesAsync(CancellationToken ct = default)
    {
        var resp = await _tickets.SlaAlertasContarAsync(soloNoNotificadas: true, ct);
        if (!resp.FbSucces) return 0;
        return resp.Datos.FirstOrDefault()?.FiTotal ?? 0;
    }
}

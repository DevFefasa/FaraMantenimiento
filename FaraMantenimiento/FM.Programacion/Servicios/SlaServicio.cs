using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Sla;
using FM.OrigenDatos.Repositorios;
using FM.Programacion.Servicios.Correo;

namespace FM.Programacion.Servicios;

// Callers: SlaTarea (revisión, cierre y correos), campana del header (alertas)
// API: RevisarVencimientosAsync, CierreAutomaticoAsync, ListarAlertasAsync, ContarAlertasPendientesAsync
// Schema: slaalerta / ticket SLA flags
// User instruction: Fase 3 SLA + "agrega SOLO un metodo en SlaServicio" para contador; no edites Views/Shared

public class SlaServicio
{
    private readonly TicketRepositorio _tickets;
    private readonly CorreoServicio _correos;

    public SlaServicio(TicketRepositorio tickets, CorreoServicio correos)
    {
        _tickets = tickets;
        _correos = correos;
    }

    /// <summary>Registra alertas de vencimiento y encola sus correos (responsable y jefatura, sin repetir).</summary>
    public async Task<RespuestaSp> RevisarVencimientosAsync(DateTime? ahora = null, CancellationToken ct = default)
    {
        var resp = await _tickets.SlaRevisarVencimientosAsync(ahora ?? DateTime.Now, ct);
        if (resp.FbSucces) await _correos.EncolarAlertasSlaAsync(ct);
        return resp;
    }

    /// <summary>Cierre automático; avisa por correo al solicitante de cada ticket cerrado.</summary>
    public async Task<RespuestaSp> CierreAutomaticoAsync(DateTime? ahora = null, CancellationToken ct = default)
    {
        var resp = await _tickets.SlaCierreAutomaticoAsync(ahora ?? DateTime.Now, ct);
        if (resp.FbSucces) await _correos.EncolarCierresAutomaticosAsync(resp.FjData, ct);
        return resp;
    }

    public Task<RespuestaSp<SlaAlertaModelo>> ListarAlertasAsync(bool soloNoNotificadas = true, int limite = 100, CancellationToken ct = default) =>
        _tickets.SlaAlertasListarAsync(soloNoNotificadas, limite, ct);

    /// <summary>Últimas alertas SLA pendientes (campana del header).</summary>
    public async Task<List<SlaAlertaModelo>> ListarAlertasPendientesAsync(int limite = 8, CancellationToken ct = default)
    {
        var resp = await _tickets.SlaAlertasListarAsync(soloNoNotificadas: true, Math.Clamp(limite, 1, 50), ct);
        return resp.FbSucces ? resp.Datos.ToList() : new List<SlaAlertaModelo>();
    }

    /// <summary>Contador de alertas SLA pendientes (para bandeja). Correos no se envían aún.</summary>
    public async Task<int> ContarAlertasPendientesAsync(CancellationToken ct = default)
    {
        var resp = await _tickets.SlaAlertasContarAsync(soloNoNotificadas: true, ct);
        if (!resp.FbSucces) return 0;
        return resp.Datos.FirstOrDefault()?.FiTotal ?? 0;
    }
}

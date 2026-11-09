using FM.Programacion.Servicios;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace FM.Programacion.Tareas;

// Callers: host AddHostedService en ProgramacionServiceCollectionExtensions
// API: BackgroundService cada 5 minutos → sp_sla_revisar_vencimientos + sp_ticket_cierre_automatico
// User instruction: "SlaTarea: BackgroundService cada 5 minutos que llama a ambos SP, con try/catch y log, sin tumbar la app."

public class SlaTarea : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<SlaTarea> _log;

    public SlaTarea(IServiceScopeFactory scopeFactory, ILogger<SlaTarea> log)
    {
        _scopeFactory = scopeFactory;
        _log = log;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await EjecutarCicloAsync(stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
                await EjecutarCicloAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _log.LogError(ex, "Error en el ciclo de SlaTarea");
                try { await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken); }
                catch (OperationCanceledException) { break; }
            }
        }
    }

    private async Task EjecutarCicloAsync(CancellationToken ct)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var sla = scope.ServiceProvider.GetRequiredService<SlaServicio>();

            var rev = await sla.RevisarVencimientosAsync(DateTime.Now, ct);
            if (rev.FbSucces) _log.LogInformation("SlaTarea revisión: {Mensaje} {Data}", rev.FcMensaje, rev.FjData);
            else _log.LogWarning("SlaTarea revisión: {Codigo} {Mensaje}", rev.FiCodigo, rev.FcMensaje);

            var cierre = await sla.CierreAutomaticoAsync(DateTime.Now, ct);
            if (cierre.FbSucces) _log.LogInformation("SlaTarea cierre: {Mensaje} {Data}", cierre.FcMensaje, cierre.FjData);
            else _log.LogWarning("SlaTarea cierre: {Codigo} {Mensaje}", cierre.FiCodigo, cierre.FcMensaje);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { }
        catch (Exception ex)
        {
            _log.LogError(ex, "SlaTarea: fallo al ejecutar SP de SLA/cierre");
        }
    }
}

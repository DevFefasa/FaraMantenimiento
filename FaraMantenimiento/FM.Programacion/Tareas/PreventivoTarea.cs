using FM.Programacion.Servicios;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace FM.Programacion.Tareas;

// Callers: host via AddHostedService en ProgramacionServiceCollectionExtensions
// API: BackgroundService diario + al arrancar → PreventivoServicio.GenerarTicketsAsync
// User instruction: "PreventivoTarea: BackgroundService que una vez al dia (y al arrancar) llama a generar tickets; con try/catch y log, sin tumbar la app."

public class PreventivoTarea : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<PreventivoTarea> _log;

    public PreventivoTarea(IServiceScopeFactory scopeFactory, ILogger<PreventivoTarea> log)
    {
        _scopeFactory = scopeFactory;
        _log = log;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await EjecutarGeneracionAsync(stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var ahora = DateTime.Now;
                var proxima = ahora.Date.AddDays(1).AddHours(1);
                var delay = proxima - ahora;
                if (delay < TimeSpan.FromMinutes(1))
                    delay = TimeSpan.FromHours(24);

                await Task.Delay(delay, stoppingToken);
                await EjecutarGeneracionAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _log.LogError(ex, "Error en el ciclo de PreventivoTarea");
                try { await Task.Delay(TimeSpan.FromHours(1), stoppingToken); }
                catch (OperationCanceledException) { break; }
            }
        }
    }

    private async Task EjecutarGeneracionAsync(CancellationToken ct)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var svc = scope.ServiceProvider.GetRequiredService<PreventivoServicio>();
            var resp = await svc.GenerarTicketsAsync(1, DateTime.Today, ct);
            if (resp.FbSucces)
                _log.LogInformation("PreventivoTarea: {Mensaje} | {Data}", resp.FcMensaje, resp.FjData);
            else
                _log.LogWarning("PreventivoTarea: {Codigo} {Mensaje}", resp.FiCodigo, resp.FcMensaje);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "PreventivoTarea: fallo al generar tickets preventivos");
        }
    }
}

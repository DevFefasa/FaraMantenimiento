using FM.Programacion.Servicios.Correo;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace FM.Programacion.Tareas;

/// <summary>Worker que envía la bandeja de correos cada Smtp:SegundosIntervalo (mínimo 15 s).</summary>
public class CorreoTarea : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IOptions<SmtpOptions> _opciones;
    private readonly ILogger<CorreoTarea> _log;

    public CorreoTarea(IServiceScopeFactory scopeFactory, IOptions<SmtpOptions> opciones, ILogger<CorreoTarea> log)
    {
        _scopeFactory = scopeFactory;
        _opciones = opciones;
        _log = log;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var cfg = _opciones.Value;
        if (!cfg.Habilitado)
        {
            _log.LogInformation("Envío de correos deshabilitado (Smtp:Habilitado=false).");
            return;
        }
        var intervalo = TimeSpan.FromSeconds(Math.Max(15, cfg.SegundosIntervalo));
        _log.LogInformation("CorreoTarea cada {Segundos} s.", intervalo.TotalSeconds);

        try { await Task.Delay(TimeSpan.FromSeconds(15), stoppingToken); }
        catch (OperationCanceledException) { return; }

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var scope = _scopeFactory.CreateAsyncScope();
                var correos = scope.ServiceProvider.GetRequiredService<CorreoServicio>();
                await correos.ProcesarPendientesAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _log.LogError(ex, "Fallo no controlado en CorreoTarea");
            }

            try { await Task.Delay(intervalo, stoppingToken); }
            catch (OperationCanceledException) { break; }
        }
    }
}

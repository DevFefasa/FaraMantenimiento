using FM.OrigenDatos.Dependencia;
using FM.Programacion.Opciones;
using FM.Programacion.Servicios;
using FM.Programacion.Servicios.Correo;
using FM.Programacion.Tareas;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace FM.Programacion.Dependencia;

public static class ProgramacionServiceCollectionExtensions
{
    public static IServiceCollection AddProgramacion(this IServiceCollection services, IConfiguration config)
    {
        services.AddOrigenDatos(config);
        services.Configure<AdjuntosOptions>(config.GetSection(AdjuntosOptions.Section));

        services.AddScoped<SeguridadServicio>();
        services.AddScoped<CorreoPendienteServicio>();
        services.Configure<SmtpOptions>(config.GetSection(SmtpOptions.Seccion));
        services.AddScoped<ISmtpCorreoSender, SmtpCorreoSender>();
        services.AddScoped<CorreoServicio>();
        services.AddScoped<AdjuntoServicio>();
        services.AddScoped<CatalogoServicio>();
        services.AddScoped<TicketServicio>();
        services.AddScoped<SlaServicio>();
        services.AddScoped<ReporteServicio>();
        services.AddScoped<ExportacionServicio>();
        services.AddScoped<PreventivoServicio>();
        // Callers: TicketsController. API: DI SapServicio. Schema: N/A (usa SapHanaRepositorio).
        // Confirm: SapHanaRepositorio registrado en OrigenDatos. User: "FM.Programacion servicio"
        services.AddScoped<SapServicio>();
        services.AddHostedService<PreventivoTarea>();
        services.AddHostedService<SlaTarea>();
        services.AddHostedService<CorreoTarea>();
        return services;
    }
}

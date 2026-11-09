using FM.OrigenDatos.Dependencia;
using FM.Programacion.Opciones;
using FM.Programacion.Servicios;
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
        services.AddScoped<AdjuntoServicio>();
        services.AddScoped<CatalogoServicio>();
        services.AddScoped<TicketServicio>();
        services.AddScoped<SlaServicio>();
        services.AddScoped<ReporteServicio>();
        services.AddScoped<ExportacionServicio>();
        services.AddScoped<PreventivoServicio>();
        services.AddHostedService<PreventivoTarea>();
        services.AddHostedService<SlaTarea>();
        return services;
    }
}

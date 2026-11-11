using FM.OrigenDatos.Api;
using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Repositorios;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace FM.OrigenDatos.Dependencia;

public static class OrigenDatosServiceCollectionExtensions
{
    public static IServiceCollection AddOrigenDatos(this IServiceCollection services, IConfiguration config)
    {
        services.Configure<ActiveDirectoryOptions>(config.GetSection(ActiveDirectoryOptions.Section));
        services.AddHttpClient("ActiveDirectory", (sp, client) =>
        {
            var opt = config.GetSection(ActiveDirectoryOptions.Section).Get<ActiveDirectoryOptions>()
                      ?? new ActiveDirectoryOptions();
            if (!string.IsNullOrWhiteSpace(opt.BaseUrl))
                client.BaseAddress = new Uri(opt.BaseUrl.TrimEnd('/') + "/");
            client.Timeout = TimeSpan.FromSeconds(20);
        });

        services.AddSingleton<IFabricaConexion, FabricaConexion>();
        services.AddScoped<IEjecutorSp, EjecutorSp>();
        services.AddScoped<IActiveDirectoryApi, ActiveDirectoryApi>();
        services.AddScoped<SeguridadRepositorio>();
        services.AddScoped<CorreoPendienteRepositorio>();
        services.AddScoped<CorreoRepositorio>();
        services.AddScoped<AdjuntoRepositorio>();
        services.AddScoped<CatalogoRepositorio>();
        services.AddScoped<TicketRepositorio>();
        services.AddScoped<ReporteRepositorio>();
        services.AddScoped<PreventivoRepositorio>();
        // Callers: SapServicio (Programacion). API: DI SapHanaRepositorio. Schema: ConnectionStrings:SapHana, Sap:Esquema.
        // Confirm: no AddScoped SapHana previo. User: "Copia el patrón... FM.OrigenDatos repositorio SAP, FM.Programacion servicio"
        services.AddScoped<SapHanaRepositorio>();
        return services;
    }
}

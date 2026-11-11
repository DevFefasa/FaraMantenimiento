using FM.OrigenDatos.Modelos.Sap;
using FM.OrigenDatos.Repositorios;
using Microsoft.Extensions.Logging;

namespace FM.Programacion.Servicios;

// Callers: TicketsController (BuscarArticulosSap, BuscarProveedoresSap)
// API: BuscarArticulosAsync / BuscarProveedoresAsync — solo lectura; sin escritura SAP
// Schema/config: ConnectionStrings:SapHana + Sap:Esquema vía SapHanaRepositorio
// Confirm: Glob **/SapServicio.cs vacío; SapHanaRepositorio ya existe en OrigenDatos
// User instruction: "Si la cadena no está configurada, la búsqueda debe responder un mensaje claro (\"SAP no está configurado\") sin romper la pantalla."

public class SapServicio
{
    private readonly SapHanaRepositorio _sap;
    private readonly ILogger<SapServicio> _log;

    public SapServicio(SapHanaRepositorio sap, ILogger<SapServicio> log)
    {
        _sap = sap;
        _log = log;
    }

    public bool EstaConfigurado => _sap.EstaConfigurado;

    public async Task<SapBusquedaResultado<SapArticuloModelo>> BuscarArticulosAsync(string? q, CancellationToken ct = default)
    {
        try
        {
            return await _sap.BuscarArticulosAsync(q, 30, ct);
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Error al buscar artículos en SAP");
            return new SapBusquedaResultado<SapArticuloModelo>
            {
                FbConfigurado = true,
                FcMensaje = "No se pudo consultar SAP. Intente de nuevo o avise a IT.",
                Datos = Array.Empty<SapArticuloModelo>()
            };
        }
    }

    public async Task<SapBusquedaResultado<SapProveedorModelo>> BuscarProveedoresAsync(string? q, CancellationToken ct = default)
    {
        try
        {
            return await _sap.BuscarProveedoresAsync(q, 30, ct);
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Error al buscar proveedores en SAP");
            return new SapBusquedaResultado<SapProveedorModelo>
            {
                FbConfigurado = true,
                FcMensaje = "No se pudo consultar SAP. Intente de nuevo o avise a IT.",
                Datos = Array.Empty<SapProveedorModelo>()
            };
        }
    }
}

using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Reportes;

namespace FM.OrigenDatos.Repositorios;

public class ReporteRepositorio
{
    private readonly IEjecutorSp _sp;

    public ReporteRepositorio(IEjecutorSp sp) => _sp = sp;

    private static object Param(ReporteFiltroModelo f) => new
    {
        p_fdDesde = f.FdDesde,
        p_fdHasta = f.FdHasta,
        p_fiSucursalId = f.FiSucursalId,
        p_fiRegionId = f.FiRegionId,
        p_fiTipoMantenimientoId = f.FiTipoMantenimientoId,
        p_fiCategoriaId = f.FiCategoriaId,
        p_fiPrioridadId = f.FiPrioridadId,
        p_fiEstadoId = f.FiEstadoId,
        p_fiTecnicoId = f.FiTecnicoId,
        p_fiProveedorId = f.FiProveedorId
    };

    public Task<RespuestaSp<ReporteResumenModelo>> ResumenAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _sp.EjecutarAsync<ReporteResumenModelo>("sp_reporte_resumen", Param(f), ct);

    public Task<RespuestaSp<ReporteTiempoModelo>> TiemposAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _sp.EjecutarAsync<ReporteTiempoModelo>("sp_reporte_tiempos", Param(f), ct);

    public Task<RespuestaSp<ReporteSlaModelo>> SlaAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _sp.EjecutarAsync<ReporteSlaModelo>("sp_reporte_sla", Param(f), ct);

    public Task<RespuestaSp<ReporteTipoModelo>> TipoAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _sp.EjecutarAsync<ReporteTipoModelo>("sp_reporte_tipo", Param(f), ct);

    public Task<(RespuestaSp Cabecera, List<ReporteMtbfModelo> PorActivo, List<ReporteMtbfModelo> PorSucursal)> MtbfAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _sp.EjecutarDosAsync<ReporteMtbfModelo, ReporteMtbfModelo>("sp_reporte_mtbf", Param(f), ct);

    public Task<(RespuestaSp Cabecera, List<ReporteReincidenciaResumenModelo> Resumen, List<ReporteReincidenciaDetalleModelo> Detalle)> ReincidenciaAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _sp.EjecutarDosAsync<ReporteReincidenciaResumenModelo, ReporteReincidenciaDetalleModelo>("sp_reporte_reincidencia", Param(f), ct);

    public Task<(RespuestaSp Cabecera, List<ReporteCostoModelo> PorSucursal, List<ReporteCostoModelo> PorCategoria, List<ReporteCostoModelo> PorActivo)> CostosAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _sp.EjecutarTresAsync<ReporteCostoModelo, ReporteCostoModelo, ReporteCostoModelo>("sp_reporte_costos", Param(f), ct);

    public Task<(RespuestaSp Cabecera, List<ReporteProductividadModelo> Tecnicos, List<ReporteProductividadModelo> Proveedores)> ProductividadAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _sp.EjecutarDosAsync<ReporteProductividadModelo, ReporteProductividadModelo>("sp_reporte_productividad", Param(f), ct);

    public Task<(RespuestaSp Cabecera, List<ReporteSatisfaccionResumenModelo> Resumen, List<ReporteSatisfaccionDetalleModelo> Detalle)> SatisfaccionAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _sp.EjecutarDosAsync<ReporteSatisfaccionResumenModelo, ReporteSatisfaccionDetalleModelo>("sp_reporte_satisfaccion", Param(f), ct);

    public Task<RespuestaSp<ReporteTendenciaModelo>> TendenciaAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _sp.EjecutarAsync<ReporteTendenciaModelo>("sp_reporte_tendencia", Param(f), ct);

    public Task<(RespuestaSp Cabecera, List<ActivoHojaVidaModelo> Activo, List<ActivoHojaVidaTicketModelo> Tickets, List<ActivoHojaVidaTotalesModelo> Totales)> HojaVidaAsync(int fiActivoId, CancellationToken ct = default) =>
        _sp.EjecutarTresAsync<ActivoHojaVidaModelo, ActivoHojaVidaTicketModelo, ActivoHojaVidaTotalesModelo>(
            "sp_reporte_activo_hojavida", new { p_fiActivoId = fiActivoId }, ct);
}


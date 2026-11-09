using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Reportes;
using FM.OrigenDatos.Repositorios;

namespace FM.Programacion.Servicios;

public class ReporteServicio
{
    private readonly ReporteRepositorio _repo;

    public ReporteServicio(ReporteRepositorio repo) => _repo = repo;

    public static ReporteFiltroModelo NormalizarFiltro(ReporteFiltroModelo? f)
    {
        f ??= new ReporteFiltroModelo();
        if (f.FdDesde.HasValue && f.FdHasta.HasValue && f.FdDesde > f.FdHasta)
            (f.FdDesde, f.FdHasta) = (f.FdHasta, f.FdDesde);
        return f;
    }

    public Task<RespuestaSp<ReporteResumenModelo>> ResumenAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _repo.ResumenAsync(NormalizarFiltro(f), ct);

    public Task<RespuestaSp<ReporteTiempoModelo>> TiemposAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _repo.TiemposAsync(NormalizarFiltro(f), ct);

    public Task<RespuestaSp<ReporteSlaModelo>> SlaAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _repo.SlaAsync(NormalizarFiltro(f), ct);

    public Task<RespuestaSp<ReporteTipoModelo>> TipoAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _repo.TipoAsync(NormalizarFiltro(f), ct);

    public Task<(RespuestaSp Cabecera, List<ReporteMtbfModelo> PorActivo, List<ReporteMtbfModelo> PorSucursal)> MtbfAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _repo.MtbfAsync(NormalizarFiltro(f), ct);

    public Task<(RespuestaSp Cabecera, List<ReporteReincidenciaResumenModelo> Resumen, List<ReporteReincidenciaDetalleModelo> Detalle)> ReincidenciaAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _repo.ReincidenciaAsync(NormalizarFiltro(f), ct);

    public Task<(RespuestaSp Cabecera, List<ReporteCostoModelo> PorSucursal, List<ReporteCostoModelo> PorCategoria, List<ReporteCostoModelo> PorActivo)> CostosAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _repo.CostosAsync(NormalizarFiltro(f), ct);

    public Task<(RespuestaSp Cabecera, List<ReporteProductividadModelo> Tecnicos, List<ReporteProductividadModelo> Proveedores)> ProductividadAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _repo.ProductividadAsync(NormalizarFiltro(f), ct);

    public Task<(RespuestaSp Cabecera, List<ReporteSatisfaccionResumenModelo> Resumen, List<ReporteSatisfaccionDetalleModelo> Detalle)> SatisfaccionAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _repo.SatisfaccionAsync(NormalizarFiltro(f), ct);

    public Task<RespuestaSp<ReporteTendenciaModelo>> TendenciaAsync(ReporteFiltroModelo f, CancellationToken ct = default) =>
        _repo.TendenciaAsync(NormalizarFiltro(f), ct);

    public Task<(RespuestaSp Cabecera, List<ActivoHojaVidaModelo> Activo, List<ActivoHojaVidaTicketModelo> Tickets, List<ActivoHojaVidaTotalesModelo> Totales)> HojaVidaAsync(int fiActivoId, CancellationToken ct = default) =>
        _repo.HojaVidaAsync(fiActivoId, ct);
}


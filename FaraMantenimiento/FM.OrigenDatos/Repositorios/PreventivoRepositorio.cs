using System.Data;
using Dapper;
using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Preventivos;
using MySqlConnector;

namespace FM.OrigenDatos.Repositorios;

// Callers: PreventivoServicio
// API: sp_preventivo_listar/obtener/guardar/activar/calendario/generar_tickets + sp_reporte_cumplimiento_preventivo
// Schema: fila estándar + PlanPreventivoModelo / calendario / cumplimiento
// User instruction: "FM.OrigenDatos (Modelos/Preventivos + Repositorios/PreventivoRepositorio)"

public class PreventivoRepositorio
{
    private readonly IEjecutorSp _sp;
    private readonly IFabricaConexion _fabrica;

    public PreventivoRepositorio(IEjecutorSp sp, IFabricaConexion fabrica)
    {
        _sp = sp;
        _fabrica = fabrica;
    }

    public Task<RespuestaSp<PlanPreventivoModelo>> ListarAsync(int? fiSucursalId, bool soloActivos, CancellationToken ct = default) =>
        _sp.EjecutarAsync<PlanPreventivoModelo>("sp_preventivo_listar", new
        {
            p_fiSucursalId = fiSucursalId,
            p_fbSoloActivos = soloActivos ? 1 : 0
        }, ct);

    public async Task<PreventivoObtenerResultado> ObtenerAsync(int fiId, CancellationToken ct = default)
    {
        await using var cn = (MySqlConnection)_fabrica.Crear();
        await cn.OpenAsync(ct);
        await using var multi = await cn.QueryMultipleAsync(new CommandDefinition(
            "sp_preventivo_obtener", new { p_fiId = fiId }, commandType: CommandType.StoredProcedure, cancellationToken: ct));

        var cab = await multi.ReadSingleAsync<RespuestaSp>();
        var result = new PreventivoObtenerResultado { Cabecera = cab };
        if (!cab.FbSucces) return result;

        result.Plan = (await multi.ReadAsync<PlanPreventivoModelo>()).FirstOrDefault();
        if (!multi.IsConsumed)
            result.Ejecuciones = (await multi.ReadAsync<PlanPreventivoEjecucionModelo>()).AsList();
        return result;
    }

    public Task<RespuestaSp> GuardarAsync(
        int? fiId, string fcNombre, int? fiActivoId, int fiSucursalId, int? fiUbicacionId,
        int fiCategoriaId, int fiPrioridadId, string? fcDescripcion, int fiFrecuenciaDias,
        DateTime fdProximaFecha, int fiDiasAnticipacion, int? fiTecnicoId, int? fiProveedorId,
        int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_preventivo_guardar", new
        {
            p_fiId = fiId ?? 0,
            p_fcNombre = fcNombre,
            p_fiActivoId = fiActivoId,
            p_fiSucursalId = fiSucursalId,
            p_fiUbicacionId = fiUbicacionId,
            p_fiCategoriaId = fiCategoriaId,
            p_fiPrioridadId = fiPrioridadId,
            p_fcDescripcion = fcDescripcion,
            p_fiFrecuenciaDias = fiFrecuenciaDias,
            p_fdProximaFecha = fdProximaFecha.Date,
            p_fiDiasAnticipacion = fiDiasAnticipacion,
            p_fiTecnicoId = fiTecnicoId,
            p_fiProveedorId = fiProveedorId,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    public Task<RespuestaSp> ActivarAsync(int fiId, bool fbActivo, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_preventivo_activar", new
        {
            p_fiId = fiId,
            p_fbActivo = fbActivo ? 1 : 0,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    public Task<RespuestaSp<PreventivoCalendarioItemModelo>> CalendarioAsync(DateTime desde, DateTime hasta, CancellationToken ct = default) =>
        _sp.EjecutarAsync<PreventivoCalendarioItemModelo>("sp_preventivo_calendario", new
        {
            p_fdDesde = desde.Date,
            p_fdHasta = hasta.Date
        }, ct);

    public Task<RespuestaSp> GenerarTicketsAsync(DateTime? fdHoy, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_preventivo_generar_tickets", new
        {
            p_fdHoy = (fdHoy ?? DateTime.Today).Date,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    public async Task<(RespuestaSp Cabecera, CumplimientoPreventivoResumenModelo Resumen, List<CumplimientoPreventivoDetalleModelo> Detalle)> CumplimientoAsync(
        DateTime desde, DateTime hasta, int? fiSucursalId, CancellationToken ct = default)
    {
        var (cab, resumen, detalle) = await _sp.EjecutarDosAsync<CumplimientoPreventivoResumenModelo, CumplimientoPreventivoDetalleModelo>(
            "sp_reporte_cumplimiento_preventivo",
            new
            {
                p_fdDesde = desde.Date,
                p_fdHasta = hasta.Date,
                p_fiSucursalId = fiSucursalId
            }, ct);

        return (cab, resumen.FirstOrDefault() ?? new CumplimientoPreventivoResumenModelo(), detalle);
    }
}

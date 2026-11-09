using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Preventivos;
using FM.OrigenDatos.Repositorios;

namespace FM.Programacion.Servicios;

// Callers: PreventivosController, PreventivoTarea
// API: Listar/Obtener/Guardar/Activar/Calendario/Generar/Cumplimiento via PreventivoRepositorio
// User instruction: "FM.Programacion/Servicios/PreventivoServicio"

public class PreventivoServicio
{
    private readonly PreventivoRepositorio _repo;

    public PreventivoServicio(PreventivoRepositorio repo) => _repo = repo;

    public Task<RespuestaSp<PlanPreventivoModelo>> ListarAsync(int? fiSucursalId = null, bool soloActivos = false, CancellationToken ct = default) =>
        _repo.ListarAsync(fiSucursalId, soloActivos, ct);

    public Task<PreventivoObtenerResultado> ObtenerAsync(int fiId, CancellationToken ct = default) =>
        _repo.ObtenerAsync(fiId, ct);

    public Task<RespuestaSp> GuardarAsync(
        int? fiId, string fcNombre, int? fiActivoId, int fiSucursalId, int? fiUbicacionId,
        int fiCategoriaId, int fiPrioridadId, string? fcDescripcion, int fiFrecuenciaDias,
        DateTime fdProximaFecha, int fiDiasAnticipacion, int? fiTecnicoId, int? fiProveedorId,
        int fiUsuarioId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(fcNombre))
            return Task.FromResult(new RespuestaSp { FiCodigo = 400, FcMensaje = "El nombre es obligatorio", FbSucces = false });
        if (fiFrecuenciaDias <= 0)
            return Task.FromResult(new RespuestaSp { FiCodigo = 400, FcMensaje = "La frecuencia en días debe ser mayor a cero", FbSucces = false });
        if (fiDiasAnticipacion < 0)
            return Task.FromResult(new RespuestaSp { FiCodigo = 400, FcMensaje = "Los días de anticipación no son válidos", FbSucces = false });
        if (fiTecnicoId is > 0 && fiProveedorId is > 0)
            return Task.FromResult(new RespuestaSp { FiCodigo = 400, FcMensaje = "Indique técnico o proveedor, no ambos", FbSucces = false });

        return _repo.GuardarAsync(fiId, fcNombre.Trim(), fiActivoId, fiSucursalId, fiUbicacionId,
            fiCategoriaId, fiPrioridadId, fcDescripcion, fiFrecuenciaDias, fdProximaFecha,
            fiDiasAnticipacion, fiTecnicoId, fiProveedorId, fiUsuarioId, ct);
    }

    public Task<RespuestaSp> ActivarAsync(int fiId, bool fbActivo, int fiUsuarioId, CancellationToken ct = default) =>
        _repo.ActivarAsync(fiId, fbActivo, fiUsuarioId, ct);

    public Task<RespuestaSp<PreventivoCalendarioItemModelo>> CalendarioAsync(DateTime desde, DateTime hasta, CancellationToken ct = default) =>
        _repo.CalendarioAsync(desde, hasta, ct);

    public Task<RespuestaSp> GenerarTicketsAsync(int fiUsuarioId, DateTime? fdHoy = null, CancellationToken ct = default) =>
        _repo.GenerarTicketsAsync(fdHoy, fiUsuarioId, ct);

    public Task<(RespuestaSp Cabecera, CumplimientoPreventivoResumenModelo Resumen, List<CumplimientoPreventivoDetalleModelo> Detalle)> CumplimientoAsync(
        DateTime desde, DateTime hasta, int? fiSucursalId = null, CancellationToken ct = default) =>
        _repo.CumplimientoAsync(desde, hasta, fiSucursalId, ct);
}

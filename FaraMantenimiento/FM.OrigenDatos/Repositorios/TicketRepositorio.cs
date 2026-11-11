using System.Data;
using Dapper;
using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Sla;
using FM.OrigenDatos.Modelos.Tickets;
using MySqlConnector;

namespace FM.OrigenDatos.Repositorios;

public class TicketRepositorio
{
    private readonly IEjecutorSp _sp;
    private readonly IFabricaConexion _fabrica;

    public TicketRepositorio(IEjecutorSp sp, IFabricaConexion fabrica)
    {
        _sp = sp;
        _fabrica = fabrica;
    }

    public Task<RespuestaSp> CrearAsync(
        int fiUsuarioId, int fiSucursalId, int? fiUbicacionId, string? fcUbicacionDetalle,
        int? fiActivoId, int fiTipoId, int fiCategoriaId, int fiPrioridadId,
        string fcDescripcion, DateTime? fdFechaSugerida, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_ticket_crear", new
        {
            p_fiUsuarioId = fiUsuarioId,
            p_fiSucursalId = fiSucursalId,
            p_fiUbicacionId = fiUbicacionId,
            p_fcUbicacionDetalle = fcUbicacionDetalle,
            p_fiActivoId = fiActivoId,
            p_fiTipoMantenimientoId = fiTipoId,
            p_fiCategoriaId = fiCategoriaId,
            p_fiPrioridadId = fiPrioridadId,
            p_fcDescripcion = fcDescripcion,
            p_fdFechaSugerida = fdFechaSugerida
        }, ct);

    public Task<RespuestaSp> CambiarEstadoAsync(int fiTicketId, string fcEstadoCodigo, int? fiMotivoEsperaId, string? fcComentario, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_ticket_cambiar_estado", new
        {
            p_fiTicketId = fiTicketId,
            p_fcEstadoCodigo = fcEstadoCodigo,
            p_fiMotivoEsperaId = fiMotivoEsperaId,
            p_fcComentario = fcComentario,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    // Callers: TicketServicio.AsignarAsync. API: sp_ticket_asignar (+SAP). Schema: mig 92.
    // User: "se busca el proveedor SAP y se guarda código + nombre"
    public Task<RespuestaSp> AsignarAsync(int fiTicketId, string fcTipoResponsable, int? fiTecnicoId, int? fiProveedorId,
        string? fcProveedorSapCodigo, string? fcProveedorSapNombre, DateTime? fdFechaProgramada, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_ticket_asignar", new
        {
            p_fiTicketId = fiTicketId,
            p_fcTipoResponsable = fcTipoResponsable,
            p_fiTecnicoId = fiTecnicoId,
            p_fiProveedorId = fiProveedorId,
            p_fcProveedorSapCodigo = fcProveedorSapCodigo,
            p_fcProveedorSapNombre = fcProveedorSapNombre,
            p_fdFechaProgramada = fdFechaProgramada,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    public Task<RespuestaSp> CambiarPrioridadAsync(int fiTicketId, int fiPrioridadId, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_ticket_cambiar_prioridad", new { p_fiTicketId = fiTicketId, p_fiPrioridadId = fiPrioridadId, p_fiUsuarioId = fiUsuarioId }, ct);

    public Task<RespuestaSp> GuardarEjecucionAsync(
        int fiTicketId, DateTime? fdInicio, DateTime? fdFin, decimal? fnHoras,
        decimal? fnManoObra, decimal? fnProveedor, string? diagnostico, string? causa,
        string? trabajo, string? preventivas, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_ticket_ejecucion_guardar", new
        {
            p_fiTicketId = fiTicketId,
            p_fdFechaInicio = fdInicio,
            p_fdFechaFin = fdFin,
            p_fnHorasTrabajadas = fnHoras,
            p_fnCostoManoObra = fnManoObra,
            p_fnCostoProveedor = fnProveedor,
            p_fcDiagnostico = diagnostico,
            p_fcCausaRaiz = causa,
            p_fcTrabajoRealizado = trabajo,
            p_fcAccionesPreventivas = preventivas,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    // Callers: TicketServicio.GuardarMaterialAsync. API: sp_ticket_material_guardar (+fcCodigoSap). Schema: mig 91.
    // User: "se guarda código SAP + descripción + cantidad + costo unitario"
    public Task<RespuestaSp> GuardarMaterialAsync(int? fiId, int fiTicketId, string fcDescripcion, decimal fnCantidad, string? fcUnidad, decimal fnCostoUnitario, string? fcCodigoSap, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_ticket_material_guardar", new
        {
            p_fiId = fiId ?? 0,
            p_fiTicketId = fiTicketId,
            p_fcDescripcion = fcDescripcion,
            p_fnCantidad = fnCantidad,
            p_fcUnidad = fcUnidad,
            p_fnCostoUnitario = fnCostoUnitario,
            p_fcCodigoSap = fcCodigoSap,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    public Task<RespuestaSp> EliminarMaterialAsync(int fiId, int fiUsuarioId, CancellationToken ct = default) =>
        EliminarMaterialAsync(fiId, 0, fiUsuarioId, ct);

    public Task<RespuestaSp> EliminarMaterialAsync(int fiId, int fiTicketId, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_ticket_material_eliminar", new { p_fiId = fiId, p_fiTicketId = fiTicketId, p_fiUsuarioId = fiUsuarioId }, ct);

    public Task<RespuestaSp> GuardarEncuestaAsync(int fiTicketId, int fiCalificacion, bool fbConforme, string? fcComentario, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_ticket_encuesta_guardar", new
        {
            p_fiTicketId = fiTicketId,
            p_fiCalificacion = fiCalificacion,
            p_fbConforme = fbConforme ? 1 : 0,
            p_fcComentario = fcComentario,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    public Task<RespuestaSp> AgregarComentarioAsync(int fiTicketId, string fcComentario, bool fbInterno, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_ticket_comentario_agregar", new
        {
            p_fiTicketId = fiTicketId,
            p_fcComentario = fcComentario,
            p_fbInterno = fbInterno ? 1 : 0,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    public async Task<RespuestaSp<TicketListaModelo>> ListarAsync(object filtros, CancellationToken ct = default) =>
        await _sp.EjecutarAsync<TicketListaModelo>("sp_ticket_listar", filtros, ct);

    public async Task<TicketObtenerResultado> ObtenerAsync(int fiTicketId, CancellationToken ct = default)
    {
        await using var cn = (MySqlConnection)_fabrica.Crear();
        await cn.OpenAsync(ct);
        await using var multi = await cn.QueryMultipleAsync(new CommandDefinition(
            "sp_ticket_obtener", new { p_fiTicketId = fiTicketId }, commandType: CommandType.StoredProcedure, cancellationToken: ct));

        var cab = await multi.ReadSingleAsync<RespuestaSp>();
        var result = new TicketObtenerResultado { Cabecera = cab };
        if (!cab.FbSucces) return result;

        result.Ticket = (await multi.ReadAsync<TicketDetalleModelo>()).FirstOrDefault();
        if (!multi.IsConsumed) result.Historial = (await multi.ReadAsync<TicketEstadoHistorialModelo>()).AsList();
        if (!multi.IsConsumed) result.Materiales = (await multi.ReadAsync<TicketMaterialModelo>()).AsList();
        if (!multi.IsConsumed) result.Encuesta = (await multi.ReadAsync<TicketEncuestaModelo>()).FirstOrDefault();
        if (!multi.IsConsumed) result.Comentarios = (await multi.ReadAsync<TicketComentarioModelo>()).AsList();
        return result;
    }

    public Task<RespuestaSp> SlaRevisarVencimientosAsync(DateTime ahora, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_sla_revisar_vencimientos", new { p_fdAhora = ahora }, ct);

    public Task<RespuestaSp> SlaCierreAutomaticoAsync(DateTime ahora, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_ticket_cierre_automatico", new { p_fdAhora = ahora }, ct);

    public Task<RespuestaSp<SlaAlertaModelo>> SlaAlertasListarAsync(bool soloNoNotificadas, int limite, CancellationToken ct = default) =>
        _sp.EjecutarAsync<SlaAlertaModelo>("sp_sla_alertas_listar", new
        {
            p_fbSoloNoNotificadas = soloNoNotificadas ? 1 : 0,
            p_fiLimite = limite
        }, ct);

    public Task<RespuestaSp<SlaAlertaConteoModelo>> SlaAlertasContarAsync(bool soloNoNotificadas, CancellationToken ct = default) =>
        _sp.EjecutarAsync<SlaAlertaConteoModelo>("sp_sla_alertas_contar", new
        {
            p_fbSoloNoNotificadas = soloNoNotificadas ? 1 : 0
        }, ct);

    // Recordatorio diario de SLA vencido (migración 93).
    public Task<RespuestaSp<TicketRecordatorioSlaModelo>> RecordatorioSlaObtenerAsync(int fiTicketId, CancellationToken ct = default) =>
        _sp.EjecutarAsync<TicketRecordatorioSlaModelo>("sp_ticket_recordatorio_sla_obtener", new { p_fiTicketId = fiTicketId }, ct);

    public Task<RespuestaSp> RecordatorioSlaCambiarAsync(int fiTicketId, bool sinRecordatorio, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_ticket_recordatorio_sla_cambiar", new
        {
            p_fiTicketId = fiTicketId,
            p_fbSinRecordatorio = sinRecordatorio ? 1 : 0,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    // Vistas de la pantalla Tickets (migración 99): el filtrado por vista y permiso está en el SP.
    public Task<RespuestaSp<TicketListaModelo>> ListarVistaAsync(object filtros, CancellationToken ct = default) =>
        _sp.EjecutarAsync<TicketListaModelo>("sp_ticket_listar_vista", filtros, ct);

    public Task<RespuestaSp<TicketVistaResumenModelo>> VistasResumenAsync(int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync<TicketVistaResumenModelo>("sp_ticket_vistas_resumen", new { p_fiUsuarioId = fiUsuarioId }, ct);

    public Task<RespuestaSp> PuedeVerAsync(int fiTicketId, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_ticket_puede_ver", new { p_fiTicketId = fiTicketId, p_fiUsuarioId = fiUsuarioId }, ct);
}

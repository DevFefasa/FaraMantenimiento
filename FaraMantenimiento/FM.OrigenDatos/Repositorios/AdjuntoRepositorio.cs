using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Adjunto;

namespace FM.OrigenDatos.Repositorios;

public class AdjuntoRepositorio
{
    private readonly IEjecutorSp _sp;

    public AdjuntoRepositorio(IEjecutorSp sp) => _sp = sp;

    public Task<RespuestaSp> GuardarAsync(
        string fcEntidad, int fiEntidadId, string fcEtapa, string fcNombreOriginal,
        string fcRuta, string? fcTipoMime, long fiTamanoBytes, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_adjunto_guardar", new
        {
            p_fcEntidad = fcEntidad,
            p_fiEntidadId = fiEntidadId,
            p_fcEtapa = fcEtapa,
            p_fcNombreOriginal = fcNombreOriginal,
            p_fcRuta = fcRuta,
            p_fcTipoMime = fcTipoMime,
            p_fiTamanoBytes = fiTamanoBytes,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    public Task<RespuestaSp<AdjuntoModelo>> ListarAsync(string fcEntidad, int fiEntidadId, string? fcEtapa = null, CancellationToken ct = default) =>
        _sp.EjecutarAsync<AdjuntoModelo>("sp_adjunto_listar", new
        {
            p_fcEntidad = fcEntidad,
            p_fiEntidadId = fiEntidadId,
            p_fcEtapa = fcEtapa
        }, ct);

    public Task<RespuestaSp<AdjuntoModelo>> ObtenerAsync(int fiId, CancellationToken ct = default) =>
        _sp.EjecutarAsync<AdjuntoModelo>("sp_adjunto_obtener", new { p_fiId = fiId }, ct);

    public Task<RespuestaSp> EliminarAsync(int fiId, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_adjunto_eliminar", new { p_fiId = fiId, p_fiUsuarioId = fiUsuarioId }, ct);
}

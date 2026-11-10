// Callers: CorreoPendienteServicio.EncolarBienvenidaAsync
// API: sp_seguridad_correo_pendiente_guardar
// Schema: correopendiente (migraciones 75/79)
// User instruction: "puedes crear... repositorios en FM.OrigenDatos/Repositorios para la bandeja de correos"
using FM.OrigenDatos.Conexion;

namespace FM.OrigenDatos.Repositorios;

public class CorreoPendienteRepositorio
{
    private readonly IEjecutorSp _sp;

    public CorreoPendienteRepositorio(IEjecutorSp sp) => _sp = sp;

    public Task<RespuestaSp> GuardarAsync(
        string fcPara, string fcAsunto, string fcCuerpoCifrado, string fcTipo, int? fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_seguridad_correo_pendiente_guardar", new
        {
            p_fcPara = fcPara,
            p_fcAsunto = fcAsunto,
            p_fcCuerpoCifrado = fcCuerpoCifrado,
            p_fcTipo = fcTipo,
            p_fiUsuarioId = fiUsuarioId
        }, ct);
}

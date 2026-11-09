using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Seguridad;

namespace FM.OrigenDatos.Repositorios;

public class SeguridadRepositorio
{
    private readonly IEjecutorSp _sp;

    public SeguridadRepositorio(IEjecutorSp sp) => _sp = sp;

    public Task<RespuestaSp<UsuarioModelo>> ObtenerPorLoginAsync(string fcUsuario, CancellationToken ct = default) =>
        _sp.EjecutarAsync<UsuarioModelo>("sp_seguridad_usuario_por_login", new { p_fcUsuario = fcUsuario }, ct);

    public Task<RespuestaSp<UsuarioModelo>> LoginAdAltaAsync(
        string fcUsuario, string? fcNombre, string? fcCorreo, string? fcCargo, string? fcTelefono, CancellationToken ct = default) =>
        _sp.EjecutarAsync<UsuarioModelo>("sp_seguridad_login_ad_alta", new
        {
            p_fcUsuario = fcUsuario,
            p_fcNombre = fcNombre,
            p_fcCorreo = fcCorreo,
            p_fcCargo = fcCargo,
            p_fcTelefono = fcTelefono
        }, ct);

    public Task<RespuestaSp> RegistrarAccesoAsync(int? fiUsuarioId, string? fcUsuario, string fcAccion, string? fcIp, string? fcDetalle, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_seguridad_registrar_acceso", new
        {
            p_fiUsuarioId = fiUsuarioId,
            p_fcUsuario = fcUsuario,
            p_fcAccion = fcAccion,
            p_fcIp = fcIp,
            p_fcDetalle = fcDetalle
        }, ct);

    public Task<RespuestaSp<PermisoPantallaModelo>> PermisosUsuarioAsync(int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync<PermisoPantallaModelo>("sp_seguridad_permisos_usuario", new { p_fiUsuarioId = fiUsuarioId }, ct);

    public Task<RespuestaSp<UsuarioModelo>> ListarUsuariosAsync(bool soloActivos = true, CancellationToken ct = default) =>
        _sp.EjecutarAsync<UsuarioModelo>("sp_seguridad_usuario_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0 }, ct);

    public Task<RespuestaSp<UsuarioModelo>> ObtenerUsuarioAsync(int fiId, CancellationToken ct = default) =>
        _sp.EjecutarAsync<UsuarioModelo>("sp_seguridad_usuario_obtener", new { p_fiId = fiId }, ct);

    public Task<RespuestaSp> GuardarUsuarioAsync(
        int? fiId, string fcUsuario, string fcNombre, string? fcCargo, string? fcCorreo, string? fcTelefono,
        int fiRolId, int? fiSucursalId, bool fbEsLocal, string? fcClaveHash, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_seguridad_usuario_guardar", new
        {
            p_fiId = fiId ?? 0,
            p_fcUsuario = fcUsuario,
            p_fcNombre = fcNombre,
            p_fcCargo = fcCargo,
            p_fcCorreo = fcCorreo,
            p_fcTelefono = fcTelefono,
            p_fiRolId = fiRolId,
            p_fiSucursalId = fiSucursalId,
            p_fbEsLocal = fbEsLocal ? 1 : 0,
            p_fcClaveHash = fcClaveHash,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    public Task<RespuestaSp> ActivarUsuarioAsync(int fiId, bool fbActivo, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_seguridad_usuario_activar", new { p_fiId = fiId, p_fbActivo = fbActivo ? 1 : 0, p_fiUsuarioId = fiUsuarioId }, ct);

    public Task<RespuestaSp<RolModelo>> ListarRolesAsync(bool soloActivos = true, CancellationToken ct = default) =>
        _sp.EjecutarAsync<RolModelo>("sp_seguridad_rol_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0 }, ct);

    public Task<RespuestaSp<PantallaModelo>> ListarPantallasAsync(bool soloActivos = true, CancellationToken ct = default) =>
        _sp.EjecutarAsync<PantallaModelo>("sp_seguridad_pantalla_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0 }, ct);

    public Task<(RespuestaSp Cabecera, List<RolModelo> Rol, List<PantallaModelo> Pantallas)> ObtenerRolPermisosAsync(int fiRolId, CancellationToken ct = default) =>
        _sp.EjecutarDosAsync<RolModelo, PantallaModelo>("sp_seguridad_rol_permisos_obtener", new { p_fiRolId = fiRolId }, ct);

    public Task<RespuestaSp> GuardarRolPermisosAsync(int fiRolId, IEnumerable<string> pantallas, int fiUsuarioId, CancellationToken ct = default)
    {
        var csv = string.Join(",", pantallas.Where(p => !string.IsNullOrWhiteSpace(p)).Select(p => p.Trim()));
        return _sp.EjecutarAsync("sp_seguridad_rol_permisos_guardar", new
        {
            p_fiRolId = fiRolId,
            p_fcPantallas = csv,
            p_fiUsuarioId = fiUsuarioId
        }, ct);
    }

    public Task<RespuestaSp> GuardarRolAsync(int? fiId, string fcCodigo, string fcNombre, string? fcDescripcion, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_seguridad_rol_guardar", new
        {
            p_fiId = fiId ?? 0,
            p_fcCodigo = fcCodigo,
            p_fcNombre = fcNombre,
            p_fcDescripcion = fcDescripcion,
            p_fiUsuarioId = fiUsuarioId
        }, ct);

    public Task<RespuestaSp> ActivarRolAsync(int fiId, bool fbActivo, int fiUsuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_seguridad_rol_activar", new { p_fiId = fiId, p_fbActivo = fbActivo ? 1 : 0, p_fiUsuarioId = fiUsuarioId }, ct);
}

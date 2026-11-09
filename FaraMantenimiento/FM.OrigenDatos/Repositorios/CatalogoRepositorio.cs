using System.Data;
using Dapper;
using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Catalogos;
using MySqlConnector;

namespace FM.OrigenDatos.Repositorios;

// Callers: CatalogoServicio
// API: ObtenerCombosAsync (único) + CRUD sp_catalogo_* (13-19)
// User instruction: "hay DOS metodos duplicados de combos ... deja uno solo" + "Implementa los metodos para todos los SP sp_catalogo_* existentes (13-19)."

public class CatalogoRepositorio
{
    private readonly IEjecutorSp _sp;
    private readonly IFabricaConexion _fabrica;

    public CatalogoRepositorio(IEjecutorSp sp, IFabricaConexion fabrica)
    {
        _sp = sp;
        _fabrica = fabrica;
    }

    public async Task<(RespuestaSp Cabecera, CatalogoCombosModelo Combos)> ObtenerCombosAsync(CancellationToken ct = default)
    {
        await using var cn = (MySqlConnection)_fabrica.Crear();
        await cn.OpenAsync(ct);
        await using var multi = await cn.QueryMultipleAsync(new CommandDefinition(
            "sp_catalogo_combos", commandType: CommandType.StoredProcedure, cancellationToken: ct));

        var cab = await multi.ReadSingleAsync<RespuestaSp>();
        var combos = new CatalogoCombosModelo();
        if (!cab.FbSucces) return (cab, combos);

        combos.Regiones = (await multi.ReadAsync<CatalogoItemModelo>()).AsList();
        combos.Sucursales = (await multi.ReadAsync<CatalogoItemModelo>()).AsList();
        combos.Ubicaciones = (await multi.ReadAsync<CatalogoItemModelo>()).AsList();
        combos.Activos = (await multi.ReadAsync<CatalogoItemModelo>()).AsList();
        combos.Tipos = (await multi.ReadAsync<CatalogoItemModelo>()).AsList();
        combos.Categorias = (await multi.ReadAsync<CatalogoItemModelo>()).AsList();
        combos.Prioridades = (await multi.ReadAsync<CatalogoItemModelo>()).AsList();
        combos.Estados = (await multi.ReadAsync<CatalogoItemModelo>()).AsList();
        combos.MotivosEspera = (await multi.ReadAsync<CatalogoItemModelo>()).AsList();
        combos.Proveedores = (await multi.ReadAsync<CatalogoItemModelo>()).AsList();
        combos.Tecnicos = (await multi.ReadAsync<CatalogoItemModelo>()).AsList();
        return (cab, combos);
    }

    public Task<RespuestaSp<RegionModelo>> RegionListarAsync(bool soloActivos, CancellationToken ct = default) =>
        _sp.EjecutarAsync<RegionModelo>("sp_catalogo_region_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0 }, ct);
    public Task<RespuestaSp<RegionModelo>> RegionObtenerAsync(int id, CancellationToken ct = default) =>
        _sp.EjecutarAsync<RegionModelo>("sp_catalogo_region_obtener", new { p_fiId = id }, ct);
    public Task<RespuestaSp> RegionGuardarAsync(int? id, string codigo, string nombre, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_region_guardar", new { p_fiId = id ?? 0, p_fcCodigo = codigo, p_fcNombre = nombre, p_fiUsuarioId = usuarioId }, ct);
    public Task<RespuestaSp> RegionActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_region_activar", new { p_fiId = id, p_fbActivo = activo ? 1 : 0, p_fiUsuarioId = usuarioId }, ct);

    public Task<RespuestaSp<SucursalModelo>> SucursalListarAsync(bool soloActivos, int? regionId, CancellationToken ct = default) =>
        _sp.EjecutarAsync<SucursalModelo>("sp_catalogo_sucursal_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0, p_fiRegionId = regionId }, ct);
    public Task<RespuestaSp<SucursalModelo>> SucursalObtenerAsync(int id, CancellationToken ct = default) =>
        _sp.EjecutarAsync<SucursalModelo>("sp_catalogo_sucursal_obtener", new { p_fiId = id }, ct);
    public Task<RespuestaSp> SucursalGuardarAsync(int? id, string codigo, string nombre, string tipo, int regionId, string? direccion, string? telefono, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_sucursal_guardar", new { p_fiId = id ?? 0, p_fcCodigo = codigo, p_fcNombre = nombre, p_fcTipo = tipo, p_fiRegionId = regionId, p_fcDireccion = direccion, p_fcTelefono = telefono, p_fiUsuarioId = usuarioId }, ct);
    public Task<RespuestaSp> SucursalActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_sucursal_activar", new { p_fiId = id, p_fbActivo = activo ? 1 : 0, p_fiUsuarioId = usuarioId }, ct);

    public Task<RespuestaSp<UbicacionModelo>> UbicacionListarAsync(bool soloActivos, int? sucursalId, CancellationToken ct = default) =>
        _sp.EjecutarAsync<UbicacionModelo>("sp_catalogo_ubicacion_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0, p_fiSucursalId = sucursalId }, ct);
    public Task<RespuestaSp<UbicacionModelo>> UbicacionObtenerAsync(int id, CancellationToken ct = default) =>
        _sp.EjecutarAsync<UbicacionModelo>("sp_catalogo_ubicacion_obtener", new { p_fiId = id }, ct);
    public Task<RespuestaSp> UbicacionGuardarAsync(int? id, string codigo, string nombre, int sucursalId, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_ubicacion_guardar", new { p_fiId = id ?? 0, p_fcCodigo = codigo, p_fcNombre = nombre, p_fiSucursalId = sucursalId, p_fiUsuarioId = usuarioId }, ct);
    public Task<RespuestaSp> UbicacionActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_ubicacion_activar", new { p_fiId = id, p_fbActivo = activo ? 1 : 0, p_fiUsuarioId = usuarioId }, ct);

    public Task<RespuestaSp<ActivoModelo>> ActivoListarAsync(bool soloActivos, int? sucursalId, int? categoriaId, CancellationToken ct = default) =>
        _sp.EjecutarAsync<ActivoModelo>("sp_catalogo_activo_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0, p_fiSucursalId = sucursalId, p_fiCategoriaId = categoriaId }, ct);
    public Task<RespuestaSp<ActivoModelo>> ActivoObtenerAsync(int id, CancellationToken ct = default) =>
        _sp.EjecutarAsync<ActivoModelo>("sp_catalogo_activo_obtener", new { p_fiId = id }, ct);
    public Task<RespuestaSp> ActivoGuardarAsync(int? id, string codigo, string nombre, string? marca, string? modelo, string? serie, int sucursalId, int? ubicacionId, int? categoriaId, DateTime? fechaInstalacion, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_activo_guardar", new { p_fiId = id ?? 0, p_fcCodigo = codigo, p_fcNombre = nombre, p_fcMarca = marca, p_fcModelo = modelo, p_fcSerie = serie, p_fiSucursalId = sucursalId, p_fiUbicacionId = ubicacionId, p_fiCategoriaId = categoriaId, p_fdFechaInstalacion = fechaInstalacion, p_fiUsuarioId = usuarioId }, ct);
    public Task<RespuestaSp> ActivoActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_activo_activar", new { p_fiId = id, p_fbActivo = activo ? 1 : 0, p_fiUsuarioId = usuarioId }, ct);

    public Task<RespuestaSp<TipoMantenimientoModelo>> TipoListarAsync(bool soloActivos, CancellationToken ct = default) =>
        _sp.EjecutarAsync<TipoMantenimientoModelo>("sp_catalogo_tipomantenimiento_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0 }, ct);
    public Task<RespuestaSp<TipoMantenimientoModelo>> TipoObtenerAsync(int id, CancellationToken ct = default) =>
        _sp.EjecutarAsync<TipoMantenimientoModelo>("sp_catalogo_tipomantenimiento_obtener", new { p_fiId = id }, ct);
    public Task<RespuestaSp> TipoGuardarAsync(int? id, string codigo, string nombre, bool reqAprob, bool prev, bool post, bool reqFecha, int orden, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_tipomantenimiento_guardar", new { p_fiId = id ?? 0, p_fcCodigo = codigo, p_fcNombre = nombre, p_fbRequiereAprobacion = reqAprob ? 1 : 0, p_fbEsPreventivo = prev ? 1 : 0, p_fbEsPostFalla = post ? 1 : 0, p_fbRequiereFechaSugerida = reqFecha ? 1 : 0, p_fiOrden = orden, p_fiUsuarioId = usuarioId }, ct);
    public Task<RespuestaSp> TipoActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_tipomantenimiento_activar", new { p_fiId = id, p_fbActivo = activo ? 1 : 0, p_fiUsuarioId = usuarioId }, ct);

    public Task<RespuestaSp<CategoriaModelo>> CategoriaListarAsync(bool soloActivos, CancellationToken ct = default) =>
        _sp.EjecutarAsync<CategoriaModelo>("sp_catalogo_categoria_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0 }, ct);
    public Task<RespuestaSp<CategoriaModelo>> CategoriaObtenerAsync(int id, CancellationToken ct = default) =>
        _sp.EjecutarAsync<CategoriaModelo>("sp_catalogo_categoria_obtener", new { p_fiId = id }, ct);
    public Task<RespuestaSp> CategoriaGuardarAsync(int? id, string codigo, string nombre, int orden, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_categoria_guardar", new { p_fiId = id ?? 0, p_fcCodigo = codigo, p_fcNombre = nombre, p_fiOrden = orden, p_fiUsuarioId = usuarioId }, ct);
    public Task<RespuestaSp> CategoriaActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_categoria_activar", new { p_fiId = id, p_fbActivo = activo ? 1 : 0, p_fiUsuarioId = usuarioId }, ct);

    public Task<RespuestaSp<PrioridadModelo>> PrioridadListarAsync(bool soloActivos, CancellationToken ct = default) =>
        _sp.EjecutarAsync<PrioridadModelo>("sp_catalogo_prioridad_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0 }, ct);
    public Task<RespuestaSp<PrioridadModelo>> PrioridadObtenerAsync(int id, CancellationToken ct = default) =>
        _sp.EjecutarAsync<PrioridadModelo>("sp_catalogo_prioridad_obtener", new { p_fiId = id }, ct);
    public Task<RespuestaSp> PrioridadGuardarAsync(int? id, string codigo, string nombre, int horasResp, int horasSol, string? color, int orden, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_prioridad_guardar", new { p_fiId = id ?? 0, p_fcCodigo = codigo, p_fcNombre = nombre, p_fiHorasRespuesta = horasResp, p_fiHorasSolucion = horasSol, p_fcColor = color, p_fiOrden = orden, p_fiUsuarioId = usuarioId }, ct);
    public Task<RespuestaSp> PrioridadActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_prioridad_activar", new { p_fiId = id, p_fbActivo = activo ? 1 : 0, p_fiUsuarioId = usuarioId }, ct);

    public Task<RespuestaSp<EstadoModelo>> EstadoListarAsync(bool soloActivos, CancellationToken ct = default) =>
        _sp.EjecutarAsync<EstadoModelo>("sp_catalogo_estado_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0 }, ct);
    public Task<RespuestaSp<EstadoModelo>> EstadoObtenerAsync(int id, CancellationToken ct = default) =>
        _sp.EjecutarAsync<EstadoModelo>("sp_catalogo_estado_obtener", new { p_fiId = id }, ct);
    public Task<RespuestaSp> EstadoGuardarAsync(int? id, string codigo, string nombre, int orden, string? color, bool final, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_estado_guardar", new { p_fiId = id ?? 0, p_fcCodigo = codigo, p_fcNombre = nombre, p_fiOrden = orden, p_fcColor = color, p_fbFinal = final ? 1 : 0, p_fiUsuarioId = usuarioId }, ct);
    public Task<RespuestaSp> EstadoActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_estado_activar", new { p_fiId = id, p_fbActivo = activo ? 1 : 0, p_fiUsuarioId = usuarioId }, ct);

    public Task<RespuestaSp<MotivoEsperaModelo>> MotivoListarAsync(bool soloActivos, CancellationToken ct = default) =>
        _sp.EjecutarAsync<MotivoEsperaModelo>("sp_catalogo_motivoespera_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0 }, ct);
    public Task<RespuestaSp<MotivoEsperaModelo>> MotivoObtenerAsync(int id, CancellationToken ct = default) =>
        _sp.EjecutarAsync<MotivoEsperaModelo>("sp_catalogo_motivoespera_obtener", new { p_fiId = id }, ct);
    public Task<RespuestaSp> MotivoGuardarAsync(int? id, string codigo, string nombre, int orden, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_motivoespera_guardar", new { p_fiId = id ?? 0, p_fcCodigo = codigo, p_fcNombre = nombre, p_fiOrden = orden, p_fiUsuarioId = usuarioId }, ct);
    public Task<RespuestaSp> MotivoActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_motivoespera_activar", new { p_fiId = id, p_fbActivo = activo ? 1 : 0, p_fiUsuarioId = usuarioId }, ct);

    public Task<RespuestaSp<ProveedorModelo>> ProveedorListarAsync(bool soloActivos, CancellationToken ct = default) =>
        _sp.EjecutarAsync<ProveedorModelo>("sp_catalogo_proveedor_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0 }, ct);
    public Task<RespuestaSp<ProveedorModelo>> ProveedorObtenerAsync(int id, CancellationToken ct = default) =>
        _sp.EjecutarAsync<ProveedorModelo>("sp_catalogo_proveedor_obtener", new { p_fiId = id }, ct);
    public Task<RespuestaSp> ProveedorGuardarAsync(int? id, string codigo, string nombre, string? rtn, string? contacto, string? telefono, string? correo, string? especialidad, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_proveedor_guardar", new { p_fiId = id ?? 0, p_fcCodigo = codigo, p_fcNombre = nombre, p_fcRtn = rtn, p_fcContacto = contacto, p_fcTelefono = telefono, p_fcCorreo = correo, p_fcEspecialidad = especialidad, p_fiUsuarioId = usuarioId }, ct);
    public Task<RespuestaSp> ProveedorActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_proveedor_activar", new { p_fiId = id, p_fbActivo = activo ? 1 : 0, p_fiUsuarioId = usuarioId }, ct);

    public Task<RespuestaSp<TecnicoModelo>> TecnicoListarAsync(bool soloActivos, int? categoriaId, CancellationToken ct = default) =>
        _sp.EjecutarAsync<TecnicoModelo>("sp_catalogo_tecnico_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0, p_fiCategoriaId = categoriaId }, ct);
    public Task<RespuestaSp<TecnicoModelo>> TecnicoObtenerAsync(int id, CancellationToken ct = default) =>
        _sp.EjecutarAsync<TecnicoModelo>("sp_catalogo_tecnico_obtener", new { p_fiId = id }, ct);
    public Task<RespuestaSp> TecnicoGuardarAsync(int? id, string codigo, string nombre, int? usuarioRef, string? telefono, int? categoriaId, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_tecnico_guardar", new { p_fiId = id ?? 0, p_fcCodigo = codigo, p_fcNombre = nombre, p_fiUsuarioIdRef = usuarioRef, p_fcTelefono = telefono, p_fiCategoriaId = categoriaId, p_fiUsuarioId = usuarioId }, ct);
    public Task<RespuestaSp> TecnicoActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_tecnico_activar", new { p_fiId = id, p_fbActivo = activo ? 1 : 0, p_fiUsuarioId = usuarioId }, ct);

    public Task<RespuestaSp<ParametroModelo>> ParametroListarAsync(bool soloActivos, CancellationToken ct = default) =>
        _sp.EjecutarAsync<ParametroModelo>("sp_catalogo_parametro_listar", new { p_fbSoloActivos = soloActivos ? 1 : 0 }, ct);
    public Task<RespuestaSp<ParametroModelo>> ParametroObtenerAsync(int id, CancellationToken ct = default) =>
        _sp.EjecutarAsync<ParametroModelo>("sp_catalogo_parametro_obtener", new { p_fiId = id }, ct);
    public Task<RespuestaSp> ParametroGuardarAsync(int? id, string clave, string valor, string? descripcion, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_parametro_guardar", new { p_fiId = id ?? 0, p_fcClave = clave, p_fcValor = valor, p_fcDescripcion = descripcion, p_fiUsuarioId = usuarioId }, ct);
    public Task<RespuestaSp> ParametroActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) =>
        _sp.EjecutarAsync("sp_catalogo_parametro_activar", new { p_fiId = id, p_fbActivo = activo ? 1 : 0, p_fiUsuarioId = usuarioId }, ct);
}

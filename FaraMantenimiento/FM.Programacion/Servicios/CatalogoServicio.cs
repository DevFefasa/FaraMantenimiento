using ClosedXML.Excel;
using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Catalogos;
using FM.OrigenDatos.Repositorios;
using Microsoft.AspNetCore.Http;

namespace FM.Programacion.Servicios;

// Callers: CatalogosController, TicketsController, ReportesController, DashboardController, PreventivosController
// API: ObtenerCombosAsync (único) + CRUD catálogos + CargarActivosExcelAsync / PlantillaActivos
// User instruction: unificar combos + implementar SP 13-19 + carga masiva Excel ClosedXML

public class CatalogoServicio
{
    private readonly CatalogoRepositorio _repo;

    public CatalogoServicio(CatalogoRepositorio repo) => _repo = repo;

    public Task<(RespuestaSp Cabecera, CatalogoCombosModelo Combos)> ObtenerCombosAsync(CancellationToken ct = default) =>
        _repo.ObtenerCombosAsync(ct);

    /// <summary>Adapta combos al modelo legacy de Reportes/Dashboard (Views/Reportes no se tocan).</summary>
    public FM.OrigenDatos.Modelos.Catalogo.CatalogoCombosModelo ACombosReporte(CatalogoCombosModelo c) => new()
    {
        Regiones = MapItems(c.Regiones),
        Sucursales = MapItems(c.Sucursales),
        Tipos = MapItems(c.Tipos),
        Categorias = MapItems(c.Categorias),
        Prioridades = MapItems(c.Prioridades),
        Estados = MapItems(c.Estados),
        Tecnicos = MapItems(c.Tecnicos),
        Proveedores = MapItems(c.Proveedores),
        Activos = MapItems(c.Activos)
    };

    private static List<FM.OrigenDatos.Modelos.Catalogo.CatalogoItemModelo> MapItems(IEnumerable<CatalogoItemModelo> src) =>
        src.Select(x => new FM.OrigenDatos.Modelos.Catalogo.CatalogoItemModelo
        {
            FiId = x.FiId,
            FcCodigo = x.FcCodigo,
            FcNombre = x.FcNombre,
            FiRegionId = x.FiRegionId,
            FiSucursalId = x.FiSucursalId,
            FcTipo = x.FcTipo,
            FbEsPreventivo = x.FbEsPreventivo,
            FiOrden = x.FiOrden ?? 0
        }).ToList();

    public Task<RespuestaSp<RegionModelo>> RegionListarAsync(bool soloActivos = false, CancellationToken ct = default) => _repo.RegionListarAsync(soloActivos, ct);
    public Task<RespuestaSp<RegionModelo>> RegionObtenerAsync(int id, CancellationToken ct = default) => _repo.RegionObtenerAsync(id, ct);
    public Task<RespuestaSp> RegionGuardarAsync(int? id, string codigo, string nombre, int usuarioId, CancellationToken ct = default) => _repo.RegionGuardarAsync(id, codigo, nombre, usuarioId, ct);
    public Task<RespuestaSp> RegionActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) => _repo.RegionActivarAsync(id, activo, usuarioId, ct);

    public Task<RespuestaSp<SucursalModelo>> SucursalListarAsync(bool soloActivos = false, int? regionId = null, CancellationToken ct = default) => _repo.SucursalListarAsync(soloActivos, regionId, ct);
    public Task<RespuestaSp<SucursalModelo>> SucursalObtenerAsync(int id, CancellationToken ct = default) => _repo.SucursalObtenerAsync(id, ct);
    public Task<RespuestaSp> SucursalGuardarAsync(int? id, string codigo, string nombre, string tipo, int regionId, string? direccion, string? telefono, int usuarioId, CancellationToken ct = default) =>
        _repo.SucursalGuardarAsync(id, codigo, nombre, tipo, regionId, direccion, telefono, usuarioId, ct);
    public Task<RespuestaSp> SucursalActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) => _repo.SucursalActivarAsync(id, activo, usuarioId, ct);

    public Task<RespuestaSp<UbicacionModelo>> UbicacionListarAsync(bool soloActivos = false, int? sucursalId = null, CancellationToken ct = default) => _repo.UbicacionListarAsync(soloActivos, sucursalId, ct);
    public Task<RespuestaSp<UbicacionModelo>> UbicacionObtenerAsync(int id, CancellationToken ct = default) => _repo.UbicacionObtenerAsync(id, ct);
    public Task<RespuestaSp> UbicacionGuardarAsync(int? id, string codigo, string nombre, int sucursalId, int usuarioId, CancellationToken ct = default) => _repo.UbicacionGuardarAsync(id, codigo, nombre, sucursalId, usuarioId, ct);
    public Task<RespuestaSp> UbicacionActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) => _repo.UbicacionActivarAsync(id, activo, usuarioId, ct);

    public Task<RespuestaSp<ActivoModelo>> ActivoListarAsync(bool soloActivos = false, int? sucursalId = null, int? categoriaId = null, CancellationToken ct = default) =>
        _repo.ActivoListarAsync(soloActivos, sucursalId, categoriaId, ct);
    public Task<RespuestaSp<ActivoModelo>> ActivoObtenerAsync(int id, CancellationToken ct = default) => _repo.ActivoObtenerAsync(id, ct);
    public Task<RespuestaSp> ActivoGuardarAsync(int? id, string codigo, string nombre, string? marca, string? modelo, string? serie, int sucursalId, int? ubicacionId, int? categoriaId, DateTime? fechaInstalacion, int usuarioId, CancellationToken ct = default) =>
        _repo.ActivoGuardarAsync(id, codigo, nombre, marca, modelo, serie, sucursalId, ubicacionId, categoriaId, fechaInstalacion, usuarioId, ct);
    public Task<RespuestaSp> ActivoActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) => _repo.ActivoActivarAsync(id, activo, usuarioId, ct);

    public Task<RespuestaSp<TipoMantenimientoModelo>> TipoListarAsync(bool soloActivos = false, CancellationToken ct = default) => _repo.TipoListarAsync(soloActivos, ct);
    public Task<RespuestaSp<TipoMantenimientoModelo>> TipoObtenerAsync(int id, CancellationToken ct = default) => _repo.TipoObtenerAsync(id, ct);
    public Task<RespuestaSp> TipoGuardarAsync(int? id, string codigo, string nombre, bool reqAprob, bool prev, bool post, bool reqFecha, int orden, int usuarioId, CancellationToken ct = default) =>
        _repo.TipoGuardarAsync(id, codigo, nombre, reqAprob, prev, post, reqFecha, orden, usuarioId, ct);
    public Task<RespuestaSp> TipoActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) => _repo.TipoActivarAsync(id, activo, usuarioId, ct);

    public Task<RespuestaSp<CategoriaModelo>> CategoriaListarAsync(bool soloActivos = false, CancellationToken ct = default) => _repo.CategoriaListarAsync(soloActivos, ct);
    public Task<RespuestaSp<CategoriaModelo>> CategoriaObtenerAsync(int id, CancellationToken ct = default) => _repo.CategoriaObtenerAsync(id, ct);
    public Task<RespuestaSp> CategoriaGuardarAsync(int? id, string codigo, string nombre, int orden, int usuarioId, CancellationToken ct = default) => _repo.CategoriaGuardarAsync(id, codigo, nombre, orden, usuarioId, ct);
    public Task<RespuestaSp> CategoriaActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) => _repo.CategoriaActivarAsync(id, activo, usuarioId, ct);

    public Task<RespuestaSp<PrioridadModelo>> PrioridadListarAsync(bool soloActivos = false, CancellationToken ct = default) => _repo.PrioridadListarAsync(soloActivos, ct);
    public Task<RespuestaSp<PrioridadModelo>> PrioridadObtenerAsync(int id, CancellationToken ct = default) => _repo.PrioridadObtenerAsync(id, ct);
    public Task<RespuestaSp> PrioridadGuardarAsync(int? id, string codigo, string nombre, int horasResp, int horasSol, string? color, int orden, int usuarioId, CancellationToken ct = default) =>
        _repo.PrioridadGuardarAsync(id, codigo, nombre, horasResp, horasSol, color, orden, usuarioId, ct);
    public Task<RespuestaSp> PrioridadActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) => _repo.PrioridadActivarAsync(id, activo, usuarioId, ct);

    public Task<RespuestaSp<EstadoModelo>> EstadoListarAsync(bool soloActivos = false, CancellationToken ct = default) => _repo.EstadoListarAsync(soloActivos, ct);
    public Task<RespuestaSp<EstadoModelo>> EstadoObtenerAsync(int id, CancellationToken ct = default) => _repo.EstadoObtenerAsync(id, ct);
    public Task<RespuestaSp> EstadoGuardarAsync(int? id, string codigo, string nombre, int orden, string? color, bool final, int usuarioId, CancellationToken ct = default) =>
        _repo.EstadoGuardarAsync(id, codigo, nombre, orden, color, final, usuarioId, ct);
    public Task<RespuestaSp> EstadoActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) => _repo.EstadoActivarAsync(id, activo, usuarioId, ct);

    public Task<RespuestaSp<MotivoEsperaModelo>> MotivoListarAsync(bool soloActivos = false, CancellationToken ct = default) => _repo.MotivoListarAsync(soloActivos, ct);
    public Task<RespuestaSp<MotivoEsperaModelo>> MotivoObtenerAsync(int id, CancellationToken ct = default) => _repo.MotivoObtenerAsync(id, ct);
    public Task<RespuestaSp> MotivoGuardarAsync(int? id, string codigo, string nombre, int orden, int usuarioId, CancellationToken ct = default) => _repo.MotivoGuardarAsync(id, codigo, nombre, orden, usuarioId, ct);
    public Task<RespuestaSp> MotivoActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) => _repo.MotivoActivarAsync(id, activo, usuarioId, ct);

    public Task<RespuestaSp<ProveedorModelo>> ProveedorListarAsync(bool soloActivos = false, CancellationToken ct = default) => _repo.ProveedorListarAsync(soloActivos, ct);
    public Task<RespuestaSp<ProveedorModelo>> ProveedorObtenerAsync(int id, CancellationToken ct = default) => _repo.ProveedorObtenerAsync(id, ct);
    public Task<RespuestaSp> ProveedorGuardarAsync(int? id, string codigo, string nombre, string? rtn, string? contacto, string? telefono, string? correo, string? especialidad, int usuarioId, CancellationToken ct = default) =>
        _repo.ProveedorGuardarAsync(id, codigo, nombre, rtn, contacto, telefono, correo, especialidad, usuarioId, ct);
    public Task<RespuestaSp> ProveedorActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) => _repo.ProveedorActivarAsync(id, activo, usuarioId, ct);

    public Task<RespuestaSp<TecnicoModelo>> TecnicoListarAsync(bool soloActivos = false, int? categoriaId = null, CancellationToken ct = default) => _repo.TecnicoListarAsync(soloActivos, categoriaId, ct);
    public Task<RespuestaSp<TecnicoModelo>> TecnicoObtenerAsync(int id, CancellationToken ct = default) => _repo.TecnicoObtenerAsync(id, ct);
    public Task<RespuestaSp> TecnicoGuardarAsync(int? id, string codigo, string nombre, int? usuarioRef, string? telefono, int? categoriaId, int usuarioId, CancellationToken ct = default) =>
        _repo.TecnicoGuardarAsync(id, codigo, nombre, usuarioRef, telefono, categoriaId, usuarioId, ct);
    public Task<RespuestaSp> TecnicoActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) => _repo.TecnicoActivarAsync(id, activo, usuarioId, ct);

    public Task<RespuestaSp<ParametroModelo>> ParametroListarAsync(bool soloActivos = false, CancellationToken ct = default) => _repo.ParametroListarAsync(soloActivos, ct);
    public Task<RespuestaSp<ParametroModelo>> ParametroObtenerAsync(int id, CancellationToken ct = default) => _repo.ParametroObtenerAsync(id, ct);
    public Task<RespuestaSp> ParametroGuardarAsync(int? id, string clave, string valor, string? descripcion, int usuarioId, CancellationToken ct = default) =>
        _repo.ParametroGuardarAsync(id, clave, valor, descripcion, usuarioId, ct);
    public Task<RespuestaSp> ParametroActivarAsync(int id, bool activo, int usuarioId, CancellationToken ct = default) => _repo.ParametroActivarAsync(id, activo, usuarioId, ct);

    public byte[] PlantillaActivosExcel()
    {
        using var wb = new XLWorkbook();
        var ws = wb.Worksheets.Add("Activos");
        var headers = new[] { "Codigo", "Nombre", "Marca", "Modelo", "Serie", "CodigoSucursal", "CodigoUbicacion", "CodigoCategoria", "FechaInstalacion" };
        for (var i = 0; i < headers.Length; i++) ws.Cell(1, i + 1).Value = headers[i];
        ws.Row(1).Style.Font.Bold = true;
        ws.Cell(2, 1).Value = "ACT-EJEMPLO";
        ws.Cell(2, 2).Value = "Equipo ejemplo";
        ws.Cell(2, 6).Value = "SPS_PRUEBA";
        using var ms = new MemoryStream();
        wb.SaveAs(ms);
        return ms.ToArray();
    }

    public async Task<RespuestaSp> CargarActivosExcelAsync(IFormFile archivo, int usuarioId, CancellationToken ct = default)
    {
        if (archivo == null || archivo.Length == 0)
            return new RespuestaSp { FiCodigo = 400, FcMensaje = "Debe seleccionar un archivo Excel", FbSucces = false };

        var sucursales = (await _repo.SucursalListarAsync(true, null, ct)).Datos;
        var ubicaciones = (await _repo.UbicacionListarAsync(true, null, ct)).Datos;
        var categorias = (await _repo.CategoriaListarAsync(true, ct)).Datos;
        var ok = 0; var errores = new List<string>();

        await using var stream = archivo.OpenReadStream();
        using var wb = new XLWorkbook(stream);
        var ws = wb.Worksheets.First();
        var filas = ws.RangeUsed()?.RowsUsed().Skip(1) ?? Enumerable.Empty<IXLRangeRow>();

        foreach (var row in filas)
        {
            var codigo = row.Cell(1).GetString().Trim();
            var nombre = row.Cell(2).GetString().Trim();
            if (string.IsNullOrWhiteSpace(codigo) || string.IsNullOrWhiteSpace(nombre))
            {
                errores.Add($"Fila {row.RowNumber()}: código y nombre son obligatorios");
                continue;
            }
            var marca = NullIfEmpty(row.Cell(3).GetString());
            var modelo = NullIfEmpty(row.Cell(4).GetString());
            var serie = NullIfEmpty(row.Cell(5).GetString());
            var codSuc = row.Cell(6).GetString().Trim();
            var codUbi = row.Cell(7).GetString().Trim();
            var codCat = row.Cell(8).GetString().Trim();
            DateTime? fecha = null;
            if (!row.Cell(9).IsEmpty())
            {
                if (row.Cell(9).TryGetValue<DateTime>(out var fd)) fecha = fd.Date;
                else if (DateTime.TryParse(row.Cell(9).GetString(), out var fp)) fecha = fp.Date;
            }

            var suc = sucursales.FirstOrDefault(s => string.Equals(s.FcCodigo, codSuc, StringComparison.OrdinalIgnoreCase));
            if (suc == null)
            {
                errores.Add($"Fila {row.RowNumber()}: sucursal '{codSuc}' no encontrada");
                continue;
            }
            int? ubiId = null;
            if (!string.IsNullOrWhiteSpace(codUbi))
            {
                var ubi = ubicaciones.FirstOrDefault(u => string.Equals(u.FcCodigo, codUbi, StringComparison.OrdinalIgnoreCase) && u.FiSucursalId == suc.FiId);
                if (ubi == null)
                {
                    errores.Add($"Fila {row.RowNumber()}: ubicación '{codUbi}' no válida para la sucursal");
                    continue;
                }
                ubiId = ubi.FiId;
            }
            int? catId = null;
            if (!string.IsNullOrWhiteSpace(codCat))
            {
                var cat = categorias.FirstOrDefault(c => string.Equals(c.FcCodigo, codCat, StringComparison.OrdinalIgnoreCase));
                if (cat == null)
                {
                    errores.Add($"Fila {row.RowNumber()}: categoría '{codCat}' no encontrada");
                    continue;
                }
                catId = cat.FiId;
            }

            var resp = await _repo.ActivoGuardarAsync(0, codigo, nombre, marca, modelo, serie, suc.FiId, ubiId, catId, fecha, usuarioId, ct);
            if (resp.FbSucces) ok++;
            else errores.Add($"Fila {row.RowNumber()}: {resp.FcMensaje}");
        }

        return new RespuestaSp
        {
            FiCodigo = ok > 0 ? 200 : 400,
            FcMensaje = ok > 0
                ? $"Se importaron {ok} activo(s)" + (errores.Count > 0 ? $"; {errores.Count} con error" : "")
                : (errores.FirstOrDefault() ?? "No se importó ningún activo"),
            FbSucces = ok > 0,
            FjData = $"{{\"ok\":{ok},\"errores\":{errores.Count}}}"
        };
    }

    private static string? NullIfEmpty(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}

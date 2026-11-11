namespace FM.OrigenDatos.Modelos.Catalogos;

// Callers: CatalogoRepositorio, CatalogoServicio, CatalogosController/Views
// API: DTOs listar/obtener de sp_catalogo_* (13-18)
// Schema: region, sucursal, ubicacion, activo, tipomantenimiento, categoria, prioridad, estado, motivoespera, proveedor, tecnico, parametro
// User instruction: "FM.OrigenDatos/Repositorios/CatalogoRepositorio.cs + Modelos/Catalogos"

public class RegionModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

public class SucursalModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public string FcTipo { get; set; } = "SUCURSAL";
    public int FiRegionId { get; set; }
    public string? FcRegionNombre { get; set; }
    public string? FcDireccion { get; set; }
    public string? FcTelefono { get; set; }
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

public class UbicacionModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public int FiSucursalId { get; set; }
    public string? FcSucursalNombre { get; set; }
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

public class ActivoModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public string? FcMarca { get; set; }
    public string? FcModelo { get; set; }
    public string? FcSerie { get; set; }
    public int FiSucursalId { get; set; }
    public string? FcSucursalNombre { get; set; }
    public int? FiUbicacionId { get; set; }
    public string? FcUbicacionNombre { get; set; }
    public int? FiCategoriaId { get; set; }
    public string? FcCategoriaNombre { get; set; }
    public DateTime? FdFechaInstalacion { get; set; }
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

public class TipoMantenimientoModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public bool FbRequiereAprobacion { get; set; }
    public bool FbEsPreventivo { get; set; }
    public bool FbEsPostFalla { get; set; }
    public bool FbRequiereFechaSugerida { get; set; }
    public int FiOrden { get; set; }
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

public class CategoriaModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public int FiOrden { get; set; }
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

public class PrioridadModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public int FiHorasRespuesta { get; set; }
    public int FiHorasSolucion { get; set; }
    public string? FcColor { get; set; }
    public int FiOrden { get; set; }
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

public class EstadoModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public int FiOrden { get; set; }
    public string? FcColor { get; set; }
    public bool FbFinal { get; set; }
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

public class MotivoEsperaModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public int FiOrden { get; set; }
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

public class ProveedorModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public string? FcRtn { get; set; }
    public string? FcContacto { get; set; }
    public string? FcTelefono { get; set; }
    public string? FcCorreo { get; set; }
    public string? FcEspecialidad { get; set; }
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

public class TecnicoModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public int? FiUsuarioId { get; set; }
    // Callers: Catalogos Entidad/form técnicos; User instruction: "Usuario del sistema" + lista
    public string? FcUsuarioNombre { get; set; }
    public string? FcTelefono { get; set; }
    public int? FiCategoriaId { get; set; }
    public string? FcCategoriaNombre { get; set; }
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

public class ParametroModelo
{
    public int FiId { get; set; }
    public string FcClave { get; set; } = "";
    public string FcValor { get; set; } = "";
    public string? FcDescripcion { get; set; }
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

// Callers: CatalogoRepositorio.Area*/Departamento*; CatalogosController/Views
// API: DTOs sp_catalogo_area_* / sp_catalogo_departamento_*
// User instruction: "Catálogos: agrega Áreas y Departamentos al módulo Catálogos"
public class AreaModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

public class DepartamentoModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public int FiAreaId { get; set; }
    public string? FcAreaNombre { get; set; }
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
}

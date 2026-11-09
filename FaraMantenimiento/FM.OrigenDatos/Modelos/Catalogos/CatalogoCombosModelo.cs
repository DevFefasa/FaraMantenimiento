namespace FM.OrigenDatos.Modelos.Catalogos;

public class CatalogoItemModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public int? FiRegionId { get; set; }
    public int? FiSucursalId { get; set; }
    public int? FiUbicacionId { get; set; }
    public int? FiCategoriaId { get; set; }
    public string? FcTipo { get; set; }
    public bool FbRequiereAprobacion { get; set; }
    public bool FbEsPreventivo { get; set; }
    public bool FbEsPostFalla { get; set; }
    public bool FbRequiereFechaSugerida { get; set; }
    public int? FiOrden { get; set; }
    public int? FiHorasRespuesta { get; set; }
    public int? FiHorasSolucion { get; set; }
    public string? FcColor { get; set; }
    public bool FbFinal { get; set; }
    public string? FcEspecialidad { get; set; }
    public string? FcTelefono { get; set; }
}

public class CatalogoCombosModelo
{
    public List<CatalogoItemModelo> Regiones { get; set; } = new();
    public List<CatalogoItemModelo> Sucursales { get; set; } = new();
    public List<CatalogoItemModelo> Ubicaciones { get; set; } = new();
    public List<CatalogoItemModelo> Activos { get; set; } = new();
    public List<CatalogoItemModelo> Tipos { get; set; } = new();
    public List<CatalogoItemModelo> Categorias { get; set; } = new();
    public List<CatalogoItemModelo> Prioridades { get; set; } = new();
    public List<CatalogoItemModelo> Estados { get; set; } = new();
    public List<CatalogoItemModelo> MotivosEspera { get; set; } = new();
    public List<CatalogoItemModelo> Proveedores { get; set; } = new();
    public List<CatalogoItemModelo> Tecnicos { get; set; } = new();
}

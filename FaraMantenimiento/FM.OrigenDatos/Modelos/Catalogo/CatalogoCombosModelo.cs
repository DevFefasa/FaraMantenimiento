namespace FM.OrigenDatos.Modelos.Catalogo;

public class CatalogoItemModelo
{
    public int FiId { get; set; }
    public string? FcCodigo { get; set; }
    public string FcNombre { get; set; } = "";
    public int? FiRegionId { get; set; }
    public int? FiSucursalId { get; set; }
    public int? FiAreaId { get; set; }
    public string? FcTipo { get; set; }
    public bool FbEsPreventivo { get; set; }
    public int FiOrden { get; set; }
}

public class CatalogoCombosModelo
{
    public List<CatalogoItemModelo> Regiones { get; set; } = new();
    public List<CatalogoItemModelo> Sucursales { get; set; } = new();
    public List<CatalogoItemModelo> Tipos { get; set; } = new();
    public List<CatalogoItemModelo> Categorias { get; set; } = new();
    public List<CatalogoItemModelo> Prioridades { get; set; } = new();
    public List<CatalogoItemModelo> Estados { get; set; } = new();
    public List<CatalogoItemModelo> Tecnicos { get; set; } = new();
    public List<CatalogoItemModelo> Proveedores { get; set; } = new();
    public List<CatalogoItemModelo> Activos { get; set; } = new();
    public List<CatalogoItemModelo> Areas { get; set; } = new();
    public List<CatalogoItemModelo> Departamentos { get; set; } = new();
}


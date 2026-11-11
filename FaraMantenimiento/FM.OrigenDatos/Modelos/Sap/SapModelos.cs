namespace FM.OrigenDatos.Modelos.Sap;

// Callers: SapHanaRepositorio; SapServicio; TicketsController BuscarArticulosSap/BuscarProveedoresSap
// API: DTOs lectura OITM (ItemCode/ItemName/unidad/existencia/AvgPrice) y OCRD CardType=S
// Confirm: Glob **/Modelos/Sap/** vacío
// Fields: FcCodigo, FcNombre, FcUnidad, FnExistencia, FnCostoPromedio; FbConfigurado/FcMensaje
// User instruction: "materiales y proveedores desde SAP Business One (HANA), SOLO LECTURA"

public class SapArticuloModelo
{
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public string? FcUnidad { get; set; }
    public decimal FnExistencia { get; set; }
    public decimal FnCostoPromedio { get; set; }
}

public class SapProveedorModelo
{
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
}

public class SapBusquedaResultado<T>
{
    public bool FbConfigurado { get; set; }
    public string? FcMensaje { get; set; }
    public IReadOnlyList<T> Datos { get; set; } = Array.Empty<T>();
}

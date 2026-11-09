namespace FM.OrigenDatos.Modelos.Reportes;

public class ActivoHojaVidaModelo
{
    public int FiActivoId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public string? FcMarca { get; set; }
    public string? FcModelo { get; set; }
    public string? FcSerie { get; set; }
    public DateTime? FdFechaInstalacion { get; set; }
    public string FcSucursalNombre { get; set; } = "";
    public string? FcSucursalCodigo { get; set; }
    public string? FcUbicacionNombre { get; set; }
    public string? FcCategoriaNombre { get; set; }
    public string? FcCategoriaCodigo { get; set; }
}

public class ActivoHojaVidaTicketModelo
{
    public int FiTicketId { get; set; }
    public string FcNumero { get; set; } = "";
    public DateTime FdFechaIngreso { get; set; }
    public string FcTipoNombre { get; set; } = "";
    public bool FbEsPreventivo { get; set; }
    public string FcCategoriaNombre { get; set; } = "";
    public string FcEstadoNombre { get; set; } = "";
    public string? FcEstadoCodigo { get; set; }
    public string? FcDiagnostico { get; set; }
    public string? FcCausaRaiz { get; set; }
    public decimal FnCostoTotal { get; set; }
}

public class ActivoHojaVidaTotalesModelo
{
    public int FiTickets { get; set; }
    public int FiCorrectivos { get; set; }
    public int FiPreventivos { get; set; }
    public int FiReincidencias { get; set; }
    public decimal FnCostoManoObra { get; set; }
    public decimal FnCostoMateriales { get; set; }
    public decimal FnCostoProveedor { get; set; }
    public decimal FnCostoTotal { get; set; }
    public decimal? FnMtbfDias { get; set; }
    public DateTime? FdUltimaIntervencion { get; set; }
}

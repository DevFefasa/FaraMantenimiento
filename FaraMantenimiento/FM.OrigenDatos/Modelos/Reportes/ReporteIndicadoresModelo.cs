namespace FM.OrigenDatos.Modelos.Reportes;

public class ReporteResumenModelo
{
    public int FiRecibidos { get; set; }
    public int FiAbiertos { get; set; }
    public int FiCerrados { get; set; }
    public int FiBacklog { get; set; }
    public int FiReincidentes { get; set; }
    public decimal? FnHorasRespuestaPromedio { get; set; }
    public decimal? FnHorasSolucionPromedio { get; set; }
    public decimal? FnPctSlaSolucion { get; set; }
    public decimal? FnSatisfaccionPromedio { get; set; }
}

public class ReporteTiempoModelo
{
    public string FcPrioridadCodigo { get; set; } = "";
    public string FcPrioridadNombre { get; set; } = "";
    public int FiTickets { get; set; }
    public decimal? FnHorasRespuestaPromedio { get; set; }
    public decimal? FnHorasSolucionPromedio { get; set; }
    public decimal? FnMttrHoras { get; set; }
}

public class ReporteSlaModelo
{
    public string FcPrioridadCodigo { get; set; } = "";
    public string FcPrioridadNombre { get; set; } = "";
    public int FiTickets { get; set; }
    public int FiSlaRespuestaOk { get; set; }
    public int FiSlaRespuestaNo { get; set; }
    public decimal? FnPctSlaRespuesta { get; set; }
    public int FiSlaSolucionOk { get; set; }
    public int FiSlaSolucionNo { get; set; }
    public decimal? FnPctSlaSolucion { get; set; }
}

public class ReporteTipoModelo
{
    public string FcTipoCodigo { get; set; } = "";
    public string FcTipoNombre { get; set; } = "";
    public bool FbEsPreventivo { get; set; }
    public int FiTickets { get; set; }
    public decimal? FnPorcentaje { get; set; }
}

public class ReporteMtbfModelo
{
    public int? FiActivoId { get; set; }
    public string FcAgrupacion { get; set; } = "";
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public string? FcSucursalNombre { get; set; }
    public int FiFallos { get; set; }
    public decimal? FnMtbfHoras { get; set; }
}

public class ReporteReincidenciaResumenModelo
{
    public int FiTickets { get; set; }
    public int FiReincidentes { get; set; }
    public decimal? FnTasaReincidencia { get; set; }
}

public class ReporteReincidenciaDetalleModelo
{
    public string FcActivoCodigo { get; set; } = "";
    public string FcActivoNombre { get; set; } = "";
    public string FcCategoriaNombre { get; set; } = "";
    public string FcSucursalNombre { get; set; } = "";
    public int FiTickets { get; set; }
    public int FiReincidentes { get; set; }
}

public class ReporteCostoModelo
{
    public int? FiActivoId { get; set; }
    public string FcAgrupacion { get; set; } = "";
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public int FiTickets { get; set; }
    public decimal FnCostoManoObra { get; set; }
    public decimal FnCostoMateriales { get; set; }
    public decimal FnCostoProveedor { get; set; }
    public decimal FnCostoTotal { get; set; }
}

public class ReporteProductividadModelo
{
    public string FcTipoResponsable { get; set; } = "";
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public int FiTickets { get; set; }
    public decimal FnHorasTrabajadas { get; set; }
    public decimal? FnHorasSolucionPromedio { get; set; }
}

public class ReporteSatisfaccionResumenModelo
{
    public int FiEncuestas { get; set; }
    public decimal? FnCalificacionPromedio { get; set; }
    public int FiConformes { get; set; }
    public decimal? FnPctConformes { get; set; }
}

public class ReporteSatisfaccionDetalleModelo
{
    public int FiCalificacion { get; set; }
    public int FiCantidad { get; set; }
    public decimal? FnPorcentaje { get; set; }
}

public class ReporteTendenciaModelo
{
    public string FcPeriodo { get; set; } = "";
    public string FcPeriodoEtiqueta { get; set; } = "";
    public int FiRecibidos { get; set; }
    public int FiCerrados { get; set; }
    public int FiAbiertos { get; set; }
    public decimal? FnMttrHoras { get; set; }
}


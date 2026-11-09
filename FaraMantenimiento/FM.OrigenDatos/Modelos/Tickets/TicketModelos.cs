using FM.OrigenDatos.Conexion;

namespace FM.OrigenDatos.Modelos.Tickets;

public class TicketListaModelo
{
    public int FiId { get; set; }
    public string FcNumero { get; set; } = "";
    public DateTime FdFechaIngreso { get; set; }
    public int? FiSolicitanteId { get; set; }
    public string FcSolicitanteNombre { get; set; } = "";
    public int FiSucursalId { get; set; }
    public string? FcSucursalNombre { get; set; }
    public int FiTipoMantenimientoId { get; set; }
    public string? FcTipoNombre { get; set; }
    public int FiCategoriaId { get; set; }
    public string? FcCategoriaNombre { get; set; }
    public int FiPrioridadId { get; set; }
    public string? FcPrioridadNombre { get; set; }
    public string? FcPrioridadCodigo { get; set; }
    public string? FcPrioridadColor { get; set; }
    public int FiEstadoId { get; set; }
    public string? FcEstadoCodigo { get; set; }
    public string? FcEstadoNombre { get; set; }
    public string? FcEstadoColor { get; set; }
    public bool FbFinal { get; set; }
    public string? FcTipoResponsable { get; set; }
    public int? FiTecnicoId { get; set; }
    public string? FcTecnicoNombre { get; set; }
    public int? FiProveedorId { get; set; }
    public string? FcProveedorNombre { get; set; }
    public bool FbReincidencia { get; set; }
    public DateTime? FdLimiteRespuesta { get; set; }
    public DateTime? FdLimiteSolucion { get; set; }
    public bool? FbSlaRespuestaCumplido { get; set; }
    public bool? FbSlaSolucionCumplido { get; set; }
    public string? FcDescripcionCorta { get; set; }
    public string FcSemaforoSla { get; set; } = "VERDE";
}

public class TicketDetalleModelo : TicketListaModelo
{
    public string? FcCargo { get; set; }
    public string? FcCorreo { get; set; }
    public string? FcTelefono { get; set; }
    public string? FcSucursalCodigo { get; set; }
    public int? FiUbicacionId { get; set; }
    public string? FcUbicacionNombre { get; set; }
    public string? FcUbicacionDetalle { get; set; }
    public int? FiActivoId { get; set; }
    public string? FcActivoNombre { get; set; }
    public string? FcActivoCodigo { get; set; }
    public string? FcTipoCodigo { get; set; }
    public bool FbRequiereAprobacion { get; set; }
    public bool FbEsPreventivo { get; set; }
    public bool FbEsPostFalla { get; set; }
    public bool FbRequiereFechaSugerida { get; set; }
    public string? FcCategoriaCodigo { get; set; }
    public int FiHorasRespuesta { get; set; }
    public int FiHorasSolucion { get; set; }
    public string FcDescripcion { get; set; } = "";
    public DateTime? FdFechaSugerida { get; set; }
    public int? FiMotivoEsperaId { get; set; }
    public string? FcMotivoEsperaNombre { get; set; }
    public DateTime? FdFechaProgramada { get; set; }
    public DateTime? FdFechaInicio { get; set; }
    public DateTime? FdFechaFin { get; set; }
    public decimal? FnHorasTrabajadas { get; set; }
    public decimal? FnCostoManoObra { get; set; }
    public decimal? FnCostoMateriales { get; set; }
    public decimal? FnCostoProveedor { get; set; }
    public string? FcDiagnostico { get; set; }
    public string? FcCausaRaiz { get; set; }
    public string? FcTrabajoRealizado { get; set; }
    public string? FcAccionesPreventivas { get; set; }
    public int? FiTicketReincidenteId { get; set; }
    public string? FcTicketReincidenteNumero { get; set; }
    public DateTime? FdPrimeraRespuesta { get; set; }
    public DateTime? FdResuelto { get; set; }
    public DateTime? FdValidado { get; set; }
    public DateTime? FdCerrado { get; set; }
    public DateTime? FdInicioEspera { get; set; }
    public int FiMinutosEnEspera { get; set; }
    public bool FbCierreAutomatico { get; set; }
}

public class TicketEstadoHistorialModelo
{
    public int FiId { get; set; }
    public int FiTicketId { get; set; }
    public int? FiEstadoAnteriorId { get; set; }
    public string? FcEstadoAnteriorCodigo { get; set; }
    public string? FcEstadoAnteriorNombre { get; set; }
    public int FiEstadoId { get; set; }
    public string? FcEstadoCodigo { get; set; }
    public string? FcEstadoNombre { get; set; }
    public string? FcEstadoColor { get; set; }
    public int? FiMotivoEsperaId { get; set; }
    public string? FcMotivoEsperaNombre { get; set; }
    public string? FcComentario { get; set; }
    public int? FiUsuarioId { get; set; }
    public string? FcUsuarioNombre { get; set; }
    public DateTime FdFecha { get; set; }
}

public class TicketMaterialModelo
{
    public int FiId { get; set; }
    public int FiTicketId { get; set; }
    public string FcDescripcion { get; set; } = "";
    public decimal FnCantidad { get; set; }
    public string? FcUnidad { get; set; }
    public decimal FnCostoUnitario { get; set; }
    public decimal FnTotal { get; set; }
    public DateTime FdCreado { get; set; }
    public int? FiCreadoPor { get; set; }
}

public class TicketEncuestaModelo
{
    public int FiId { get; set; }
    public int FiTicketId { get; set; }
    public byte FiCalificacion { get; set; }
    public bool FbConforme { get; set; }
    public string? FcComentario { get; set; }
    public DateTime FdFecha { get; set; }
    public int? FiUsuarioId { get; set; }
}

public class TicketComentarioModelo
{
    public int FiId { get; set; }
    public int FiTicketId { get; set; }
    public string FcComentario { get; set; } = "";
    public bool FbInterno { get; set; }
    public int? FiUsuarioId { get; set; }
    public string? FcUsuarioNombre { get; set; }
    public DateTime FdFecha { get; set; }
}

public class TicketObtenerResultado
{
    public RespuestaSp Cabecera { get; set; } = new();
    public TicketDetalleModelo? Ticket { get; set; }
    public List<TicketEstadoHistorialModelo> Historial { get; set; } = new();
    public List<TicketMaterialModelo> Materiales { get; set; } = new();
    public TicketEncuestaModelo? Encuesta { get; set; }
    public List<TicketComentarioModelo> Comentarios { get; set; } = new();
}

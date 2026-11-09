namespace FM.OrigenDatos.Modelos.Preventivos;

// Callers: PreventivoRepositorio, PreventivoServicio, PreventivosController / Views
// API: DTOs de planpreventivo, ejecucion, calendario, cumplimiento
// Schema: columnas fi*/fc*/fd*/fb*/fn* de SP 55-59
// User instruction: "FM.OrigenDatos (Modelos/Preventivos + Repositorios/PreventivoRepositorio)"

public class PlanPreventivoModelo
{
    public int FiId { get; set; }
    public string FcNombre { get; set; } = "";
    public int? FiActivoId { get; set; }
    public string? FcActivoNombre { get; set; }
    public string? FcActivoCodigo { get; set; }
    public int FiSucursalId { get; set; }
    public string? FcSucursalNombre { get; set; }
    public int? FiUbicacionId { get; set; }
    public string? FcUbicacionNombre { get; set; }
    public int FiCategoriaId { get; set; }
    public string? FcCategoriaNombre { get; set; }
    public int FiPrioridadId { get; set; }
    public string? FcPrioridadNombre { get; set; }
    public string? FcPrioridadColor { get; set; }
    public string? FcDescripcion { get; set; }
    public int FiFrecuenciaDias { get; set; }
    public DateTime FdProximaFecha { get; set; }
    public int FiDiasAnticipacion { get; set; }
    public int? FiTecnicoId { get; set; }
    public string? FcTecnicoNombre { get; set; }
    public int? FiProveedorId { get; set; }
    public string? FcProveedorNombre { get; set; }
    public bool FbActivo { get; set; }
    public DateTime FdCreado { get; set; }
    public int? FiCreadoPor { get; set; }
    public DateTime? FdModificado { get; set; }
    public int? FiModificadoPor { get; set; }
}

public class PlanPreventivoEjecucionModelo
{
    public int FiId { get; set; }
    public int FiPlanId { get; set; }
    public DateTime FdFechaProgramada { get; set; }
    public int? FiTicketId { get; set; }
    public DateTime FdGenerado { get; set; }
    public string? FcTicketNumero { get; set; }
    public string? FcEstadoCodigo { get; set; }
    public string? FcEstadoNombre { get; set; }
}

public class PreventivoCalendarioItemModelo
{
    public int FiPlanId { get; set; }
    public string FcNombre { get; set; } = "";
    public int FiSucursalId { get; set; }
    public string? FcSucursalNombre { get; set; }
    public int? FiActivoId { get; set; }
    public string? FcActivoNombre { get; set; }
    public DateTime FdFecha { get; set; }
    public int? FiTicketId { get; set; }
    public string? FcTicketNumero { get; set; }
    public string? FcEstadoCodigo { get; set; }
    public string? FcEstadoNombre { get; set; }
    public bool FbProyectado { get; set; }
}

public class CumplimientoPreventivoResumenModelo
{
    public int FiProgramados { get; set; }
    public int FiEjecutados { get; set; }
    public decimal FnPorcentajeCumplimiento { get; set; }
}

public class CumplimientoPreventivoDetalleModelo
{
    public int FiPlanId { get; set; }
    public string FcNombre { get; set; } = "";
    public int FiSucursalId { get; set; }
    public string? FcSucursalNombre { get; set; }
    public int FiProgramados { get; set; }
    public int FiEjecutados { get; set; }
    public decimal FnPorcentajeCumplimiento { get; set; }
}

public class PreventivoObtenerResultado
{
    public FM.OrigenDatos.Conexion.RespuestaSp Cabecera { get; set; } = new();
    public PlanPreventivoModelo? Plan { get; set; }
    public List<PlanPreventivoEjecucionModelo> Ejecuciones { get; set; } = new();
}

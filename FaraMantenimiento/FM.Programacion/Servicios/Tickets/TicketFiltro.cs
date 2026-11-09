namespace FM.Programacion.Servicios.Tickets;

public class TicketFiltro
{
    public int? FiSolicitanteId { get; set; }
    public int? FiEstadoId { get; set; }
    public string? FcEstadoCodigo { get; set; }
    public int? FiSucursalId { get; set; }
    public int? FiPrioridadId { get; set; }
    public int? FiTipoMantenimientoId { get; set; }
    public int? FiCategoriaId { get; set; }
    public string? FcTipoResponsable { get; set; }
    public int? FiTecnicoId { get; set; }
    public int? FiProveedorId { get; set; }
    public DateTime? FdDesde { get; set; }
    public DateTime? FdHasta { get; set; }
    public string? FcTexto { get; set; }
    public bool FbSoloAbiertos { get; set; }
    public int FiPagina { get; set; } = 1;
    public int FiTamano { get; set; } = 20;
}

public class TicketAccionesDisponibles
{
    public bool PuedeEvaluar { get; set; }
    public bool PuedeAprobar { get; set; }
    public bool PuedeRechazar { get; set; }
    public bool PuedeAsignar { get; set; }
    public bool PuedeCambiarPrioridad { get; set; }
    public bool PuedeIniciar { get; set; }
    public bool PuedePonerEspera { get; set; }
    public bool PuedeSalirEspera { get; set; }
    public bool PuedeResolver { get; set; }
    public bool PuedeEjecucion { get; set; }
    public bool PuedeMateriales { get; set; }
    public bool PuedeComentar { get; set; }
    public bool PuedeEncuesta { get; set; }
    public bool PuedeCerrar { get; set; }
    public bool PuedeAdjuntos { get; set; }
}

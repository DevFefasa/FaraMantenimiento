namespace FM.OrigenDatos.Modelos.Sla;

// Callers: TicketRepositorio SLA methods / SlaServicio / bandeja contador
// API: SlaAlertaModelo, SlaAlertaConteoModelo
// Schema: slaalerta + fiTotal
// User instruction: "sp_sla_alertas_listar para mostrar avisos" + "agrega SOLO un metodo en SlaServicio" para contador

public class SlaAlertaModelo
{
    public int FiId { get; set; }
    public int FiTicketId { get; set; }
    public string FcTipo { get; set; } = "";
    public DateTime FdFecha { get; set; }
    public bool FbNotificado { get; set; }
    public string? FcDetalle { get; set; }
    public string? FcTicketNumero { get; set; }
    public string? FcEstadoCodigo { get; set; }
    public string? FcEstadoNombre { get; set; }
    public DateTime? FdLimiteRespuesta { get; set; }
    public DateTime? FdLimiteSolucion { get; set; }
    public string? FcSucursalNombre { get; set; }
}

public class SlaAlertaConteoModelo
{
    public int FiTotal { get; set; }
}

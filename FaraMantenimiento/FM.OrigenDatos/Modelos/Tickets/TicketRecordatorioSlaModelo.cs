namespace FM.OrigenDatos.Modelos.Tickets;

/// <summary>Estado del recordatorio diario de SLA vencido (sp_ticket_recordatorio_sla_obtener).</summary>
public class TicketRecordatorioSlaModelo
{
    public int FiTicketId { get; set; }
    public bool FbSinRecordatorioSla { get; set; }
    public DateTime? FdSinRecordatorioSla { get; set; }
    public string? FcSinRecordatorioSlaPor { get; set; }
    /// <summary>Algún límite de SLA (respuesta o solución) ya se superó.</summary>
    public bool FbVencido { get; set; }
    /// <summary>El ticket no está resuelto ni cerrado (la opción aplica).</summary>
    public bool FbAplica { get; set; }
}

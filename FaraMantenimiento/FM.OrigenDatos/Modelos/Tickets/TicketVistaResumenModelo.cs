namespace FM.OrigenDatos.Modelos.Tickets;

/// <summary>Pestaña de la pantalla Tickets (sp_ticket_vistas_resumen): disponible para el usuario y abiertos.</summary>
public class TicketVistaResumenModelo
{
    public string FcVista { get; set; } = "";
    public bool FbDisponible { get; set; }
    public int FiAbiertos { get; set; }
}

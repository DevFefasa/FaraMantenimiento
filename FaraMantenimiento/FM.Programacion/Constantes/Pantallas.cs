namespace FM.Programacion.Constantes;

public static class Pantallas
{
    public const string Dashboard = "DASHBOARD";
    public const string TicketCrear = "TICKET_CREAR";
    public const string TicketMios = "TICKET_MIOS";
    public const string TicketBandeja = "TICKET_BANDEJA";
    public const string TicketAprobacion = "TICKET_APROBACION";
    public const string TicketTodos = "TICKET_TODOS";
    public const string Catalogos = "CATALOGOS";
    public const string Reportes = "REPORTES";
    public const string Seguridad = "SEGURIDAD";
    public const string Preventivos = "PREVENTIVOS";

    public const string ClaimType = "permiso";

    /// <summary>Códigos referenciados en código; no se borran ni se les cambia el código.</summary>
    public static readonly IReadOnlyList<string> CodigosProtegidos = new[]
    {
        Dashboard, TicketCrear, TicketMios, TicketBandeja, TicketAprobacion, TicketTodos,
        Catalogos, Reportes, Seguridad, Preventivos
    };

    public static bool EsProtegida(string? fcCodigo) =>
        !string.IsNullOrWhiteSpace(fcCodigo) &&
        CodigosProtegidos.Contains(fcCodigo.Trim(), StringComparer.OrdinalIgnoreCase);
}

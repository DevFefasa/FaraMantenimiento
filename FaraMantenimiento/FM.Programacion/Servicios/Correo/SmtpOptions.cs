namespace FM.Programacion.Servicios.Correo;

/// <summary>
/// Sección "Smtp" de configuración. Usuario y Password van en User Secrets (desarrollo)
/// o variables Smtp__Usuario / Smtp__Password (servidor); nunca en appsettings.
/// </summary>
public sealed class SmtpOptions
{
    public const string Seccion = "Smtp";

    /// <summary>Si es false, el worker no envía correos (se siguen encolando).</summary>
    public bool Habilitado { get; set; } = true;
    public string Host { get; set; } = "";
    public int Puerto { get; set; } = 587;
    public bool UsarSsl { get; set; } = true;
    public string Usuario { get; set; } = "";
    public string Password { get; set; } = "";
    public string Remitente { get; set; } = "";
    public string NombreRemitente { get; set; } = "Fara Mantenimiento FEFASA";

    /// <summary>
    /// Buzón de pruebas: si tiene valor, TODO correo va solo ahí (el destinatario real se indica en asunto y cuerpo).
    /// En Development es obligatorio: sin él no se envía nada.
    /// </summary>
    public string CorreoPruebas { get; set; } = "";

    /// <summary>URL pública de la app para el botón "Ver ticket" (p. ej. https://mantenimiento.fefasa.hn).</summary>
    public string UrlBase { get; set; } = "";

    /// <summary>Intervalo del worker (mínimo 15 s).</summary>
    public int SegundosIntervalo { get; set; } = 60;
    /// <summary>Intentos antes de dejar el correo en error definitivo.</summary>
    public int FiMaxIntentos { get; set; } = 5;
    /// <summary>Correos por corrida.</summary>
    public int FiLimiteLote { get; set; } = 50;
}

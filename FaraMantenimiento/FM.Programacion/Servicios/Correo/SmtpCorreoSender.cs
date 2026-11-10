using System.Net;
using System.Net.Mail;
using System.Net.Mime;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace FM.Programacion.Servicios.Correo;

public interface ISmtpCorreoSender
{
    Task EnviarAsync(string destinatario, string asunto, string cuerpoHtml, string? cuerpoTexto = null, CancellationToken ct = default);
}

/// <summary>
/// Envío SMTP (System.Net.Mail) con alternativa texto + HTML y logo incrustado (cid).
/// Con Smtp:CorreoPruebas todo correo se desvía a ese buzón; en Development es obligatorio.
/// La contraseña nunca se registra.
/// </summary>
public sealed class SmtpCorreoSender : ISmtpCorreoSender
{
    private readonly IOptions<SmtpOptions> _opciones;
    private readonly IWebHostEnvironment _entorno;
    private readonly ILogger<SmtpCorreoSender> _log;

    public SmtpCorreoSender(IOptions<SmtpOptions> opciones, IWebHostEnvironment entorno, ILogger<SmtpCorreoSender> log)
    {
        _opciones = opciones;
        _entorno = entorno;
        _log = log;
    }

    public async Task EnviarAsync(string destinatario, string asunto, string cuerpoHtml, string? cuerpoTexto = null, CancellationToken ct = default)
    {
        var cfg = _opciones.Value;
        ValidarConfiguracion(cfg);

        var destinatarios = CorreoLista.ExtraerValidos(destinatario);
        if (destinatarios.Count == 0)
            throw new InvalidOperationException("No hay correos válidos en el destinatario.");

        var pruebas = (cfg.CorreoPruebas ?? "").Trim();
        if (_entorno.IsDevelopment() && string.IsNullOrWhiteSpace(pruebas))
            throw new InvalidOperationException("En Development falta Smtp:CorreoPruebas; no se envía a destinatarios reales.");

        if (!string.IsNullOrWhiteSpace(pruebas))
        {
            // Modo pruebas: el destinatario real solo se informa.
            var original = string.Join(", ", destinatarios);
            _log.LogInformation("Correo de prueba: {Original} desviado al buzón de pruebas.", original);
            asunto = $"[PRUEBA → {original}] {asunto}";
            var aviso = "<div style=\"background:#C41E1E;color:#FFFFFF;padding:8px 12px;font-family:Arial,sans-serif;font-size:13px;\">"
                        + WebUtility.HtmlEncode($"Correo de prueba. Destinatario real: {original}") + "</div>";
            var conAviso = Regex.Replace(cuerpoHtml, "<body[^>]*>", m => m.Value + aviso, RegexOptions.IgnoreCase, TimeSpan.FromSeconds(1));
            cuerpoHtml = conAviso == cuerpoHtml ? aviso + cuerpoHtml : conAviso;
            cuerpoTexto = $"[Correo de prueba. Destinatario real: {original}]\n\n{cuerpoTexto}";
            destinatarios = CorreoLista.ExtraerValidos(pruebas);
            if (destinatarios.Count == 0)
                throw new InvalidOperationException("Smtp:CorreoPruebas no es un correo válido.");
        }

        using var mensaje = new MailMessage
        {
            From = new MailAddress(cfg.Remitente.Trim(), string.IsNullOrWhiteSpace(cfg.NombreRemitente) ? cfg.Remitente.Trim() : cfg.NombreRemitente.Trim()),
            Subject = asunto.Trim().Replace('\r', ' ').Replace('\n', ' '),
            BodyEncoding = Encoding.UTF8,
            SubjectEncoding = Encoding.UTF8
        };
        foreach (var c in destinatarios) mensaje.To.Add(new MailAddress(c));

        var texto = string.IsNullOrWhiteSpace(cuerpoTexto)
            ? "Consulte este mensaje en un cliente de correo con soporte HTML."
            : cuerpoTexto;
        var vistaTexto = AlternateView.CreateAlternateViewFromString(texto, Encoding.UTF8, MediaTypeNames.Text.Plain);
        var vistaHtml = AlternateView.CreateAlternateViewFromString(cuerpoHtml, Encoding.UTF8, MediaTypeNames.Text.Html);
        AdjuntarLogo(vistaHtml, cuerpoHtml);
        mensaje.AlternateViews.Add(vistaTexto);
        mensaje.AlternateViews.Add(vistaHtml);

        using var cliente = new SmtpClient(cfg.Host.Trim(), cfg.Puerto)
        {
            EnableSsl = cfg.UsarSsl,
            DeliveryMethod = SmtpDeliveryMethod.Network,
            UseDefaultCredentials = false,
            Credentials = new NetworkCredential(cfg.Usuario.Trim(), cfg.Password),
            Timeout = 60_000
        };
        await cliente.SendMailAsync(mensaje, ct);
    }

    /// <summary>Incrusta el logo (cid:fefasaLogo) para que se vea sin descargar imágenes externas.</summary>
    private void AdjuntarLogo(AlternateView vistaHtml, string cuerpoHtml)
    {
        if (!cuerpoHtml.Contains($"cid:{CorreoHtml.LogoContentId}", StringComparison.OrdinalIgnoreCase)) return;
        var ruta = Path.Combine(_entorno.WebRootPath ?? "", "assets", "images", "FefasaLogo.png");
        if (!File.Exists(ruta))
        {
            _log.LogWarning("No se encontró el logo del correo en {Ruta}.", ruta);
            return;
        }
        var logo = new LinkedResource(ruta, "image/png") { ContentId = CorreoHtml.LogoContentId, TransferEncoding = TransferEncoding.Base64 };
        logo.ContentType.Name = "FefasaLogo.png";
        vistaHtml.LinkedResources.Add(logo);
    }

    private static void ValidarConfiguracion(SmtpOptions cfg)
    {
        if (string.IsNullOrWhiteSpace(cfg.Host)) throw new InvalidOperationException("Falta Smtp:Host.");
        if (cfg.Puerto < 1) throw new InvalidOperationException("Smtp:Puerto no es válido.");
        if (string.IsNullOrWhiteSpace(cfg.Remitente)) throw new InvalidOperationException("Falta Smtp:Remitente.");
        if (string.IsNullOrWhiteSpace(cfg.Usuario) || string.IsNullOrWhiteSpace(cfg.Password))
            throw new InvalidOperationException("Faltan Smtp:Usuario / Smtp:Password (User Secrets o variables de entorno).");
    }
}

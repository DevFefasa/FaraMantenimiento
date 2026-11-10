using System.Net;

namespace FM.Programacion.Servicios.Correo;

/// <summary>
/// Piezas HTML del correo institucional FEFASA (mismo formato que FECPP): tarjeta blanca con franja
/// verde/roja, logo incrustado (cid), etiqueta roja, título con acento verde, cajas de datos y botón verde.
/// Estilos en línea y tablas para que Outlook lo muestre igual.
/// </summary>
public static class CorreoHtml
{
    public const string LogoContentId = "fefasaLogo";

    private const string Verde = "#1B5E35";
    private const string Rojo = "#C41E1E";
    private const string Texto = "#222222";
    private const string Gris = "#6E6E6E";
    private const string Fondo = "#F2F2F2";
    private const string VerdeCaja = "#E8F3EC";
    private const string VerdeBorde = "#D4E6DA";
    private const string Linea = "#E5E5E5";
    private const string Fuente = "'Segoe UI',Tahoma,Arial,Helvetica,sans-serif";

    public static string Codificar(string? texto) => WebUtility.HtmlEncode(texto ?? string.Empty);

    /// <summary>Texto con acento de color para el título.</summary>
    public static string Acento(string texto, bool rojo = false)
        => $"<span style=\"color:{(rojo ? Rojo : Verde)};\">{Codificar(texto)}</span>";

    public static string PlantillaBase(string tituloPagina, string preheader, string etiqueta, string tituloHtml, string contenidoHtml, string firma)
    {
        return $@"<!DOCTYPE html>
<html lang=""es"">
<head>
  <meta http-equiv=""Content-Type"" content=""text/html; charset=utf-8"" />
  <meta name=""viewport"" content=""width=device-width, initial-scale=1"" />
  <meta http-equiv=""X-UA-Compatible"" content=""IE=edge"" />
  <title>{Codificar(tituloPagina)}</title>
</head>
<body style=""margin:0;padding:0;background:{Fondo};font-family:{Fuente};color:{Texto};"">
  <div style=""display:none;max-height:0;overflow:hidden;opacity:0;"">{Codificar(preheader)}</div>
  <table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" border=""0"" style=""width:100%;background:{Fondo};"">
    <tr>
      <td align=""center"" style=""padding:24px 12px;"">
        <table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" border=""0""
               style=""max-width:600px;background:#FFFFFF;border:1px solid {Linea};border-radius:10px;overflow:hidden;"">
          {Franja(5)}
          <tr>
            <td align=""center"" style=""padding:24px 28px 14px 28px;"">
              <img src=""cid:{LogoContentId}"" alt=""FEFASA"" width=""180""
                   style=""display:block;max-width:180px;height:auto;border:0;"" />
              <div style=""margin-top:10px;font-size:11px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:{Verde};"">MANTENIMIENTO</div>
              <div style=""margin-top:2px;font-size:12px;color:{Gris};"">Fara Mantenimiento FEFASA</div>
            </td>
          </tr>
          <tr>
            <td style=""padding:0 28px;""><div style=""height:1px;line-height:1px;font-size:0;background:{Linea};"">&nbsp;</div></td>
          </tr>
          <tr>
            <td style=""padding:20px 28px 6px 28px;"">
              <div style=""font-size:10px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:{Rojo};margin-bottom:8px;"">{Codificar(etiqueta)}</div>
              <div style=""font-size:24px;line-height:1.25;font-weight:700;color:{Texto};"">{tituloHtml}</div>
            </td>
          </tr>
          <tr>
            <td style=""padding:12px 28px 20px 28px;"">
              {contenidoHtml}
            </td>
          </tr>
          <tr>
            <td style=""padding:0 28px 22px 28px;"">
              <div style=""height:1px;line-height:1px;font-size:0;background:{Linea};margin-bottom:14px;"">&nbsp;</div>
              <div style=""font-size:11px;line-height:1.6;color:{Gris};text-align:center;"">
                {Codificar(firma)}<br />
                FEFASA &middot; Ferreter&iacute;a Faraj S.A. de C.V.<br />
                Este es un mensaje autom&aacute;tico; por favor no responda a este correo.
              </div>
            </td>
          </tr>
          {Franja(4)}
        </table>
      </td>
    </tr>
  </table>
</body>
</html>";
    }

    /// <summary>Párrafo (htmlYaCodificado debe venir codificado).</summary>
    public static string Parrafo(string htmlYaCodificado, bool secundario = false)
        => $@"<p style=""margin:0 0 16px 0;font-size:{(secundario ? "12px" : "14px")};line-height:1.6;color:{(secundario ? Gris : Texto)};"">{htmlYaCodificado}</p>";

    /// <summary>Caja verde clara con etiqueta en mayúsculas y valor destacado.</summary>
    public static string CajaDato(string etiqueta, string? valor, bool etiquetaRoja = false)
        => $@"<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" border=""0"" style=""margin:0 0 12px 0;"">
  <tr>
    <td style=""background:{VerdeCaja};border:1px solid {VerdeBorde};border-radius:8px;padding:12px 16px;"">
      <div style=""font-size:10px;font-weight:700;letter-spacing:0.10em;text-transform:uppercase;color:{(etiquetaRoja ? Rojo : Verde)};margin-bottom:6px;"">{Codificar(etiqueta)}</div>
      <div style=""font-size:16px;font-weight:700;color:{Texto};word-break:break-word;"">{Codificar(string.IsNullOrWhiteSpace(valor) ? "—" : valor)}</div>
    </td>
  </tr>
</table>";

    /// <summary>Dos cajas lado a lado.</summary>
    public static string FilaCajas(string izquierda, string derecha)
        => $@"<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" border=""0"">
  <tr>
    <td width=""50%"" valign=""top"" style=""padding:0 6px 0 0;"">{izquierda}</td>
    <td width=""50%"" valign=""top"" style=""padding:0 0 0 6px;"">{derecha}</td>
  </tr>
</table>";

    /// <summary>Recuadro gris con borde lateral (descripción, motivo, comentario).</summary>
    public static string CajaTexto(string etiqueta, string? texto, bool rojo = true)
        => $@"<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" border=""0"" style=""margin:0 0 16px 0;"">
  <tr>
    <td style=""background:{Fondo};border-left:3px solid {(rojo ? Rojo : Verde)};border-radius:8px;padding:12px 16px;"">
      <div style=""font-size:10px;font-weight:700;letter-spacing:0.10em;text-transform:uppercase;color:{(rojo ? Rojo : Verde)};margin-bottom:6px;"">{Codificar(etiqueta)}</div>
      <div style=""font-size:14px;line-height:1.6;color:{Texto};white-space:pre-wrap;"">{Codificar(string.IsNullOrWhiteSpace(texto) ? "Sin detalle adicional." : texto)}</div>
    </td>
  </tr>
</table>";

    /// <summary>Botón verde (píldora). Vacío si no hay URL.</summary>
    public static string Boton(string texto, string? url)
    {
        if (string.IsNullOrWhiteSpace(url)) return string.Empty;
        var href = Codificar(url);
        return $@"<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" border=""0"" style=""margin:4px 0 16px 0;"">
  <tr>
    <td align=""center"">
      <table role=""presentation"" cellspacing=""0"" cellpadding=""0"" border=""0"">
        <tr>
          <td align=""center"" bgcolor=""{Verde}"" style=""background:{Verde};border-radius:22px;"">
            <a href=""{href}"" style=""display:inline-block;padding:12px 28px;font-size:14px;font-weight:700;color:#FFFFFF;text-decoration:none;border-radius:22px;"">
              <span style=""color:#FFFFFF;"">{Codificar(texto)}</span>
            </a>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>";
    }

    /// <summary>Recuadro "Si el botón no funciona" con el enlace en texto.</summary>
    public static string EnlaceAlterno(string? url)
    {
        if (string.IsNullOrWhiteSpace(url)) return string.Empty;
        var href = Codificar(url);
        return $@"<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" border=""0"" style=""margin:0 0 12px 0;"">
  <tr>
    <td style=""background:{Fondo};border:1px solid {Linea};border-radius:8px;padding:12px 16px;"">
      <div style=""font-size:12px;font-weight:700;color:{Verde};margin-bottom:4px;"">Si el bot&oacute;n no funciona</div>
      <div style=""font-size:11px;line-height:1.5;color:{Gris};margin-bottom:6px;"">Copie y pegue este enlace en su navegador:</div>
      <a href=""{href}"" style=""font-size:11px;line-height:1.5;color:{Verde};word-break:break-all;text-decoration:underline;"">{href}</a>
    </td>
  </tr>
</table>";
    }

    /// <summary>Recuadro de consejo de seguridad (borde rojo).</summary>
    public static string CajaSeguridad(string texto)
        => $@"<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" border=""0"" style=""margin:0;"">
  <tr>
    <td style=""background:{Fondo};border-left:3px solid {Rojo};border-radius:8px;padding:12px 16px;"">
      <div style=""font-size:11px;line-height:1.6;color:{Texto};"">
        <strong style=""color:{Rojo};"">Consejo de seguridad:</strong> {Codificar(texto)}
      </div>
    </td>
  </tr>
</table>";

    /// <summary>Franja superior/inferior mitad verde, mitad roja.</summary>
    private static string Franja(int alto)
        => $@"<tr>
            <td style=""padding:0;font-size:0;line-height:0;"">
              <table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" border=""0"">
                <tr>
                  <td width=""50%"" style=""height:{alto}px;line-height:{alto}px;font-size:0;background:{Verde};"">&nbsp;</td>
                  <td width=""50%"" style=""height:{alto}px;line-height:{alto}px;font-size:0;background:{Rojo};"">&nbsp;</td>
                </tr>
              </table>
            </td>
          </tr>";
}

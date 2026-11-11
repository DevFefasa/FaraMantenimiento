using System.Globalization;
using System.Text;
using FM.OrigenDatos.Modelos.Correo;
using static FM.Programacion.Servicios.Correo.CorreoHtml;

namespace FM.Programacion.Servicios.Correo;

/// <summary>Correo ya armado: asunto, HTML y texto plano alternativo.</summary>
public sealed record CorreoRender(string Asunto, string Html, string Texto);

/// <summary>Eventos que generan correo (también se guardan como correopendiente.fcTipo).</summary>
public static class EventosCorreo
{
    public const string Bienvenida = "BIENVENIDA";
    public const string TicketCreado = "TICKET_CREADO";
    public const string TicketAsignado = "TICKET_ASIGNADO";
    public const string TicketAprobado = "TICKET_APROBADO";
    public const string TicketRechazado = "TICKET_RECHAZADO";
    public const string TicketEnEspera = "TICKET_EN_ESPERA";
    public const string TicketResuelto = "TICKET_RESUELTO";
    public const string TicketCerrado = "TICKET_CERRADO";
    public const string SlaAlerta = "SLA_ALERTA";
}

/// <summary>Grupos de destinatarios que devuelve sp_correo_ticket_datos.</summary>
public static class GruposCorreo
{
    public const string Solicitante = "SOLICITANTE";
    public const string Responsable = "RESPONSABLE";
    public const string Jefatura = "JEFATURA";
    public const string Mantenimiento = "MANTENIMIENTO";
}

/// <summary>Plantillas HTML institucionales de FaraFix (todas en español).</summary>
public static class PlantillaCorreo
{
    private static readonly CultureInfo Cultura = CultureInfo.GetCultureInfo("es-HN");
    private const string Firma = "FaraFix · Departamento de Mantenimiento";

    private static string Fecha(DateTime? f) => f.HasValue ? f.Value.ToString("dd/MM/yyyy HH:mm", Cultura) : "—";

    public static string UrlTicket(string? urlBase, int fiTicketId) =>
        string.IsNullOrWhiteSpace(urlBase) ? "" : $"{urlBase.TrimEnd('/')}/Tickets/Detalle/{fiTicketId}";

    /// <summary>
    /// Correo de un evento de ticket para un destinatario.
    /// extra: comentario/motivo del cambio de estado o detalle de la alerta SLA; tipoSla: POR_VENCER / VENCIDO_*.
    /// </summary>
    public static CorreoRender Ticket(string evento, string grupo, string? nombreDestinatario, CorreoTicketModelo t,
        string? urlBase, string? extra = null, string? tipoSla = null, bool cierreAutomatico = false)
    {
        var url = UrlTicket(urlBase, t.FiId);
        var saludo = string.IsNullOrWhiteSpace(nombreDestinatario) ? "Hola," : $"Hola {nombreDestinatario.Trim()},";
        string etiqueta, tituloHtml, tituloTexto, intro, asunto, boton = "Ver ticket";
        var cajasExtra = new StringBuilder();
        var textoExtra = new StringBuilder();

        void Motivo(string etq, string? valor, bool rojo = true)
        {
            if (string.IsNullOrWhiteSpace(valor)) return;
            cajasExtra.Append(CajaTexto(etq, valor, rojo));
            textoExtra.AppendLine($"{etq}: {valor}");
        }

        switch (evento)
        {
            case EventosCorreo.TicketCreado when grupo == GruposCorreo.Solicitante:
                etiqueta = "Ticket recibido";
                tituloHtml = "Su solicitud fue " + Acento("registrada"); tituloTexto = "Su solicitud fue registrada";
                intro = "Recibimos su solicitud de mantenimiento. Le avisaremos por este medio cada vez que cambie de estado.";
                asunto = $"Ticket {t.FcNumero} registrado";
                break;
            case EventosCorreo.TicketCreado when grupo == GruposCorreo.Mantenimiento:
                etiqueta = "Emergencia";
                tituloHtml = "Nueva " + Acento("emergencia", rojo: true) + " por atender"; tituloTexto = "Nueva emergencia por atender";
                intro = "Se registró un ticket de emergencia. No requiere aprobación: asigne un responsable lo antes posible.";
                asunto = $"EMERGENCIA {t.FcNumero} · {t.FcSucursalNombre}";
                break;
            case EventosCorreo.TicketCreado:
                etiqueta = "Pendiente de aprobación";
                tituloHtml = "Nuevo ticket por " + Acento("aprobar"); tituloTexto = "Nuevo ticket por aprobar";
                intro = "Se registró un ticket de mantenimiento que requiere su evaluación y aprobación.";
                asunto = $"Ticket {t.FcNumero} pendiente de aprobación";
                break;
            case EventosCorreo.TicketAsignado when grupo == GruposCorreo.Responsable:
                etiqueta = "Ticket asignado";
                tituloHtml = "Se le asignó un " + Acento("ticket"); tituloTexto = "Se le asignó un ticket";
                intro = "Usted es el responsable de atender este ticket de mantenimiento.";
                asunto = $"Ticket {t.FcNumero} asignado a usted";
                if (t.FdFechaProgramada.HasValue) Motivo("Fecha programada", Fecha(t.FdFechaProgramada), rojo: false);
                break;
            case EventosCorreo.TicketAsignado:
                etiqueta = "Ticket asignado";
                tituloHtml = "Su ticket fue " + Acento("asignado"); tituloTexto = "Su ticket fue asignado";
                intro = "Su solicitud ya tiene un responsable asignado.";
                asunto = $"Ticket {t.FcNumero} asignado";
                Motivo("Responsable", t.FcResponsableNombre, rojo: false);
                if (t.FdFechaProgramada.HasValue) Motivo("Fecha programada", Fecha(t.FdFechaProgramada), rojo: false);
                break;
            case EventosCorreo.TicketAprobado:
                etiqueta = "Ticket aprobado";
                tituloHtml = "Su ticket fue " + Acento("aprobado"); tituloTexto = "Su ticket fue aprobado";
                intro = "Su solicitud fue aprobada y pasa al equipo de mantenimiento para su asignación.";
                asunto = $"Ticket {t.FcNumero} aprobado";
                Motivo("Comentario", extra, rojo: false);
                break;
            case EventosCorreo.TicketRechazado:
                etiqueta = "Ticket rechazado";
                tituloHtml = "Su ticket fue " + Acento("rechazado", rojo: true); tituloTexto = "Su ticket fue rechazado";
                intro = "Su solicitud no fue aprobada. Revise el motivo a continuación.";
                asunto = $"Ticket {t.FcNumero} rechazado";
                cajasExtra.Append(CajaTexto("Motivo del rechazo", extra));
                textoExtra.AppendLine($"Motivo del rechazo: {(string.IsNullOrWhiteSpace(extra) ? "Sin detalle adicional." : extra)}");
                break;
            case EventosCorreo.TicketEnEspera:
                etiqueta = "Ticket en espera";
                tituloHtml = "Su ticket está " + Acento("en espera"); tituloTexto = "Su ticket está en espera";
                intro = "El trabajo se pausó temporalmente. El tiempo en espera no cuenta para el SLA.";
                asunto = $"Ticket {t.FcNumero} en espera";
                Motivo("Motivo de espera", t.FcMotivoEsperaNombre);
                Motivo("Comentario", extra);
                break;
            case EventosCorreo.TicketResuelto:
                etiqueta = "Ticket resuelto";
                tituloHtml = "Su ticket fue " + Acento("resuelto"); tituloTexto = "Su ticket fue resuelto";
                intro = "El equipo de mantenimiento marcó el trabajo como terminado. Ingrese para validarlo y responder la encuesta de satisfacción; si no lo valida, el ticket se cerrará automáticamente.";
                asunto = $"Ticket {t.FcNumero} resuelto: valide el trabajo";
                boton = "Validar y calificar";
                Motivo("Comentario", extra, rojo: false);
                break;
            case EventosCorreo.TicketCerrado:
                etiqueta = "Ticket cerrado";
                tituloHtml = "Su ticket fue " + Acento("cerrado"); tituloTexto = "Su ticket fue cerrado";
                intro = cierreAutomatico
                    ? "El ticket se cerró automáticamente porque no se validó dentro del plazo."
                    : "El ticket quedó cerrado. Gracias por usar FaraFix.";
                asunto = $"Ticket {t.FcNumero} cerrado";
                Motivo("Comentario", cierreAutomatico ? null : extra, rojo: false);
                break;
            case EventosCorreo.SlaAlerta:
                var vencido = (tipoSla ?? "").StartsWith("VENCIDO", StringComparison.OrdinalIgnoreCase);
                var que = (tipoSla ?? "").ToUpperInvariant() switch
                {
                    "VENCIDO_RESPUESTA" => "respuesta",
                    "VENCIDO_SOLUCION" => "solución",
                    _ => ""
                };
                etiqueta = "Alerta SLA";
                tituloHtml = vencido
                    ? "SLA de " + Codificar(que) + " " + Acento("vencido", rojo: true)
                    : "SLA " + Acento("por vencer", rojo: true);
                tituloTexto = vencido ? $"SLA de {que} vencido" : "SLA por vencer";
                intro = vencido
                    ? "Este ticket superó el tiempo acordado. Dele prioridad y actualice su estado."
                    : "Este ticket está cerca de su tiempo límite. Atiéndalo para cumplir el SLA.";
                asunto = vencido ? $"SLA vencido · Ticket {t.FcNumero}" : $"SLA por vencer · Ticket {t.FcNumero}";
                cajasExtra.Append(FilaCajas(CajaDato("Límite respuesta", Fecha(t.FdLimiteRespuesta), true), CajaDato("Límite solución", Fecha(t.FdLimiteSolucion), true)));
                textoExtra.AppendLine($"Límite respuesta: {Fecha(t.FdLimiteRespuesta)}");
                textoExtra.AppendLine($"Límite solución: {Fecha(t.FdLimiteSolucion)}");
                Motivo("Responsable", t.FcResponsableNombre, rojo: false);
                Motivo("Detalle", extra);
                break;
            default:
                etiqueta = "Actualización de ticket";
                tituloHtml = "Actualización del " + Acento("ticket"); tituloTexto = "Actualización del ticket";
                intro = "Hubo un cambio en el ticket.";
                asunto = $"Ticket {t.FcNumero} actualizado";
                break;
        }

        var contenido = new StringBuilder()
            .Append(Parrafo(Codificar(saludo)))
            .Append(Parrafo(Codificar(intro)))
            .Append(FilaCajas(CajaDato("Ticket", t.FcNumero), CajaDato("Estado", t.FcEstadoNombre)))
            .Append(FilaCajas(CajaDato("Sucursal", t.FcSucursalNombre), CajaDato("Prioridad", t.FcPrioridadNombre)))
            .Append(cajasExtra)
            .Append(CajaTexto("Descripción", t.FcDescripcion, rojo: false))
            .Append(Boton(boton, url))
            .Append(EnlaceAlterno(url))
            .ToString();
        var html = PlantillaBase(asunto, $"{tituloTexto} · {t.FcNumero}", etiqueta, tituloHtml, contenido, Firma);

        var texto = new StringBuilder()
            .AppendLine("FARA MANTENIMIENTO · FEFASA").AppendLine()
            .AppendLine(tituloTexto.ToUpperInvariant()).AppendLine()
            .AppendLine(saludo).AppendLine(intro).AppendLine()
            .AppendLine($"Ticket: {t.FcNumero}")
            .AppendLine($"Estado: {t.FcEstadoNombre}")
            .AppendLine($"Sucursal: {t.FcSucursalNombre}")
            .AppendLine($"Prioridad: {t.FcPrioridadNombre}")
            .Append(textoExtra)
            .AppendLine($"Descripción: {t.FcDescripcion}");
        if (!string.IsNullOrWhiteSpace(url)) texto.AppendLine().AppendLine($"{boton}: {url}");
        texto.AppendLine().AppendLine("Mensaje automático; no responda a este correo.");

        return new CorreoRender(asunto, html, texto.ToString());
    }

    /// <summary>
    /// Bienvenida: el cuerpo lo encola Seguridad en texto plano (cifrado). Las líneas "Etiqueta: valor"
    /// se muestran como cajas de datos y el resto como párrafos.
    /// </summary>
    public static CorreoRender DesdeTexto(string asunto, string cuerpoPlano, string? urlBase, bool esBienvenida)
    {
        var contenido = new StringBuilder();
        foreach (var lineaCruda in cuerpoPlano.Replace("\r", "").Split('\n'))
        {
            var linea = lineaCruda.Trim();
            if (linea.Length == 0) continue;
            var i = linea.IndexOf(':');
            // "Etiqueta: valor" con etiqueta corta (hasta 3 palabras) y valor no vacío.
            var esDato = i > 0 && i < 40 && i < linea.Length - 1
                         && linea[..i].Split(' ', StringSplitOptions.RemoveEmptyEntries).Length <= 3;
            if (esDato)
                contenido.Append(CajaDato(linea[..i].Trim(), linea[(i + 1)..].Trim()));
            else
                contenido.Append(Parrafo(Codificar(linea)));
        }
        var url = string.IsNullOrWhiteSpace(urlBase) ? "" : $"{urlBase.TrimEnd('/')}/Account/Login";
        contenido.Append(Boton("Ingresar a FaraFix", url)).Append(EnlaceAlterno(url));
        if (esBienvenida)
            contenido.Append(CajaSeguridad("La contraseña es temporal: el sistema le pedirá crear una clave personal al ingresar. No la comparta con nadie."));

        var titulo = esBienvenida ? "Bienvenido a " + Acento("FaraFix") : Codificar(asunto);
        var html = PlantillaBase(asunto, asunto, esBienvenida ? "Bienvenida" : "Aviso", titulo, contenido.ToString(), Firma);
        var texto = "FARA MANTENIMIENTO · FEFASA\n\n" + cuerpoPlano.Trim()
                    + (string.IsNullOrWhiteSpace(url) ? "" : $"\n\nIngresar: {url}")
                    + "\n\nMensaje automático; no responda a este correo.";
        return new CorreoRender(asunto, html, texto);
    }
}

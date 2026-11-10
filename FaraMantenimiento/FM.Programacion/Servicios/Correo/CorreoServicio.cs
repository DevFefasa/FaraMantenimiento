using System.Security.Cryptography;
using System.Text.Json;
using FM.OrigenDatos.Modelos.Correo;
using FM.OrigenDatos.Repositorios;
using FM.Programacion.Constantes;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace FM.Programacion.Servicios.Correo;

/// <summary>
/// Correos de Fara Mantenimiento.
/// Encolar: se arma el correo (PlantillaCorreo), se cifra con Data Protection (propósito "FaraMantenimiento.Correo")
/// y se guarda en correopendiente. Los métodos Encolar* nunca lanzan excepción: un fallo se registra en el log
/// y la operación del ticket sigue.
/// Enviar: CorreoTarea llama a ProcesarPendientesAsync cada Smtp:SegundosIntervalo.
/// </summary>
public class CorreoServicio
{
    private const string FormatoJson = "JSON";

    private readonly CorreoRepositorio _repo;
    private readonly IDataProtector _protector;
    private readonly ISmtpCorreoSender _sender;
    private readonly SmtpOptions _cfg;
    private readonly IHostEnvironment _entorno;
    private readonly ILogger<CorreoServicio> _log;

    public CorreoServicio(CorreoRepositorio repo, IDataProtectionProvider dataProtection, ISmtpCorreoSender sender,
        IOptions<SmtpOptions> opciones, IHostEnvironment entorno, ILogger<CorreoServicio> log)
    {
        _repo = repo;
        _protector = dataProtection.CreateProtector(CorreoPendienteServicio.PropositoProtector);
        _sender = sender;
        _cfg = opciones.Value;
        _entorno = entorno;
        _log = log;
    }

    private sealed record Cuerpo(string Html, string Texto);

    // ================= Encolar =================

    /// <summary>Encola un correo ya armado. Devuelve false si no se pudo (sin lanzar excepción).</summary>
    public async Task<bool> EncolarAsync(string para, CorreoRender correo, string tipo, int? fiTicketId, int? fiUsuarioId, CancellationToken ct = default)
    {
        try
        {
            if (!CorreoLista.EsValido(para))
            {
                _log.LogInformation("Correo {Tipo} omitido: destinatario no válido.", tipo);
                return false;
            }
            var cifrado = _protector.Protect(JsonSerializer.Serialize(new Cuerpo(correo.Html, correo.Texto)));
            var resp = await _repo.EncolarAsync(para, correo.Asunto, cifrado, tipo, FormatoJson, fiTicketId, fiUsuarioId, ct);
            if (!resp.FbSucces)
                _log.LogWarning("No se encoló el correo {Tipo} del ticket {Ticket}: {Mensaje}", tipo, fiTicketId, resp.FcMensaje);
            return resp.FbSucces;
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _log.LogError(ex, "Error al encolar el correo {Tipo} del ticket {Ticket}", tipo, fiTicketId);
            return false;
        }
    }

    /// <summary>Ticket creado: confirmación al solicitante y aviso a jefatura (emergencia: a mantenimiento/ADMIN).</summary>
    public Task<int> EncolarTicketCreadoAsync(int fiTicketId, int? fiUsuarioId, CancellationToken ct = default) =>
        EncolarTicketAsync(fiTicketId, EventosCorreo.TicketCreado, t => t.FbRequiereAprobacion
            ? new[] { GruposCorreo.Solicitante, GruposCorreo.Jefatura }
            : new[] { GruposCorreo.Solicitante, GruposCorreo.Mantenimiento },
            null, null, false, fiUsuarioId, ct);

    /// <summary>Ticket asignado: al técnico/proveedor (si tiene correo) y al solicitante.</summary>
    public Task<int> EncolarTicketAsignadoAsync(int fiTicketId, int? fiUsuarioId, CancellationToken ct = default) =>
        EncolarTicketAsync(fiTicketId, EventosCorreo.TicketAsignado, _ => new[] { GruposCorreo.Responsable, GruposCorreo.Solicitante },
            null, null, false, fiUsuarioId, ct);

    /// <summary>Cambio de estado relevante para el solicitante (aprobado, rechazado, en espera, resuelto, cerrado).</summary>
    public Task<int> EncolarCambioEstadoAsync(int fiTicketId, string estado, string? comentario, int? fiUsuarioId,
        bool cierreAutomatico = false, CancellationToken ct = default)
    {
        var evento = (estado ?? "").ToUpperInvariant() switch
        {
            EstadosTicket.Aprobado => EventosCorreo.TicketAprobado,
            EstadosTicket.Rechazado => EventosCorreo.TicketRechazado,
            EstadosTicket.EnEspera => EventosCorreo.TicketEnEspera,
            EstadosTicket.Resuelto => EventosCorreo.TicketResuelto,
            EstadosTicket.Cerrado => EventosCorreo.TicketCerrado,
            _ => null
        };
        if (evento == null) return Task.FromResult(0);
        return EncolarTicketAsync(fiTicketId, evento, _ => new[] { GruposCorreo.Solicitante }, comentario, null, cierreAutomatico, fiUsuarioId, ct);
    }

    /// <summary>
    /// Alertas SLA nuevas (slaalerta.fbCorreoEncolado = 0) → responsable y jefatura
    /// (si ninguno tiene correo, a mantenimiento). Cada alerta se marca para no repetir.
    /// </summary>
    public async Task<int> EncolarAlertasSlaAsync(CancellationToken ct = default)
    {
        var total = 0;
        try
        {
            var alertas = await _repo.SlaAlertasPendientesAsync(100, ct);
            if (!alertas.FbSucces) return 0;
            foreach (var a in alertas.Datos)
            {
                var n = await EncolarTicketAsync(a.FiTicketId, EventosCorreo.SlaAlerta,
                    _ => new[] { GruposCorreo.Responsable, GruposCorreo.Jefatura }, a.FcDetalle, a.FcTipo, false, null, ct,
                    gruposRespaldo: new[] { GruposCorreo.Mantenimiento });
                if (n >= 0) await _repo.SlaAlertaMarcarAsync(a.FiId, ct);
                total += Math.Max(0, n);
            }
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _log.LogError(ex, "Error al encolar correos de alertas SLA");
        }
        return total;
    }

    /// <summary>Tickets cerrados por sp_ticket_cierre_automatico (fjData {"tickets":[...]}).</summary>
    public async Task<int> EncolarCierresAutomaticosAsync(string? fjData, CancellationToken ct = default)
    {
        var total = 0;
        try
        {
            if (string.IsNullOrWhiteSpace(fjData)) return 0;
            using var doc = JsonDocument.Parse(fjData);
            if (!doc.RootElement.TryGetProperty("tickets", out var arr) || arr.ValueKind != JsonValueKind.Array) return 0;
            foreach (var el in arr.EnumerateArray())
            {
                if (el.TryGetInt32(out var id))
                    total += Math.Max(0, await EncolarCambioEstadoAsync(id, EstadosTicket.Cerrado, null, null, cierreAutomatico: true, ct));
            }
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _log.LogError(ex, "Error al encolar correos de cierre automático");
        }
        return total;
    }

    /// <summary>
    /// Arma y encola un correo por destinatario (sin repetir direcciones). Devuelve cuántos se encolaron,
    /// o -1 si no se pudieron leer los datos del ticket.
    /// </summary>
    private async Task<int> EncolarTicketAsync(int fiTicketId, string evento, Func<CorreoTicketModelo, string[]> grupos,
        string? extra, string? tipoSla, bool cierreAutomatico, int? fiUsuarioId, CancellationToken ct, string[]? gruposRespaldo = null)
    {
        try
        {
            var (cab, tickets, destinatarios) = await _repo.TicketDatosAsync(fiTicketId, ct);
            var t = tickets.FirstOrDefault();
            if (!cab.FbSucces || t == null)
            {
                _log.LogWarning("Correo {Evento}: no se leyeron los datos del ticket {Ticket} ({Mensaje})", evento, fiTicketId, cab.FcMensaje);
                return -1;
            }

            var elegidos = Elegir(destinatarios, grupos(t));
            if (elegidos.Count == 0 && gruposRespaldo != null) elegidos = Elegir(destinatarios, gruposRespaldo);

            var n = 0;
            foreach (var (grupo, d) in elegidos)
            {
                var correo = PlantillaCorreo.Ticket(evento, grupo, d.FcNombre, t, _cfg.UrlBase, extra, tipoSla, cierreAutomatico);
                if (await EncolarAsync(d.FcCorreo, correo, evento, fiTicketId, fiUsuarioId, ct)) n++;
            }
            if (elegidos.Count == 0)
                _log.LogInformation("Correo {Evento} del ticket {Ticket}: sin destinatarios con correo.", evento, t.FcNumero);
            return n;
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _log.LogError(ex, "Error al encolar correo {Evento} del ticket {Ticket}", evento, fiTicketId);
            return -1;
        }
    }

    private static List<(string Grupo, CorreoDestinatarioModelo D)> Elegir(IEnumerable<CorreoDestinatarioModelo> todos, string[] grupos)
    {
        var vistos = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var res = new List<(string, CorreoDestinatarioModelo)>();
        foreach (var g in grupos)
            foreach (var d in todos.Where(x => string.Equals(x.FcGrupo, g, StringComparison.OrdinalIgnoreCase)))
                if (CorreoLista.EsValido(d.FcCorreo) && vistos.Add(d.FcCorreo.Trim()))
                    res.Add((g, d));
        return res;
    }

    // ================= Enviar =================

    /// <summary>Envía los pendientes y los marca enviados o con error (reintento con espera creciente).</summary>
    public async Task<int> ProcesarPendientesAsync(CancellationToken ct = default)
    {
        if (!_cfg.Habilitado) return 0;
        if (_entorno.IsDevelopment() && string.IsNullOrWhiteSpace(_cfg.CorreoPruebas))
        {
            _log.LogWarning("Development sin Smtp:CorreoPruebas: no se envían correos.");
            return 0;
        }
        if (string.IsNullOrWhiteSpace(_cfg.Host) || string.IsNullOrWhiteSpace(_cfg.Remitente)
            || string.IsNullOrWhiteSpace(_cfg.Usuario) || string.IsNullOrWhiteSpace(_cfg.Password))
        {
            _log.LogWarning("SMTP incompleto (Host/Remitente/Usuario/Password); se omite esta corrida.");
            return 0;
        }

        var max = _cfg.FiMaxIntentos < 1 ? 5 : _cfg.FiMaxIntentos;
        var lote = _cfg.FiLimiteLote < 1 ? 50 : _cfg.FiLimiteLote;
        var lista = await _repo.PendientesAsync(lote, max, ct);
        if (!lista.FbSucces)
        {
            _log.LogWarning("No se pudo leer la bandeja de correos: {Mensaje}", lista.FcMensaje);
            return 0;
        }

        var enviados = 0;
        foreach (var c in lista.Datos)
        {
            ct.ThrowIfCancellationRequested();
            Cuerpo cuerpo;
            try
            {
                cuerpo = Descifrar(c);
            }
            catch (Exception ex) when (ex is CryptographicException or JsonException)
            {
                // Suele ser del entorno (otro anillo de claves de Data Protection): se reintenta como cualquier error.
                _log.LogWarning("No se pudo descifrar el correo {Id} ({Tipo}).", c.FiId, c.FcTipo);
                await MarcarErrorAsync(c.FiId, "No se pudo descifrar el cuerpo del correo (claves de Data Protection)", max, ct);
                continue;
            }

            try
            {
                await _sender.EnviarAsync(c.FcPara, c.FcAsunto, cuerpo.Html, cuerpo.Texto, ct);
                var ok = await _repo.MarcarEnviadoAsync(c.FiId, ct);
                if (!ok.FbSucces) _log.LogWarning("Correo {Id} enviado pero no se marcó: {Mensaje}", c.FiId, ok.FcMensaje);
                enviados++;
                _log.LogInformation("Correo {Id} ({Tipo}) enviado.", c.FiId, c.FcTipo);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception ex)
            {
                _log.LogWarning("Falló el envío del correo {Id} (intento {Intento}): {Error}", c.FiId, c.FiIntentos + 1, ex.Message);
                await MarcarErrorAsync(c.FiId, ex.Message, max, ct);
            }
        }
        return enviados;
    }

    private Cuerpo Descifrar(CorreoBandejaModelo c)
    {
        var plano = _protector.Unprotect(c.FcCuerpoCifrado);
        if (string.Equals(c.FcFormato, FormatoJson, StringComparison.OrdinalIgnoreCase))
            return JsonSerializer.Deserialize<Cuerpo>(plano) ?? throw new JsonException("Cuerpo vacío");
        // TEXTO (p. ej. bienvenida encolada por Seguridad): se arma la plantilla al enviar.
        var r = PlantillaCorreo.DesdeTexto(c.FcAsunto, plano, _cfg.UrlBase,
            string.Equals(c.FcTipo, EventosCorreo.Bienvenida, StringComparison.OrdinalIgnoreCase));
        return new Cuerpo(r.Html, r.Texto);
    }

    private async Task MarcarErrorAsync(int fiId, string error, int max, CancellationToken ct)
    {
        try
        {
            var r = await _repo.MarcarErrorAsync(fiId, error.Length > 500 ? error[..500] : error, max, ct);
            if (r.FbSucces && r.FjData?.Contains("\"errorDefinitivo\": 1") == true)
                _log.LogError("Correo {Id} agotó los reintentos: {Error}", fiId, error);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _log.LogError(ex, "No se pudo registrar el error del correo {Id}", fiId);
        }
    }
}

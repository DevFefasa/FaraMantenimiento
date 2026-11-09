using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Adjunto;
using FM.OrigenDatos.Repositorios;
using FM.Programacion.Opciones;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;

namespace FM.Programacion.Servicios;

/// <summary>
/// Manejo físico de adjuntos (validación, disco, BD). No valida permisos sobre la entidad:
/// eso lo hace el servicio dueño (TicketServicio para "TICKET").
/// </summary>
public class AdjuntoServicio
{
    public const string EntidadTicket = "TICKET";

    private static readonly HashSet<string> EntidadesPermitidas = new(StringComparer.OrdinalIgnoreCase) { EntidadTicket };
    public static readonly IReadOnlyCollection<string> Etapas = new[] { "SOLICITUD", "ANTES", "DESPUES" };

    // Extensión → MIME que se guarda y se devuelve (no se confía en el ContentType del cliente).
    private static readonly Dictionary<string, string> MimePorExtension = new(StringComparer.OrdinalIgnoreCase)
    {
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".png"] = "image/png",
        [".gif"] = "image/gif",
        [".webp"] = "image/webp",
        [".mp4"] = "video/mp4",
        [".mov"] = "video/quicktime",
        [".webm"] = "video/webm",
        [".pdf"] = "application/pdf",
        [".doc"] = "application/msword",
        [".docx"] = "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        [".xls"] = "application/vnd.ms-excel",
        [".xlsx"] = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    };

    private readonly AdjuntoRepositorio _repo;
    private readonly AdjuntosOptions _opt;
    private readonly IWebHostEnvironment _env;

    public AdjuntoServicio(AdjuntoRepositorio repo, IOptions<AdjuntosOptions> opt, IWebHostEnvironment env)
    {
        _repo = repo;
        _opt = opt.Value;
        _env = env;
    }

    public int MaxPorSubida => Math.Max(1, _opt.MaxPorSubida);

    public static string? NormalizarEntidad(string? entidad)
    {
        var e = (entidad ?? "").Trim().ToUpperInvariant();
        return EntidadesPermitidas.Contains(e) ? e : null;
    }

    public static string? NormalizarEtapa(string? etapa)
    {
        var e = (etapa ?? "").Trim().ToUpperInvariant();
        return Etapas.Contains(e) ? e : null;
    }

    private static RespuestaSp Error(int codigo, string mensaje) => new() { FiCodigo = codigo, FcMensaje = mensaje, FbSucces = false };

    private string RutaBaseAbsoluta()
    {
        var basePath = string.IsNullOrWhiteSpace(_opt.RutaBase) ? "C:/FaraMantenimiento/Adjuntos" : _opt.RutaBase;
        var abs = Path.IsPathRooted(basePath) ? basePath : Path.Combine(_env.ContentRootPath, basePath);
        return Path.GetFullPath(abs);
    }

    /// <summary>Ruta física dentro de la carpeta base, o null si la ruta sale de ella.</summary>
    private string? RutaSegura(string rutaRelativa)
    {
        if (string.IsNullOrWhiteSpace(rutaRelativa) || Path.IsPathRooted(rutaRelativa)) return null;
        var baseAbs = RutaBaseAbsoluta().TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
        var completa = Path.GetFullPath(Path.Combine(baseAbs, rutaRelativa.Replace('/', Path.DirectorySeparatorChar)));
        return completa.StartsWith(baseAbs, StringComparison.OrdinalIgnoreCase) ? completa : null;
    }

    /// <summary>Compara los primeros bytes del archivo con la firma esperada de su extensión.</summary>
    private static async Task<bool> FirmaValidaAsync(IFormFile archivo, string ext, CancellationToken ct)
    {
        var cab = new byte[16];
        int leidos;
        await using (var s = archivo.OpenReadStream())
            leidos = await s.ReadAsync(cab.AsMemory(0, cab.Length), ct);
        if (leidos < 4) return false;

        bool Empieza(params byte[] firma) => leidos >= firma.Length && cab.AsSpan(0, firma.Length).SequenceEqual(firma);
        bool Ascii(int pos, string txt) => leidos >= pos + txt.Length &&
            cab.AsSpan(pos, txt.Length).SequenceEqual(System.Text.Encoding.ASCII.GetBytes(txt));

        return ext.ToLowerInvariant() switch
        {
            ".jpg" or ".jpeg" => Empieza(0xFF, 0xD8, 0xFF),
            ".png" => Empieza(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A),
            ".gif" => Ascii(0, "GIF87a") || Ascii(0, "GIF89a"),
            ".webp" => Ascii(0, "RIFF") && Ascii(8, "WEBP"),
            ".pdf" => Ascii(0, "%PDF"),
            ".docx" or ".xlsx" => Empieza(0x50, 0x4B, 0x03, 0x04),
            ".doc" or ".xls" => Empieza(0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1),
            ".webm" => Empieza(0x1A, 0x45, 0xDF, 0xA3),
            ".mp4" or ".mov" => Ascii(4, "ftyp") || Ascii(4, "moov") || Ascii(4, "mdat") || Ascii(4, "wide") || Ascii(4, "free") || Ascii(4, "skip"),
            _ => false
        };
    }

    public async Task<RespuestaSp> GuardarAsync(
        string fcEntidad, int fiEntidadId, string fcEtapa, IFormFile archivo, int fiUsuarioId, CancellationToken ct = default)
    {
        var entidad = NormalizarEntidad(fcEntidad);
        if (entidad == null) return Error(400, "Entidad de adjunto no válida");
        if (fiEntidadId <= 0) return Error(400, "La entidad del adjunto es obligatoria");
        var etapa = NormalizarEtapa(fcEtapa);
        if (etapa == null) return Error(400, "La etapa debe ser SOLICITUD, ANTES o DESPUES");

        if (archivo == null || archivo.Length <= 0)
            return Error(400, "Debe seleccionar un archivo");

        var nombreOriginal = Path.GetFileName(archivo.FileName ?? "");
        var ext = Path.GetExtension(nombreOriginal) ?? "";
        if (!MimePorExtension.TryGetValue(ext, out var mime))
            return Error(400, $"Tipo de archivo no permitido: {nombreOriginal}");

        var maxBytes = Math.Max(1, _opt.TamanoMaximoMB) * 1024L * 1024L;
        if (archivo.Length > maxBytes)
            return Error(400, $"El archivo {nombreOriginal} supera el máximo de {_opt.TamanoMaximoMB} MB");

        if (!await FirmaValidaAsync(archivo, ext, ct))
            return Error(400, $"El contenido de {nombreOriginal} no corresponde a un archivo {ext}");

        var nombreDisco = $"{Guid.NewGuid():N}{ext.ToLowerInvariant()}";
        var rutaRelativa = $"{entidad}/{fiEntidadId}/{nombreDisco}";
        var rutaCompleta = RutaSegura(rutaRelativa);
        if (rutaCompleta == null) return Error(400, "Ruta de adjunto no válida");

        Directory.CreateDirectory(Path.GetDirectoryName(rutaCompleta)!);
        await using (var fs = new FileStream(rutaCompleta, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            await archivo.CopyToAsync(fs, ct);

        if (nombreOriginal.Length > 255) nombreOriginal = nombreOriginal[^255..];
        RespuestaSp resp;
        try
        {
            resp = await _repo.GuardarAsync(entidad, fiEntidadId, etapa, nombreOriginal, rutaRelativa, mime, archivo.Length, fiUsuarioId, ct);
        }
        catch
        {
            TryDelete(rutaCompleta);
            throw;
        }

        if (!resp.FbSucces) TryDelete(rutaCompleta);
        return resp;
    }

    private static void TryDelete(string ruta)
    {
        try { if (File.Exists(ruta)) File.Delete(ruta); } catch { /* no bloquear */ }
    }

    public Task<RespuestaSp<AdjuntoModelo>> ListarAsync(string fcEntidad, int fiEntidadId, string? fcEtapa = null, CancellationToken ct = default)
    {
        var entidad = NormalizarEntidad(fcEntidad);
        if (entidad == null)
            return Task.FromResult(new RespuestaSp<AdjuntoModelo> { FiCodigo = 400, FcMensaje = "Entidad de adjunto no válida", FbSucces = false });
        return _repo.ListarAsync(entidad, fiEntidadId, fcEtapa, ct);
    }

    /// <summary>Datos del adjunto (sin validar permisos).</summary>
    public async Task<(RespuestaSp Cabecera, AdjuntoModelo? Adjunto)> ObtenerAsync(int fiId, CancellationToken ct = default)
    {
        var resp = await _repo.ObtenerAsync(fiId, ct);
        return (resp, resp.FbSucces ? resp.Datos.FirstOrDefault() : null);
    }

    public async Task<(RespuestaSp Cabecera, AdjuntoModelo? Adjunto, string? RutaFisica)> ObtenerParaDescargaAsync(int fiId, CancellationToken ct = default)
    {
        var (resp, adj) = await ObtenerAsync(fiId, ct);
        if (!resp.FbSucces || adj == null)
            return (resp, null, null);

        var fisica = RutaSegura(adj.FcRuta);
        if (fisica == null || !File.Exists(fisica))
            return (Error(404, "El archivo no se encontró en disco"), adj, null);

        return (resp, adj, fisica);
    }

    /// <summary>MIME a devolver al descargar: según la extensión, nunca el guardado del cliente.</summary>
    public static string MimeDescarga(AdjuntoModelo adj)
    {
        var ext = Path.GetExtension(adj.FcRuta ?? adj.FcNombreOriginal ?? "");
        return MimePorExtension.TryGetValue(ext, out var m) ? m : "application/octet-stream";
    }

    public async Task<RespuestaSp> EliminarAsync(int fiId, int fiUsuarioId, CancellationToken ct = default)
    {
        var (_, adj) = await ObtenerAsync(fiId, ct);
        var resp = await _repo.EliminarAsync(fiId, fiUsuarioId, ct);
        if (resp.FbSucces && adj != null && RutaSegura(adj.FcRuta) is { } fisica)
            TryDelete(fisica);
        return resp;
    }
}

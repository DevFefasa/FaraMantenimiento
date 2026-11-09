using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FM.OrigenDatos.Api;
using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Seguridad;
using FM.OrigenDatos.Repositorios;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;

namespace FM.Programacion.Servicios;

/// <summary>Estado vigente de la sesión, leído de la BD en cada petición.</summary>
public sealed class SesionVigente
{
    public int FiRolId { get; init; }
    public string FcRolCodigo { get; init; } = "";
    public IReadOnlyCollection<string> Permisos { get; init; } = Array.Empty<string>();
}

public class SeguridadServicio
{
    // Bloqueo por intentos fallidos (por usuario, en memoria del servidor).
    private const int MaxIntentos = 5;
    private static readonly TimeSpan VentanaBloqueo = TimeSpan.FromMinutes(15);

    // Formato de hash: pbkdf2$<iteraciones>$<sal base64>$<hash base64>
    private const string PrefijoPbkdf2 = "pbkdf2";
    private const int Iteraciones = 210_000;
    private const int BytesSal = 16;
    private const int BytesHash = 32;

    private readonly SeguridadRepositorio _repo;
    private readonly IActiveDirectoryApi _ad;
    private readonly IConfiguration _config;
    private readonly IMemoryCache _cache;

    public SeguridadServicio(SeguridadRepositorio repo, IActiveDirectoryApi ad, IConfiguration config, IMemoryCache cache)
    {
        _repo = repo;
        _ad = ad;
        _config = config;
        _cache = cache;
    }

    public static string NormalizarUsuario(string? usuario)
    {
        if (string.IsNullOrWhiteSpace(usuario)) return "";
        var u = usuario.Trim();
        var slash = u.LastIndexOf('\\');
        if (slash >= 0 && slash < u.Length - 1) u = u[(slash + 1)..];
        var at = u.IndexOf('@');
        if (at > 0) u = u[..at];
        return u.Length > 100 ? u[..100] : u;
    }

    /// <summary>Hash PBKDF2-SHA256 con sal aleatoria.</summary>
    public static string HashClave(string clave)
    {
        var sal = RandomNumberGenerator.GetBytes(BytesSal);
        var hash = Rfc2898DeriveBytes.Pbkdf2(Encoding.UTF8.GetBytes(clave), sal, Iteraciones, HashAlgorithmName.SHA256, BytesHash);
        return $"{PrefijoPbkdf2}${Iteraciones}${Convert.ToBase64String(sal)}${Convert.ToBase64String(hash)}";
    }

    /// <summary>Verifica la clave. Acepta el formato antiguo (SHA-256 hex sin sal) e indica si hay que rehacer el hash.</summary>
    public static bool VerificarClave(string hashGuardado, string clave, out bool requiereRehash)
    {
        requiereRehash = false;
        if (string.IsNullOrWhiteSpace(hashGuardado)) return false;

        var partes = hashGuardado.Split('$');
        if (partes.Length == 4 && partes[0] == PrefijoPbkdf2 && int.TryParse(partes[1], out var iter) && iter > 0)
        {
            try
            {
                var sal = Convert.FromBase64String(partes[2]);
                var esperado = Convert.FromBase64String(partes[3]);
                var calculado = Rfc2898DeriveBytes.Pbkdf2(Encoding.UTF8.GetBytes(clave), sal, iter, HashAlgorithmName.SHA256, esperado.Length);
                var ok = CryptographicOperations.FixedTimeEquals(calculado, esperado);
                requiereRehash = ok && iter < Iteraciones;
                return ok;
            }
            catch (FormatException) { return false; }
        }

        // Formato antiguo: SHA-256 hex.
        var antiguo = Encoding.ASCII.GetBytes(Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(clave))).ToLowerInvariant());
        var guardado = Encoding.ASCII.GetBytes(hashGuardado.Trim().ToLowerInvariant());
        var okAntiguo = CryptographicOperations.FixedTimeEquals(antiguo, guardado);
        requiereRehash = okAntiguo;
        return okAntiguo;
    }

    private static string ClaveBloqueo(string userName) => "login-fallos:" + userName.ToLowerInvariant();

    private bool EstaBloqueado(string userName) =>
        _cache.TryGetValue(ClaveBloqueo(userName), out int fallos) && fallos >= MaxIntentos;

    private void RegistrarFallo(string userName)
    {
        var clave = ClaveBloqueo(userName);
        var fallos = _cache.TryGetValue(clave, out int f) ? f + 1 : 1;
        _cache.Set(clave, fallos, VentanaBloqueo);
    }

    private void LimpiarFallos(string userName) => _cache.Remove(ClaveBloqueo(userName));

    /// <summary>Resultado del login. <c>DebeCrearClave</c> = entró con la clave maestra y no tiene clave propia.</summary>
    public async Task<(RespuestaSp Cabecera, UsuarioModelo? Usuario, bool DebeCrearClave)> AutenticarAsync(
        string usuario, string contrasena, string? ip, CancellationToken ct = default)
    {
        var userName = NormalizarUsuario(usuario);
        if (string.IsNullOrWhiteSpace(userName) || string.IsNullOrEmpty(contrasena))
            return (new RespuestaSp { FiCodigo = 400, FcMensaje = "Usuario y contraseña son obligatorios", FbSucces = false }, null, false);

        if (EstaBloqueado(userName))
        {
            await _repo.RegistrarAccesoAsync(null, userName, "LOGIN_BLOQUEADO", ip, "Demasiados intentos fallidos", ct);
            return (new RespuestaSp
            {
                FiCodigo = 429,
                FcMensaje = $"Demasiados intentos fallidos. Intente de nuevo en {VentanaBloqueo.TotalMinutes:0} minutos.",
                FbSucces = false
            }, null, false);
        }

        var local = await _repo.ObtenerPorLoginAsync(userName, ct);
        if (local.FbSucces && local.Datos.FirstOrDefault() is { } uLocal && uLocal.FbEsLocal)
        {
            var debeCrearClave = false;
            bool ok;
            if (!string.IsNullOrEmpty(uLocal.FcClaveHash))
            {
                // Con clave propia la clave maestra ya no sirve.
                ok = VerificarClave(uLocal.FcClaveHash, contrasena, out var rehash);
                if (ok && rehash)
                    await GuardarHashAsync(uLocal, HashClave(contrasena), ct);
            }
            else
            {
                var master = _config["Auth:LocalPassword"];
                ok = !string.IsNullOrEmpty(master) &&
                     CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(contrasena), Encoding.UTF8.GetBytes(master));
                debeCrearClave = ok;
            }

            if (!ok)
            {
                RegistrarFallo(userName);
                await _repo.RegistrarAccesoAsync(uLocal.FiId, userName, "LOGIN_FAIL", ip, "Clave local incorrecta", ct);
                return (new RespuestaSp { FiCodigo = 401, FcMensaje = "Usuario o contraseña incorrectos.", FbSucces = false }, null, false);
            }

            LimpiarFallos(userName);
            await _repo.RegistrarAccesoAsync(uLocal.FiId, userName, "LOGIN_OK", ip,
                debeCrearClave ? "Local con clave maestra (sin clave propia)" : "Local", ct);
            if (debeCrearClave)
                await _repo.RegistrarAccesoAsync(uLocal.FiId, userName, "CLAVE_MAESTRA", ip, "Uso de la clave maestra; debe crear su clave", ct);
            return (new RespuestaSp { FiCodigo = 200, FcMensaje = "OK", FbSucces = true, FjData = local.FjData }, uLocal, debeCrearClave);
        }

        var ad = await _ad.LoginAsync(userName, contrasena, ct);
        if (!ad.Success)
        {
            if (ad.StatusCode == 401) RegistrarFallo(userName);
            await _repo.RegistrarAccesoAsync(local.Datos.FirstOrDefault()?.FiId, userName, "LOGIN_FAIL", ip, ad.Status, ct);
            return (new RespuestaSp
            {
                FiCodigo = ad.StatusCode == 401 ? 401 : 400,
                FcMensaje = string.IsNullOrWhiteSpace(ad.Message) ? ActiveDirectoryApi.MensajePorStatus(ad.Status) : ad.Message,
                FbSucces = false
            }, null, false);
        }

        var alta = await _repo.LoginAdAltaAsync(userName, ad.UserName ?? userName, null, null, null, ct);
        if (!alta.FbSucces || alta.Datos.FirstOrDefault() is not { } uAd)
            return (new RespuestaSp { FiCodigo = alta.FiCodigo, FcMensaje = alta.FcMensaje, FbSucces = false }, null, false);

        LimpiarFallos(userName);
        await _repo.RegistrarAccesoAsync(uAd.FiId, userName, "LOGIN_OK", ip, "AD", ct);
        return (new RespuestaSp { FiCodigo = 200, FcMensaje = "OK", FbSucces = true, FjData = alta.FjData }, uAd, false);
    }

    private Task<RespuestaSp> GuardarHashAsync(UsuarioModelo u, string hash, CancellationToken ct) =>
        _repo.GuardarUsuarioAsync(u.FiId, u.FcUsuario, u.FcNombre, u.FcCargo, u.FcCorreo, u.FcTelefono,
            u.FiRolId, u.FiSucursalId, u.FbEsLocal, hash, u.FiId, ct);

    /// <summary>El usuario local cambia (o crea) su propia clave.</summary>
    public async Task<RespuestaSp> CambiarClavePropiaAsync(
        int fiUsuarioId, string? claveActual, string claveNueva, string claveConfirmacion, string? ip, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(claveNueva) || claveNueva.Length < 8)
            return new RespuestaSp { FiCodigo = 400, FcMensaje = "La nueva clave debe tener al menos 8 caracteres", FbSucces = false };
        if (!string.Equals(claveNueva, claveConfirmacion, StringComparison.Ordinal))
            return new RespuestaSp { FiCodigo = 400, FcMensaje = "La confirmación no coincide con la nueva clave", FbSucces = false };

        var obt = await _repo.ObtenerUsuarioAsync(fiUsuarioId, ct);
        if (!obt.FbSucces || obt.Datos.FirstOrDefault() is not { } u)
            return new RespuestaSp { FiCodigo = 404, FcMensaje = "El usuario no existe", FbSucces = false };
        if (!u.FbEsLocal)
            return new RespuestaSp { FiCodigo = 400, FcMensaje = "Los usuarios de dominio cambian su clave en Active Directory", FbSucces = false };

        // Usuario sin clave propia (entró con la clave maestra) no necesita la actual.
        // ObtenerUsuario puede no traer el hash; se relee por login para validarlo.
        var porLogin = await _repo.ObtenerPorLoginAsync(u.FcUsuario, ct);
        var hashActual = porLogin.Datos.FirstOrDefault()?.FcClaveHash;
        if (!string.IsNullOrEmpty(hashActual) && !VerificarClave(hashActual, claveActual ?? "", out _))
        {
            await _repo.RegistrarAccesoAsync(u.FiId, u.FcUsuario, "CAMBIO_CLAVE_FAIL", ip, "Clave actual incorrecta", ct);
            return new RespuestaSp { FiCodigo = 400, FcMensaje = "La clave actual es incorrecta", FbSucces = false };
        }

        var resp = await GuardarHashAsync(u, HashClave(claveNueva), ct);
        if (resp.FbSucces)
        {
            await _repo.RegistrarAccesoAsync(u.FiId, u.FcUsuario, "CAMBIO_CLAVE", ip, null, ct);
            return new RespuestaSp { FiCodigo = 200, FcMensaje = "Clave actualizada correctamente", FbSucces = true, FjData = resp.FjData };
        }
        return resp;
    }

    /// <summary>¿El usuario local todavía no tiene clave propia?</summary>
    public async Task<bool> UsuarioLocalSinClaveAsync(string fcUsuario, CancellationToken ct = default)
    {
        var r = await _repo.ObtenerPorLoginAsync(NormalizarUsuario(fcUsuario), ct);
        return r.Datos.FirstOrDefault() is { FbEsLocal: true } u && string.IsNullOrEmpty(u.FcClaveHash);
    }

    public Task<RespuestaSp<PermisoPantallaModelo>> PermisosUsuarioAsync(int fiUsuarioId, CancellationToken ct = default) =>
        _repo.PermisosUsuarioAsync(fiUsuarioId, ct);

    /// <summary>Rol y permisos vigentes. Null si el usuario o su rol están inactivos (la sesión debe cerrarse).</summary>
    public async Task<SesionVigente?> ObtenerSesionVigenteAsync(int fiUsuarioId, CancellationToken ct = default)
    {
        var resp = await _repo.PermisosUsuarioAsync(fiUsuarioId, ct);
        if (!resp.FbSucces || string.IsNullOrWhiteSpace(resp.FjData)) return null;
        try
        {
            using var doc = JsonDocument.Parse(resp.FjData);
            var root = doc.RootElement;
            if (!root.TryGetProperty("fcRolCodigo", out var rolEl)) return null;
            var rolCodigo = rolEl.GetString() ?? "";
            var rolId = 0;
            if (root.TryGetProperty("fiRolId", out var idEl))
            {
                if (idEl.ValueKind == JsonValueKind.Number) idEl.TryGetInt32(out rolId);
                else int.TryParse(idEl.GetString(), out rolId);
            }
            return new SesionVigente
            {
                FiRolId = rolId,
                FcRolCodigo = rolCodigo,
                Permisos = resp.Datos.Select(p => p.FcPantalla).ToHashSet(StringComparer.OrdinalIgnoreCase)
            };
        }
        catch (JsonException)
        {
            return null;
        }
    }

    public Task<RespuestaSp<UsuarioModelo>> ListarUsuariosAsync(bool soloActivos = true, CancellationToken ct = default) =>
        _repo.ListarUsuariosAsync(soloActivos, ct);

    public Task<RespuestaSp<UsuarioModelo>> ObtenerUsuarioAsync(int fiId, CancellationToken ct = default) =>
        _repo.ObtenerUsuarioAsync(fiId, ct);

    public Task<RespuestaSp> GuardarUsuarioAsync(
        int? fiId, string fcUsuario, string fcNombre, string? fcCargo, string? fcCorreo, string? fcTelefono,
        int fiRolId, int? fiSucursalId, bool fbEsLocal, string? contrasenaNueva, int fiUsuarioId, CancellationToken ct = default)
    {
        string? hash = string.IsNullOrWhiteSpace(contrasenaNueva) ? null : HashClave(contrasenaNueva);
        return _repo.GuardarUsuarioAsync(fiId, NormalizarUsuario(fcUsuario), fcNombre, fcCargo, fcCorreo, fcTelefono,
            fiRolId, fiSucursalId, fbEsLocal, hash, fiUsuarioId, ct);
    }

    public Task<RespuestaSp> ActivarUsuarioAsync(int fiId, bool fbActivo, int fiUsuarioId, CancellationToken ct = default) =>
        _repo.ActivarUsuarioAsync(fiId, fbActivo, fiUsuarioId, ct);

    public Task<RespuestaSp<RolModelo>> ListarRolesAsync(bool soloActivos = true, CancellationToken ct = default) =>
        _repo.ListarRolesAsync(soloActivos, ct);

    public Task<RespuestaSp<PantallaModelo>> ListarPantallasAsync(CancellationToken ct = default) =>
        _repo.ListarPantallasAsync(true, ct);

    public Task<(RespuestaSp Cabecera, List<RolModelo> Rol, List<PantallaModelo> Pantallas)> ObtenerRolPermisosAsync(int fiRolId, CancellationToken ct = default) =>
        _repo.ObtenerRolPermisosAsync(fiRolId, ct);

    public Task<RespuestaSp> GuardarRolPermisosAsync(int fiRolId, IEnumerable<string> pantallas, int fiUsuarioId, CancellationToken ct = default) =>
        _repo.GuardarRolPermisosAsync(fiRolId, pantallas, fiUsuarioId, ct);

    public Task<RespuestaSp> GuardarRolAsync(int? fiId, string fcCodigo, string fcNombre, string? fcDescripcion, int fiUsuarioId, CancellationToken ct = default) =>
        _repo.GuardarRolAsync(fiId, fcCodigo, fcNombre, fcDescripcion, fiUsuarioId, ct);

    public Task<RespuestaSp> ActivarRolAsync(int fiId, bool fbActivo, int fiUsuarioId, CancellationToken ct = default) =>
        _repo.ActivarRolAsync(fiId, fbActivo, fiUsuarioId, ct);

    public Task<RespuestaSp> RegistrarLogoutAsync(int? fiUsuarioId, string? fcUsuario, string? ip, CancellationToken ct = default) =>
        _repo.RegistrarAccesoAsync(fiUsuarioId, fcUsuario, "LOGOUT", ip, null, ct);
}

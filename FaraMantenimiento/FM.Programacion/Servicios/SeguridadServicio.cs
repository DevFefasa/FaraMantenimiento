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
    private readonly CorreoPendienteServicio _correos;

    public SeguridadServicio(
        SeguridadRepositorio repo, IActiveDirectoryApi ad, IConfiguration config, IMemoryCache cache, CorreoPendienteServicio correos)
    {
        _repo = repo;
        _ad = ad;
        _config = config;
        _cache = cache;
        _correos = correos;
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

    /// <summary>
    /// Resultado del login.
    /// <c>DebeCrearClave</c> = entró con clave maestra / temporal.
    /// <c>EntroPorLocal</c> = método Local o clave maestra (claim EsLocal / Cambiar clave).
    /// </summary>
    public async Task<(RespuestaSp Cabecera, UsuarioModelo? Usuario, bool DebeCrearClave, bool EntroPorLocal)> AutenticarAsync(
        string usuario, string contrasena, string? ip, CancellationToken ct = default)
    {
        var userName = NormalizarUsuario(usuario);
        if (string.IsNullOrWhiteSpace(userName) || string.IsNullOrEmpty(contrasena))
            return (new RespuestaSp { FiCodigo = 400, FcMensaje = "Usuario y contraseña son obligatorios", FbSucces = false }, null, false, false);

        if (EstaBloqueado(userName))
        {
            await _repo.RegistrarAccesoAsync(null, userName, "LOGIN_BLOQUEADO", ip, "Demasiados intentos fallidos", ct);
            return (new RespuestaSp
            {
                FiCodigo = 429,
                FcMensaje = $"Demasiados intentos fallidos. Intente de nuevo en {VentanaBloqueo.TotalMinutes:0} minutos.",
                FbSucces = false
            }, null, false, false);
        }

        var lookup = await _repo.ObtenerPorLoginAsync(userName, ct);
        if (lookup.FbSucces && lookup.Datos.FirstOrDefault() is { } encontrado)
        {
            var coincideUsuario = string.Equals(encontrado.FcCampoCoincide, "fcUsuario", StringComparison.OrdinalIgnoreCase)
                || (string.IsNullOrEmpty(encontrado.FcCampoCoincide)
                    && string.Equals(encontrado.FcUsuario, userName, StringComparison.OrdinalIgnoreCase));
            var tieneAd = !string.IsNullOrWhiteSpace(encontrado.FcActiveDirectory);

            if (coincideUsuario)
            {
                if (!string.IsNullOrEmpty(encontrado.FcClaveHash))
                {
                    if (VerificarClave(encontrado.FcClaveHash, contrasena, out var rehash))
                    {
                        if (rehash)
                            await GuardarHashAsync(encontrado, HashClave(contrasena), debeCambiarClave: false, ct);
                        return await LoginOkAsync(encontrado, userName, ip, lookup.FjData,
                            detalle: encontrado.FbDebeCambiarClave ? "Local (debe cambiar clave)" : "Local",
                            debeCrearClave: encontrado.FbDebeCambiarClave, entroPorLocal: true, ct);
                    }

                    if (tieneAd)
                    {
                        var adFallback = await IntentarAdAsync(encontrado.FcActiveDirectory!, contrasena, ct);
                        if (adFallback.ok)
                            return await LoginOkAsync(encontrado, userName, ip, lookup.FjData,
                                detalle: $"AD ({encontrado.FcActiveDirectory})",
                                debeCrearClave: false, entroPorLocal: false, ct);
                    }

                    RegistrarFallo(userName);
                    await _repo.RegistrarAccesoAsync(encontrado.FiId, userName, "LOGIN_FAIL", ip, "Clave local incorrecta", ct);
                    return (new RespuestaSp { FiCodigo = 401, FcMensaje = "Usuario o contraseña incorrectos.", FbSucces = false }, null, false, false);
                }

                if (tieneAd)
                {
                    var adSolo = await IntentarAdAsync(encontrado.FcActiveDirectory!, contrasena, ct);
                    if (adSolo.ok)
                        return await LoginOkAsync(encontrado, userName, ip, lookup.FjData,
                            detalle: $"AD ({encontrado.FcActiveDirectory})",
                            debeCrearClave: false, entroPorLocal: false, ct);

                    RegistrarFallo(userName);
                    await _repo.RegistrarAccesoAsync(encontrado.FiId, userName, "LOGIN_FAIL", ip, adSolo.status, ct);
                    return (new RespuestaSp
                    {
                        FiCodigo = adSolo.statusCode == 401 ? 401 : 400,
                        FcMensaje = string.IsNullOrWhiteSpace(adSolo.message) ? "Usuario o contraseña incorrectos." : adSolo.message!,
                        FbSucces = false
                    }, null, false, false);
                }

                var master = _config["Auth:LocalPassword"];
                if (!string.IsNullOrEmpty(master) &&
                    CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(contrasena), Encoding.UTF8.GetBytes(master)))
                {
                    await _repo.RegistrarAccesoAsync(encontrado.FiId, userName, "CLAVE_MAESTRA", ip, "Uso de la clave maestra; debe crear su clave", ct);
                    return await LoginOkAsync(encontrado, userName, ip, lookup.FjData,
                        detalle: "Local con clave maestra (sin clave propia)",
                        debeCrearClave: true, entroPorLocal: true, ct);
                }

                RegistrarFallo(userName);
                await _repo.RegistrarAccesoAsync(encontrado.FiId, userName, "LOGIN_FAIL", ip, "Clave local incorrecta", ct);
                return (new RespuestaSp { FiCodigo = 401, FcMensaje = "Usuario o contraseña incorrectos.", FbSucces = false }, null, false, false);
            }

            var adNombre = encontrado.FcActiveDirectory ?? userName;
            var adMatch = await IntentarAdAsync(adNombre, contrasena, ct);
            if (adMatch.ok)
                return await LoginOkAsync(encontrado, userName, ip, lookup.FjData,
                    detalle: $"AD ({adNombre})",
                    debeCrearClave: false, entroPorLocal: false, ct);

            RegistrarFallo(userName);
            await _repo.RegistrarAccesoAsync(encontrado.FiId, userName, "LOGIN_FAIL", ip, adMatch.status, ct);
            return (new RespuestaSp
            {
                FiCodigo = adMatch.statusCode == 401 ? 401 : 400,
                FcMensaje = string.IsNullOrWhiteSpace(adMatch.message) ? "Usuario o contraseña incorrectos." : adMatch.message!,
                FbSucces = false
            }, null, false, false);
        }

        var adNuevo = await IntentarAdAsync(userName, contrasena, ct);
        if (!adNuevo.ok)
        {
            if (adNuevo.statusCode == 401) RegistrarFallo(userName);
            await _repo.RegistrarAccesoAsync(null, userName, "LOGIN_FAIL", ip, adNuevo.status, ct);
            return (new RespuestaSp
            {
                FiCodigo = adNuevo.statusCode == 401 ? 401 : 400,
                FcMensaje = string.IsNullOrWhiteSpace(adNuevo.message) ? ActiveDirectoryApi.MensajePorStatus(adNuevo.status) : adNuevo.message!,
                FbSucces = false
            }, null, false, false);
        }

        var alta = await _repo.LoginAdAltaAsync(userName, adNuevo.displayName ?? userName, null, null, null, ct);
        if (!alta.FbSucces || alta.Datos.FirstOrDefault() is not { } uAd)
            return (new RespuestaSp { FiCodigo = alta.FiCodigo, FcMensaje = alta.FcMensaje, FbSucces = false }, null, false, false);

        return await LoginOkAsync(uAd, userName, ip, alta.FjData,
            detalle: $"AD ({userName})",
            debeCrearClave: false, entroPorLocal: false, ct);
    }

    private async Task<(bool ok, int statusCode, string? status, string? message, string? displayName)> IntentarAdAsync(
        string adUser, string contrasena, CancellationToken ct)
    {
        var ad = await _ad.LoginAsync(NormalizarUsuario(adUser), contrasena, ct);
        return (ad.Success, ad.StatusCode, ad.Status, ad.Message, ad.UserName);
    }

    private async Task<(RespuestaSp Cabecera, UsuarioModelo? Usuario, bool DebeCrearClave, bool EntroPorLocal)> LoginOkAsync(
        UsuarioModelo u, string userName, string? ip, string? fjData, string detalle, bool debeCrearClave, bool entroPorLocal, CancellationToken ct)
    {
        LimpiarFallos(userName);
        await _repo.RegistrarAccesoAsync(u.FiId, userName, "LOGIN_OK", ip, detalle, ct);
        return (new RespuestaSp { FiCodigo = 200, FcMensaje = "OK", FbSucces = true, FjData = fjData }, u, debeCrearClave, entroPorLocal);
    }

    // Callers: AutenticarAsync / CambiarClaveAsync; preserva área/depto del usuario
    // User instruction: "Cada usuario tiene sucursal, área y departamento"
    // Callers: AutenticarAsync/CambiarClave; User instruction: "guardar fiJefeId"
    private Task<RespuestaSp> GuardarHashAsync(UsuarioModelo u, string hash, bool debeCambiarClave, CancellationToken ct) =>
        _repo.GuardarUsuarioAsync(u.FiId, u.FcUsuario, u.FcActiveDirectory, u.FcNombre, u.FcCargo, u.FcCorreo, u.FcTelefono,
            u.FiRolId, u.FiSucursalId, u.FiAreaId, u.FiDepartamentoId, u.FiJefeId, true, hash, debeCambiarClave, u.FiId, ct);

    /// <summary>Genera contraseña aleatoria segura (12+ caracteres).</summary>
    public static string GenerarClaveAleatoria(int longitud = 14)
    {
        const string alfabeto = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
        if (longitud < 12) longitud = 12;
        var bytes = RandomNumberGenerator.GetBytes(longitud);
        var chars = new char[longitud];
        for (var i = 0; i < longitud; i++)
            chars[i] = alfabeto[bytes[i] % alfabeto.Length];
        return new string(chars);
    }

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
        // Usuario sin clave propia (clave maestra / temporal) no necesita la actual.
        var porLogin = await _repo.ObtenerPorLoginAsync(u.FcUsuario, ct);
        var uLogin = porLogin.Datos.FirstOrDefault();
        var hashActual = uLogin?.FcClaveHash;
        var debeCambiar = uLogin?.FbDebeCambiarClave == true || string.IsNullOrEmpty(hashActual);
        if (!string.IsNullOrEmpty(hashActual) && !debeCambiar && !VerificarClave(hashActual, claveActual ?? "", out _))
        {
            await _repo.RegistrarAccesoAsync(u.FiId, u.FcUsuario, "CAMBIO_CLAVE_FAIL", ip, "Clave actual incorrecta", ct);
            return new RespuestaSp { FiCodigo = 400, FcMensaje = "La clave actual es incorrecta", FbSucces = false };
        }

        var resp = await GuardarHashAsync(u, HashClave(claveNueva), debeCambiarClave: false, ct);
        if (resp.FbSucces)
        {
            await _repo.RegistrarAccesoAsync(u.FiId, u.FcUsuario, "CAMBIO_CLAVE", ip, null, ct);
            return new RespuestaSp { FiCodigo = 200, FcMensaje = "Clave actualizada correctamente", FbSucces = true, FjData = resp.FjData };
        }
        return resp;
    }

    /// <summary>¿Debe ir a CambiarClave? (sin hash o fbDebeCambiarClave).</summary>
    public async Task<bool> UsuarioDebeCambiarClaveAsync(string fcUsuario, CancellationToken ct = default)
    {
        var r = await _repo.ObtenerPorLoginAsync(NormalizarUsuario(fcUsuario), ct);
        return r.Datos.FirstOrDefault() is { } u && (string.IsNullOrEmpty(u.FcClaveHash) || u.FbDebeCambiarClave);
    }

    /// <summary>¿El usuario todavía no tiene clave propia? (compat. vista CambiarClave).</summary>
    public async Task<bool> UsuarioLocalSinClaveAsync(string fcUsuario, CancellationToken ct = default)
    {
        var r = await _repo.ObtenerPorLoginAsync(NormalizarUsuario(fcUsuario), ct);
        return r.Datos.FirstOrDefault() is { } u && string.IsNullOrEmpty(u.FcClaveHash);
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

    // Callers: SeguridadController.Usuario POST
    // User instruction: "select2 Jefe inmediato (opcional...)" + guardar fiJefeId
    public async Task<RespuestaSp> GuardarUsuarioAsync(
        int? fiId, string fcUsuario, string? fcActiveDirectory, string fcNombre, string? fcCorreo, string? fcTelefono,
        int fiRolId, int? fiSucursalId, int? fiAreaId, int? fiDepartamentoId, int? fiJefeId, string? contrasenaNueva, int fiUsuarioId, CancellationToken ct = default)
    {
        if (fiRolId <= 0)
            return new RespuestaSp { FiCodigo = 400, FcMensaje = "Seleccione un rol.", FbSucces = false };

        var esNuevo = fiId is null or <= 0;
        var userName = NormalizarUsuario(fcUsuario);
        var adName = string.IsNullOrWhiteSpace(fcActiveDirectory) ? null : NormalizarUsuario(fcActiveDirectory);
        string? hash = null;
        var debeCambiar = false;
        string? claveGenerada = null;

        if (!string.IsNullOrWhiteSpace(contrasenaNueva))
        {
            hash = HashClave(contrasenaNueva);
            debeCambiar = esNuevo;
        }
        else if (esNuevo)
        {
            if (string.IsNullOrWhiteSpace(fcCorreo))
                return new RespuestaSp
                {
                    FiCodigo = 400,
                    FcMensaje = "Ingrese el correo para enviar la contraseña generada",
                    FbSucces = false
                };
            claveGenerada = GenerarClaveAleatoria();
            hash = HashClave(claveGenerada);
            debeCambiar = true;
        }

        var resp = await _repo.GuardarUsuarioAsync(
            fiId, userName, adName, fcNombre, null, fcCorreo, fcTelefono,
            fiRolId, fiSucursalId, fiAreaId, fiDepartamentoId, fiJefeId, fbEsLocal: hash != null || !esNuevo, hash,
            esNuevo || hash != null ? debeCambiar : null, fiUsuarioId, ct);

        if (!resp.FbSucces) return resp;

        if (esNuevo && claveGenerada != null)
        {
            var correo = await _correos.EncolarBienvenidaAsync(fcCorreo!.Trim(), userName, fcNombre, claveGenerada, fiUsuarioId, ct);
            if (!correo.FbSucces)
                return new RespuestaSp
                {
                    FiCodigo = correo.FiCodigo,
                    FcMensaje = correo.FcMensaje,
                    FbSucces = false
                };
            return new RespuestaSp
            {
                FiCodigo = resp.FiCodigo,
                FcMensaje = "Usuario creado. Se enviará un correo con la contraseña cuando el correo esté configurado.",
                FbSucces = true,
                FjData = resp.FjData
            };
        }

        return resp;
    }

    public Task<RespuestaSp> ActivarUsuarioAsync(int fiId, bool fbActivo, int fiUsuarioId, CancellationToken ct = default) =>
        _repo.ActivarUsuarioAsync(fiId, fbActivo, fiUsuarioId, ct);

    public Task<RespuestaSp<RolModelo>> ListarRolesAsync(bool soloActivos = true, CancellationToken ct = default) =>
        _repo.ListarRolesAsync(soloActivos, ct);

    public Task<RespuestaSp<RolModelo>> ObtenerRolAsync(int fiId, CancellationToken ct = default) =>
        _repo.ObtenerRolAsync(fiId, ct);

    public Task<RespuestaSp<PantallaModelo>> ListarPantallasAsync(bool soloActivos = true, CancellationToken ct = default) =>
        _repo.ListarPantallasAsync(soloActivos, ct);

    public Task<RespuestaSp<PantallaModelo>> ObtenerPantallaAsync(int fiId, CancellationToken ct = default) =>
        _repo.ObtenerPantallaAsync(fiId, ct);

    public Task<RespuestaSp> GuardarPantallaAsync(
        int? fiId, string fcCodigo, string fcNombre, string? fcDescripcion, int fiOrden, int fiUsuarioId, CancellationToken ct = default) =>
        _repo.GuardarPantallaAsync(fiId, fcCodigo, fcNombre, fcDescripcion, fiOrden, fiUsuarioId, ct);

    public Task<RespuestaSp> ActivarPantallaAsync(int fiId, bool fbActivo, int fiUsuarioId, CancellationToken ct = default) =>
        _repo.ActivarPantallaAsync(fiId, fbActivo, fiUsuarioId, ct);

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

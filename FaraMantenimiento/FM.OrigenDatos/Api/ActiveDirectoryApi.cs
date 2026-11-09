using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;

namespace FM.OrigenDatos.Api;

public interface IActiveDirectoryApi
{
    Task<ActiveDirectoryAuthResult> LoginAsync(string username, string password, CancellationToken ct = default);
}

public sealed class ActiveDirectoryApi : IActiveDirectoryApi
{
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private readonly IHttpClientFactory _http;
    private readonly ActiveDirectoryOptions _options;

    public ActiveDirectoryApi(IHttpClientFactory http, IOptions<ActiveDirectoryOptions> options)
    {
        _http = http;
        _options = options.Value;
    }

    public async Task<ActiveDirectoryAuthResult> LoginAsync(string username, string password, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(_options.BaseUrl) || string.IsNullOrWhiteSpace(_options.AppName))
            return ActiveDirectoryAuthResult.Fail(503, "directory_unavailable", "El dominio no está configurado.");

        var client = _http.CreateClient("ActiveDirectory");
        try
        {
            using var response = await client.PostAsJsonAsync("api/auth/login", new
            {
                username,
                password,
                apps = _options.AppName
            }, JsonOpts, ct);

            var json = await response.Content.ReadAsStringAsync(ct);
            DirectoryPayload? parsed = null;
            if (!string.IsNullOrWhiteSpace(json))
            {
                try { parsed = JsonSerializer.Deserialize<DirectoryPayload>(json, JsonOpts); }
                catch (JsonException) { parsed = null; }
            }

            var status = string.IsNullOrWhiteSpace(parsed?.Status)
                ? StatusDesdeHttp((int)response.StatusCode)
                : parsed!.Status!;
            var message = parsed?.Message?.Trim() ?? "";
            var success = (int)response.StatusCode == 200 && parsed?.Success == true;

            return new ActiveDirectoryAuthResult
            {
                Success = success,
                StatusCode = (int)response.StatusCode,
                Status = success ? "success" : status,
                Message = string.IsNullOrWhiteSpace(message) ? MensajePorStatus(status) : message,
                UserName = parsed?.UserName
            };
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
        {
            return ActiveDirectoryAuthResult.Fail(503, "directory_unavailable", "El dominio no responde.");
        }
    }

    private static string StatusDesdeHttp(int statusCode) => statusCode switch
    {
        401 => "invalid_credentials",
        429 => "too_many_attempts",
        503 => "directory_unavailable",
        _ => ""
    };

    public static string MensajePorStatus(string? status) => status switch
    {
        "invalid_credentials" => "Usuario o contraseña incorrectos.",
        "password_expired" or "must_change_password" => "Debe cambiar la contraseña del dominio.",
        "account_locked" => "La cuenta del dominio está bloqueada.",
        "account_disabled" => "La cuenta del dominio está deshabilitada.",
        "account_expired" => "La cuenta del dominio está vencida.",
        "too_many_attempts" => "Demasiados intentos. Espere un momento antes de volver a intentar.",
        "directory_unavailable" => "El dominio no responde.",
        _ => "No se pudo validar la cuenta del dominio."
    };

    private sealed class DirectoryPayload
    {
        public bool Success { get; set; }
        public string? Status { get; set; }
        public string? Message { get; set; }
        public string? UserName { get; set; }
    }
}

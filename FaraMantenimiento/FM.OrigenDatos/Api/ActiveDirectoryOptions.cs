namespace FM.OrigenDatos.Api;

public class ActiveDirectoryOptions
{
    public const string Section = "ActiveDirectory";
    public string BaseUrl { get; set; } = "";
    public string AppName { get; set; } = "faramantenimiento";
}

public class ActiveDirectoryAuthResult
{
    public bool Success { get; set; }
    public int StatusCode { get; set; }
    public string Status { get; set; } = "";
    public string Message { get; set; } = "";
    public string? UserName { get; set; }
    public bool RequiresPasswordChange =>
        Status is "password_expired" or "must_change_password";

    public static ActiveDirectoryAuthResult Fail(int code, string status, string message) => new()
    {
        Success = false,
        StatusCode = code,
        Status = status,
        Message = message
    };
}

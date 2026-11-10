using System.Net.Mail;

namespace FM.Programacion.Servicios.Correo;

/// <summary>Separa una lista "a@x.com; b@y.com" y devuelve solo direcciones válidas, sin repetir.</summary>
public static class CorreoLista
{
    public static List<string> ExtraerValidos(string? lista)
    {
        var res = new List<string>();
        if (string.IsNullOrWhiteSpace(lista)) return res;
        foreach (var parte in lista.Split(new[] { ';', ',' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            if (MailAddress.TryCreate(parte, out var dir) && dir.Address.Contains('.') &&
                !res.Contains(dir.Address, StringComparer.OrdinalIgnoreCase))
                res.Add(dir.Address);
        }
        return res;
    }

    public static bool EsValido(string? correo) => ExtraerValidos(correo).Count == 1;
}

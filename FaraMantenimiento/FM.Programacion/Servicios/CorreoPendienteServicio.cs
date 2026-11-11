// Callers: SeguridadServicio.GuardarUsuarioAsync (bienvenida)
// API: IDataProtector "FaraMantenimiento.Correo"; CorreoPendienteRepositorio
// Schema: correopendiente.fcCuerpoCifrado
// User instruction: "CIFRADA con ASP.NET Data Protection (IDataProtector, proposito
//   \"FaraMantenimiento.Correo\")" + servicios nuevos en FM.Programacion/Servicios
using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Repositorios;
using Microsoft.AspNetCore.DataProtection;

namespace FM.Programacion.Servicios;

public class CorreoPendienteServicio
{
    public const string PropositoProtector = "FaraMantenimiento.Correo";
    public const string TipoBienvenida = "BIENVENIDA";

    private readonly CorreoPendienteRepositorio _repo;
    private readonly IDataProtector _protector;

    public CorreoPendienteServicio(CorreoPendienteRepositorio repo, IDataProtectionProvider dataProtection)
    {
        _repo = repo;
        _protector = dataProtection.CreateProtector(PropositoProtector);
    }

    public Task<RespuestaSp> EncolarBienvenidaAsync(
        string fcPara, string fcUsuario, string fcNombre, string clavePlana, int? fiCreadoPor, CancellationToken ct = default)
    {
        var cuerpoPlano =
            $"Hola {fcNombre},\n\n" +
            $"Se creó su usuario en FaraFix.\n" +
            $"Usuario: {fcUsuario}\n" +
            $"Contraseña temporal: {clavePlana}\n\n" +
            "Al ingresar con esta contraseña deberá crear una clave personal.\n\n" +
            "Ferretería FARA";
        var cifrado = _protector.Protect(cuerpoPlano);
        return _repo.GuardarAsync(fcPara, "Bienvenida — FaraFix", cifrado, TipoBienvenida, fiCreadoPor, ct);
    }
}

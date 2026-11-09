using System.ComponentModel.DataAnnotations;

namespace FaraMantenimiento.Models;

public class LoginViewModel
{
    [Display(Name = "Usuario")]
    [Required(ErrorMessage = "El usuario es obligatorio")]
    public string Usuario { get; set; } = "";

    [Display(Name = "Contraseña")]
    [Required(ErrorMessage = "La contraseña es obligatoria")]
    [DataType(DataType.Password)]
    public string Contrasena { get; set; } = "";

    [Display(Name = "Recordarme en este dispositivo")]
    public bool Recordar { get; set; }

    public string? ReturnUrl { get; set; }
}

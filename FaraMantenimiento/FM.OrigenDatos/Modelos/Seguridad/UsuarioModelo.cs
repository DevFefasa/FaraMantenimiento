namespace FM.OrigenDatos.Modelos.Seguridad;

public class UsuarioModelo
{
    public int FiId { get; set; }
    public string FcUsuario { get; set; } = "";
    public string? FcActiveDirectory { get; set; }
    /// <summary>Campo que coincidió en por_login: fcUsuario o fcActiveDirectory.</summary>
    public string? FcCampoCoincide { get; set; }
    public string FcNombre { get; set; } = "";
    public string? FcCargo { get; set; }
    public string? FcCorreo { get; set; }
    public string? FcTelefono { get; set; }
    public int FiRolId { get; set; }
    public string? FcRolCodigo { get; set; }
    public string? FcRolNombre { get; set; }
    public int? FiSucursalId { get; set; }
    public string? FcSucursalNombre { get; set; }
    public int? FiAreaId { get; set; }
    public string? FcAreaNombre { get; set; }
    public int? FiDepartamentoId { get; set; }
    public string? FcDepartamentoNombre { get; set; }
    // Callers: SeguridadController/_FormularioUsuario/Index; sp_seguridad_usuario_*
    // User instruction: "devolver fiJefeId y fcJefeNombre y guardar fiJefeId"
    public int? FiJefeId { get; set; }
    public string? FcJefeNombre { get; set; }
    public bool FbEsLocal { get; set; }
    // Callers: SeguridadController/_FormularioUsuario; sp_seguridad_usuario_*
    // User instruction: "Cada usuario tiene sucursal, área y departamento"
    public string? FcClaveHash { get; set; }
    public bool FbDebeCambiarClave { get; set; }
    public bool FbActivo { get; set; }
    public DateTime? FdUltimoAcceso { get; set; }
    public DateTime? FdCreado { get; set; }
    public DateTime? FdModificado { get; set; }
    public bool FbTieneClave { get; set; }
}

public class CorreoPendienteModelo
{
    public int FiId { get; set; }
    public string FcPara { get; set; } = "";
    public string FcAsunto { get; set; } = "";
    public string FcCuerpoCifrado { get; set; } = "";
    public string FcTipo { get; set; } = "";
    public bool FbEnviado { get; set; }
    public DateTime? FdCreado { get; set; }
    public DateTime? FdEnviado { get; set; }
    public int FiIntentos { get; set; }
}

public class RolModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public string? FcDescripcion { get; set; }
    public bool FbActivo { get; set; }
}

public class PantallaModelo
{
    public int FiId { get; set; }
    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public string? FcDescripcion { get; set; }
    public int FiOrden { get; set; }
    public bool FbActivo { get; set; }
    public bool FbAsignado { get; set; }
}

public class PermisoPantallaModelo
{
    public string FcPantalla { get; set; } = "";
    public string? FcNombre { get; set; }
}

namespace FM.OrigenDatos.Modelos.Seguridad;

public class UsuarioModelo
{
    public int FiId { get; set; }
    public string FcUsuario { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public string? FcCargo { get; set; }
    public string? FcCorreo { get; set; }
    public string? FcTelefono { get; set; }
    public int FiRolId { get; set; }
    public string? FcRolCodigo { get; set; }
    public string? FcRolNombre { get; set; }
    public int? FiSucursalId { get; set; }
    public bool FbEsLocal { get; set; }
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

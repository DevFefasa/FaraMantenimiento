namespace FM.OrigenDatos.Conexion;

public class RespuestaSp
{
    public int FiCodigo { get; set; }
    public string FcMensaje { get; set; } = "";
    public bool FbSucces { get; set; }
    public string? FjData { get; set; }
}

public class RespuestaSp<T> : RespuestaSp
{
    public List<T> Datos { get; set; } = new();
}

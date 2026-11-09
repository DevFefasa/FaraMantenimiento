namespace FM.OrigenDatos.Modelos.Comun;

/// <summary>Forma JSON estándar para respuestas AJAX del Web.</summary>
public class RespuestaApiModelo
{
    public int FiCodigo { get; set; }
    public string FcMensaje { get; set; } = "";
    public bool FbSucces { get; set; }
    public object? FjData { get; set; }
    public object? Datos { get; set; }
}

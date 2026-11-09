namespace FM.Programacion.Opciones;

public class AdjuntosOptions
{
    public const string Section = "Adjuntos";
    public string RutaBase { get; set; } = "C:/FaraMantenimiento/Adjuntos";
    public int TamanoMaximoMB { get; set; } = 25;
    public int MaxPorSubida { get; set; } = 10;
}

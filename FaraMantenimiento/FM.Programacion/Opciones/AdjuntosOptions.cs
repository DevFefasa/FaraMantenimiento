namespace FM.Programacion.Opciones;

public class AdjuntosOptions
{
    public const string Section = "Adjuntos";
    public string RutaBase { get; set; } = "C:/documentosAdjuntos/FaraMantenimiento";
    public int TamanoMaximoMB { get; set; } = 25;
    public int MaxPorSubida { get; set; } = 10;
}

namespace FM.OrigenDatos.Modelos.Adjunto;

public class AdjuntoModelo
{
    public int FiId { get; set; }
    public string FcEntidad { get; set; } = "";
    public int FiEntidadId { get; set; }
    public string FcEtapa { get; set; } = "";
    public string FcNombreOriginal { get; set; } = "";
    public string FcRuta { get; set; } = "";
    public string? FcTipoMime { get; set; }
    public long FiTamanoBytes { get; set; }
    public DateTime FdCreado { get; set; }
    public int? FiCreadoPor { get; set; }
    public bool FbActivo { get; set; }
}

using FM.OrigenDatos.Modelos.Catalogos;

namespace FaraMantenimiento.ViewModels.Catalogos;

// Callers: CatalogosController.Crear/Editar/Guardar; Views/Catalogos/_FormularioCatalogo.cshtml, Formulario.cshtml
// API: ViewModel formulario CRUD por tipo (regiones…parametros)
// Confirm: Glob ViewModels/Catalogos/** vacío; no hay CatalogoFormViewModel previo
// Fields: FiId, FcCodigo, FcNombre, FcColor (#hex), FdFechaInstalacion (yyyy-MM-dd), Combos
// User instruction: "Crear/Editar como parcial _FormularioCatalogo devuelto por GET con Request.EsModal()"

public class CatalogoFormViewModel
{
    public string Tipo { get; set; } = "";
    public string Titulo { get; set; } = "";
    public int FiId { get; set; }

    public string FcCodigo { get; set; } = "";
    public string FcNombre { get; set; } = "";
    public string? FcClave { get; set; }
    public string? FcValor { get; set; }
    public string? FcDescripcion { get; set; }
    public string? FcTipo { get; set; }
    public string? FcDireccion { get; set; }
    public string? FcTelefono { get; set; }
    public string? FcColor { get; set; }
    public string? FcRtn { get; set; }
    public string? FcContacto { get; set; }
    public string? FcCorreo { get; set; }
    public string? FcEspecialidad { get; set; }
    public string? FcMarca { get; set; }
    public string? FcModelo { get; set; }
    public string? FcSerie { get; set; }

    // Callers: CatalogosController departamentos; _FormularioCatalogo fiAreaId
    // User instruction: "En Departamentos el área se elige con select"
    public int? FiRegionId { get; set; }
    public int? FiAreaId { get; set; }
    public int? FiSucursalId { get; set; }
    public int? FiUbicacionId { get; set; }
    public int? FiCategoriaId { get; set; }
    public int? FiUsuarioId { get; set; }
    public int FiOrden { get; set; }
    public int FiHorasRespuesta { get; set; } = 4;
    public int FiHorasSolucion { get; set; } = 24;
    public DateTime? FdFechaInstalacion { get; set; }

    public bool FbFinal { get; set; }
    public bool FbRequiereAprobacion { get; set; } = true;
    public bool FbEsPreventivo { get; set; }
    public bool FbEsPostFalla { get; set; }
    public bool FbRequiereFechaSugerida { get; set; }

    public CatalogoCombosModelo Combos { get; set; } = new();
}

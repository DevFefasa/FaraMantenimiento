using System.ComponentModel.DataAnnotations;

namespace FaraMantenimiento.ViewModels.Tickets;

public class TicketCrearViewModel
{
    [Required(ErrorMessage = "La sucursal es obligatoria")]
    [Display(Name = "Sucursal")]
    public int FiSucursalId { get; set; }

    [Display(Name = "Ubicación")]
    public int? FiUbicacionId { get; set; }

    [Display(Name = "Detalle de ubicación")]
    [StringLength(250)]
    public string? FcUbicacionDetalle { get; set; }

    [Display(Name = "Activo")]
    public int? FiActivoId { get; set; }

    [Required(ErrorMessage = "El tipo es obligatorio")]
    [Display(Name = "Tipo de mantenimiento")]
    public int FiTipoMantenimientoId { get; set; }

    [Required(ErrorMessage = "La categoría es obligatoria")]
    [Display(Name = "Categoría")]
    public int FiCategoriaId { get; set; }

    [Required(ErrorMessage = "La prioridad es obligatoria")]
    [Display(Name = "Prioridad")]
    public int FiPrioridadId { get; set; }

    [Required(ErrorMessage = "La descripción es obligatoria")]
    [Display(Name = "Descripción")]
    public string FcDescripcion { get; set; } = "";

    [Display(Name = "Fecha sugerida")]
    public DateTime? FdFechaSugerida { get; set; }
}

public class TicketListaViewModel
{
    public string Titulo { get; set; } = "Tickets";
    public string Modo { get; set; } = "todos";
    public FM.Programacion.Servicios.Tickets.TicketFiltro Filtro { get; set; } = new();
    public IReadOnlyList<FM.OrigenDatos.Modelos.Tickets.TicketListaModelo> Items { get; set; } = Array.Empty<FM.OrigenDatos.Modelos.Tickets.TicketListaModelo>();
    public string? FjData { get; set; }
    public FM.OrigenDatos.Modelos.Catalogos.CatalogoCombosModelo? Combos { get; set; }
}

public class TicketDetalleViewModel
{
    public FM.OrigenDatos.Modelos.Tickets.TicketDetalleModelo Ticket { get; set; } = new();
    public List<FM.OrigenDatos.Modelos.Tickets.TicketEstadoHistorialModelo> Historial { get; set; } = new();
    public List<FM.OrigenDatos.Modelos.Tickets.TicketMaterialModelo> Materiales { get; set; } = new();
    public FM.OrigenDatos.Modelos.Tickets.TicketEncuestaModelo? Encuesta { get; set; }
    public List<FM.OrigenDatos.Modelos.Tickets.TicketComentarioModelo> Comentarios { get; set; } = new();
    public FM.Programacion.Servicios.Tickets.TicketAccionesDisponibles Acciones { get; set; } = new();
    public FM.OrigenDatos.Modelos.Catalogos.CatalogoCombosModelo? Combos { get; set; }
    public List<FM.OrigenDatos.Modelos.Adjunto.AdjuntoModelo> Adjuntos { get; set; } = new();
}

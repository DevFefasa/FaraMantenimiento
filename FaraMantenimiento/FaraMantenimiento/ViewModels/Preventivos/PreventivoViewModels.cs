using System.ComponentModel.DataAnnotations;
using FM.OrigenDatos.Modelos.Catalogos;
using FM.OrigenDatos.Modelos.Preventivos;

namespace FaraMantenimiento.ViewModels.Preventivos;

// Callers: PreventivosController + Views/Preventivos/**
// API: PreventivoListaViewModel, PreventivoCalendarioViewModel, PreventivoGuardarViewModel
// User instruction: ViewModels de preventivos para lista/calendario/modal crear-editar

public class PreventivoListaViewModel
{
    public int? SucursalId { get; set; }
    public IReadOnlyList<PlanPreventivoModelo> Planes { get; set; } = Array.Empty<PlanPreventivoModelo>();
    public CatalogoCombosModelo? Combos { get; set; }
}

public class PreventivoCalendarioViewModel
{
    public int Anio { get; set; }
    public int Mes { get; set; }
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }
    public int? SucursalId { get; set; }
    public IReadOnlyList<PreventivoCalendarioItemModelo> Eventos { get; set; } = Array.Empty<PreventivoCalendarioItemModelo>();
    public CumplimientoPreventivoResumenModelo Cumplimiento { get; set; } = new();
    public IReadOnlyList<CumplimientoPreventivoDetalleModelo> CumplimientoDetalle { get; set; } = Array.Empty<CumplimientoPreventivoDetalleModelo>();
    public CatalogoCombosModelo? Combos { get; set; }
    // Callers: PreventivosController.Calendario; Views/Preventivos/Calendario.cshtml leyenda
    // API: EstadosLeyenda para badges de color; Schema: EstadoModelo.FcCodigo/FcNombre/FcColor (#hex)
    // User instruction: "Agregar una leyenda de colores de estado"
    public IReadOnlyList<FM.OrigenDatos.Modelos.Catalogos.EstadoModelo> EstadosLeyenda { get; set; } = Array.Empty<FM.OrigenDatos.Modelos.Catalogos.EstadoModelo>();
}

public class PreventivoGuardarViewModel
{
    public int? FiId { get; set; }

    [Required(ErrorMessage = "El nombre es obligatorio")]
    [StringLength(150)]
    public string FcNombre { get; set; } = "";

    public int? FiActivoId { get; set; }

    [Required, Range(1, int.MaxValue, ErrorMessage = "La sucursal es obligatoria")]
    public int FiSucursalId { get; set; }

    public int? FiUbicacionId { get; set; }

    [Required, Range(1, int.MaxValue, ErrorMessage = "La categoría es obligatoria")]
    public int FiCategoriaId { get; set; }

    [Required, Range(1, int.MaxValue, ErrorMessage = "La prioridad es obligatoria")]
    public int FiPrioridadId { get; set; }

    public string? FcDescripcion { get; set; }

    [Required, Range(1, 3650, ErrorMessage = "La frecuencia debe ser mayor a cero")]
    public int FiFrecuenciaDias { get; set; } = 30;

    [Required(ErrorMessage = "La próxima fecha es obligatoria")]
    [DataType(DataType.Date)]
    public DateTime FdProximaFecha { get; set; } = DateTime.Today.AddDays(7);

    [Range(0, 365)]
    public int FiDiasAnticipacion { get; set; } = 7;

    public int? FiTecnicoId { get; set; }
    public int? FiProveedorId { get; set; }
}

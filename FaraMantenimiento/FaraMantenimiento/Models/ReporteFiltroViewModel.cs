using System.ComponentModel.DataAnnotations;
using FM.OrigenDatos.Modelos.Reportes;

namespace FaraMantenimiento.Models;

public class ReporteFiltroViewModel
{
    [Display(Name = "Desde")]
    [DataType(DataType.Date)]
    public DateTime? FdDesde { get; set; }

    [Display(Name = "Hasta")]
    [DataType(DataType.Date)]
    public DateTime? FdHasta { get; set; }

    [Display(Name = "Sucursal")]
    public int? FiSucursalId { get; set; }

    [Display(Name = "Región")]
    public int? FiRegionId { get; set; }

    [Display(Name = "Tipo")]
    public int? FiTipoMantenimientoId { get; set; }

    [Display(Name = "Categoría")]
    public int? FiCategoriaId { get; set; }

    [Display(Name = "Prioridad")]
    public int? FiPrioridadId { get; set; }

    [Display(Name = "Estado")]
    public int? FiEstadoId { get; set; }

    [Display(Name = "Técnico")]
    public int? FiTecnicoId { get; set; }

    [Display(Name = "Proveedor")]
    public int? FiProveedorId { get; set; }

    public string? Pestana { get; set; }

    public ReporteFiltroModelo AFiltro() => new()
    {
        FdDesde = FdDesde,
        FdHasta = FdHasta,
        FiSucursalId = FiSucursalId,
        FiRegionId = FiRegionId,
        FiTipoMantenimientoId = FiTipoMantenimientoId,
        FiCategoriaId = FiCategoriaId,
        FiPrioridadId = FiPrioridadId,
        FiEstadoId = FiEstadoId,
        FiTecnicoId = FiTecnicoId,
        FiProveedorId = FiProveedorId
    };
}

using System.Globalization;
using ClosedXML.Excel;
using FM.OrigenDatos.Modelos.Reportes;
using FM.OrigenDatos.Modelos.Tickets;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace FM.Programacion.Servicios;

public class ExportacionServicio
{
    private static readonly CultureInfo Cultura = CultureInfo.GetCultureInfo("es-HN");

    static ExportacionServicio()
    {
        QuestPDF.Settings.License = LicenseType.Community;
    }

    public static string FormatoMoneda(decimal valor) =>
        "L " + valor.ToString("#,##0.00", Cultura);

    public static string FormatoFecha(DateTime? f) =>
        f.HasValue ? f.Value.ToString("dd/MM/yyyy", Cultura) : "";

    public byte[] ExcelTabla(string titulo, IReadOnlyList<string> columnas, IEnumerable<IReadOnlyList<string>> filas)
    {
        using var wb = new XLWorkbook();
        var ws = wb.Worksheets.Add("Datos");
        ws.Cell(1, 1).Value = titulo;
        ws.Cell(1, 1).Style.Font.Bold = true;
        ws.Cell(1, 1).Style.Font.FontColor = XLColor.FromHtml("#1B5E35");
        for (var c = 0; c < columnas.Count; c++)
        {
            var cell = ws.Cell(3, c + 1);
            cell.Value = columnas[c];
            cell.Style.Font.Bold = true;
            cell.Style.Fill.BackgroundColor = XLColor.FromHtml("#1B5E35");
            cell.Style.Font.FontColor = XLColor.White;
        }
        var r = 4;
        foreach (var fila in filas)
        {
            for (var c = 0; c < fila.Count; c++)
                ws.Cell(r, c + 1).Value = fila[c];
            r++;
        }
        ws.Columns().AdjustToContents();
        using var ms = new MemoryStream();
        wb.SaveAs(ms);
        return ms.ToArray();
    }

    public byte[] PdfTabla(string titulo, string? subtitulo, IReadOnlyList<string> columnas, IEnumerable<IReadOnlyList<string>> filas)
    {
        var data = filas.Select(f => f.ToList()).ToList();
        var doc = Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Margin(30);
                page.Header().Column(col =>
                {
                    col.Item().Text("Fara Mantenimiento · FEFASA").FontColor("#1B5E35").SemiBold().FontSize(11);
                    col.Item().Text(titulo).FontSize(16).SemiBold().FontColor("#1B5E35");
                    if (!string.IsNullOrWhiteSpace(subtitulo))
                        col.Item().Text(subtitulo).FontSize(9).FontColor("#6E6E6E");
                    col.Item().Text("Generado: " + DateTime.Now.ToString("dd/MM/yyyy HH:mm", Cultura)).FontSize(8).FontColor("#6E6E6E");
                });
                page.Content().PaddingTop(12).Table(table =>
                {
                    table.ColumnsDefinition(cols =>
                    {
                        foreach (var _ in columnas)
                            cols.RelativeColumn();
                    });
                    table.Header(h =>
                    {
                        foreach (var c in columnas)
                            h.Cell().Background("#1B5E35").Padding(4).Text(c).FontColor("#FFFFFF").FontSize(8).SemiBold();
                    });
                    foreach (var fila in data)
                    {
                        foreach (var celda in fila)
                            table.Cell().BorderBottom(0.5f).BorderColor("#E5E5E5").Padding(3).Text(celda ?? "").FontSize(8);
                    }
                });
                page.Footer().AlignCenter().Text(t =>
                {
                    t.Span("Página ").FontSize(8);
                    t.CurrentPageNumber().FontSize(8);
                    t.Span(" de ").FontSize(8);
                    t.TotalPages().FontSize(8);
                });
            });
        });
        return doc.GeneratePdf();
    }

    public byte[] ExcelCostos(string titulo, IEnumerable<ReporteCostoModelo> filas) =>
        ExcelTabla(titulo,
            new[] { "Agrupación", "Código", "Nombre", "Tickets", "Mano de obra", "Materiales", "Proveedor", "Total" },
            filas.Select(x => (IReadOnlyList<string>)new[]
            {
                x.FcAgrupacion, x.FcCodigo, x.FcNombre, x.FiTickets.ToString(),
                FormatoMoneda(x.FnCostoManoObra), FormatoMoneda(x.FnCostoMateriales),
                FormatoMoneda(x.FnCostoProveedor), FormatoMoneda(x.FnCostoTotal)
            }));

    public byte[] PdfCostos(string titulo, string? sub, IEnumerable<ReporteCostoModelo> filas) =>
        PdfTabla(titulo, sub,
            new[] { "Agrupación", "Código", "Nombre", "Tickets", "Mano obra", "Materiales", "Proveedor", "Total" },
            filas.Select(x => (IReadOnlyList<string>)new[]
            {
                x.FcAgrupacion, x.FcCodigo, x.FcNombre, x.FiTickets.ToString(),
                FormatoMoneda(x.FnCostoManoObra), FormatoMoneda(x.FnCostoMateriales),
                FormatoMoneda(x.FnCostoProveedor), FormatoMoneda(x.FnCostoTotal)
            }));

    /// <summary>Callers: ReportesController.ExportarHojaVidaPdf. Schema: ActivoHojaVida*.</summary>
    public byte[] PdfHojaVida(
        ActivoHojaVidaModelo activo,
        IEnumerable<ActivoHojaVidaTicketModelo> tickets,
        ActivoHojaVidaTotalesModelo? totales)
    {
        var tot = totales ?? new ActivoHojaVidaTotalesModelo();
        var lista = tickets.ToList();
        var doc = Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Margin(28);
                page.Header().Column(col =>
                {
                    col.Item().Text("Fara Mantenimiento · FEFASA").FontColor("#1B5E35").SemiBold().FontSize(11);
                    col.Item().Text("Hoja de vida del activo").FontSize(16).SemiBold().FontColor("#1B5E35");
                    col.Item().Text($"{activo.FcCodigo} — {activo.FcNombre}").FontSize(11);
                    col.Item().Text("Generado: " + DateTime.Now.ToString("dd/MM/yyyy HH:mm", Cultura)).FontSize(8).FontColor("#6E6E6E");
                });
                page.Content().PaddingTop(10).Column(col =>
                {
                    col.Item().Text("Datos del activo").SemiBold().FontSize(11).FontColor("#1B5E35");
                    col.Item().PaddingBottom(8).Table(t =>
                    {
                        t.ColumnsDefinition(c => { c.RelativeColumn(); c.RelativeColumn(); });
                        void Fila(string k, string? v)
                        {
                            t.Cell().Padding(2).Text(k).FontSize(8).FontColor("#6E6E6E");
                            t.Cell().Padding(2).Text(v ?? "-").FontSize(8);
                        }
                        Fila("Sucursal", activo.FcSucursalNombre);
                        Fila("Ubicación", activo.FcUbicacionNombre);
                        Fila("Categoría", activo.FcCategoriaNombre);
                        Fila("Marca", activo.FcMarca);
                        Fila("Modelo", activo.FcModelo);
                        Fila("Serie", activo.FcSerie);
                        Fila("Instalación", FormatoFecha(activo.FdFechaInstalacion));
                    });

                    col.Item().Text("Totales").SemiBold().FontSize(11).FontColor("#1B5E35");
                    col.Item().PaddingBottom(8).Text(
                        $"Tickets: {tot.FiTickets} · Correctivos: {tot.FiCorrectivos} · Preventivos: {tot.FiPreventivos} · Reincidencias: {tot.FiReincidencias} · " +
                        $"MO: {FormatoMoneda(tot.FnCostoManoObra)} · Mat: {FormatoMoneda(tot.FnCostoMateriales)} · Prov: {FormatoMoneda(tot.FnCostoProveedor)} · " +
                        $"Total: {FormatoMoneda(tot.FnCostoTotal)} · MTBF: {(tot.FnMtbfDias?.ToString("0.##") ?? "-")} días · " +
                        $"Última intervención: {FormatoFecha(tot.FdUltimaIntervencion)}"
                    ).FontSize(8);

                    col.Item().Text("Historial de tickets").SemiBold().FontSize(11).FontColor("#1B5E35");
                    col.Item().Table(table =>
                    {
                        table.ColumnsDefinition(c =>
                        {
                            c.RelativeColumn(1.2f);
                            c.RelativeColumn(1);
                            c.RelativeColumn(1.2f);
                            c.RelativeColumn(1.2f);
                            c.RelativeColumn(1);
                            c.RelativeColumn(1.5f);
                            c.RelativeColumn(1.5f);
                            c.RelativeColumn(1);
                        });
                        table.Header(h =>
                        {
                            foreach (var c in new[] { "Número", "Fecha", "Tipo", "Categoría", "Estado", "Diagnóstico", "Causa raíz", "Costo" })
                                h.Cell().Background("#1B5E35").Padding(3).Text(c).FontColor("#FFFFFF").FontSize(7).SemiBold();
                        });
                        foreach (var x in lista)
                        {
                            table.Cell().BorderBottom(0.5f).BorderColor("#E5E5E5").Padding(2).Text(x.FcNumero).FontSize(7);
                            table.Cell().BorderBottom(0.5f).BorderColor("#E5E5E5").Padding(2).Text(FormatoFecha(x.FdFechaIngreso)).FontSize(7);
                            table.Cell().BorderBottom(0.5f).BorderColor("#E5E5E5").Padding(2).Text(x.FcTipoNombre).FontSize(7);
                            table.Cell().BorderBottom(0.5f).BorderColor("#E5E5E5").Padding(2).Text(x.FcCategoriaNombre).FontSize(7);
                            table.Cell().BorderBottom(0.5f).BorderColor("#E5E5E5").Padding(2).Text(x.FcEstadoNombre).FontSize(7);
                            table.Cell().BorderBottom(0.5f).BorderColor("#E5E5E5").Padding(2).Text(x.FcDiagnostico ?? "-").FontSize(7);
                            table.Cell().BorderBottom(0.5f).BorderColor("#E5E5E5").Padding(2).Text(x.FcCausaRaiz ?? "-").FontSize(7);
                            table.Cell().BorderBottom(0.5f).BorderColor("#E5E5E5").Padding(2).Text(FormatoMoneda(x.FnCostoTotal)).FontSize(7);
                        }
                    });
                });
                page.Footer().AlignCenter().Text(t =>
                {
                    t.Span("Página ").FontSize(8);
                    t.CurrentPageNumber().FontSize(8);
                    t.Span(" de ").FontSize(8);
                    t.TotalPages().FontSize(8);
                });
            });
        });
        return doc.GeneratePdf();
    }

    /// <summary>Listado de tickets (bandejas de TicketsController.Exportar). Respeta los filtros aplicados.</summary>
    public byte[] ExcelTickets(string titulo, IEnumerable<TicketListaModelo> filas)
    {
        static string Sla(string? s) => (s ?? "").ToUpperInvariant() switch
        {
            "VERDE" => "En tiempo",
            "AMARILLO" => "Por vencer",
            "ROJO" => "Vencido",
            "GRIS" => "Sin SLA",
            _ => s ?? ""
        };
        static string Fecha(DateTime? f) => f.HasValue ? f.Value.ToString("dd/MM/yyyy HH:mm", Cultura) : "";
        static string Responsable(TicketListaModelo t) =>
            !string.IsNullOrWhiteSpace(t.FcTecnicoNombre) ? t.FcTecnicoNombre!
            : !string.IsNullOrWhiteSpace(t.FcProveedorNombre) ? t.FcProveedorNombre! : "";

        return ExcelTabla(titulo,
            new[] { "Número", "Fecha ingreso", "Sucursal", "Tipo", "Categoría", "Prioridad", "Estado", "SLA",
                    "Límite respuesta", "Límite solución", "Solicitante", "Responsable", "Reincidencia", "Descripción" },
            filas.Select(t => (IReadOnlyList<string>)new[]
            {
                t.FcNumero, Fecha(t.FdFechaIngreso), t.FcSucursalNombre ?? "", t.FcTipoNombre ?? "", t.FcCategoriaNombre ?? "",
                t.FcPrioridadNombre ?? "", t.FcEstadoNombre ?? "", Sla(t.FcSemaforoSla),
                Fecha(t.FdLimiteRespuesta), Fecha(t.FdLimiteSolucion), t.FcSolicitanteNombre, Responsable(t),
                t.FbReincidencia ? "Sí" : "No", t.FcDescripcionCorta ?? ""
            }));
    }
}

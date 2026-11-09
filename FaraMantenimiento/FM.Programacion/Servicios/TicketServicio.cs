using FM.OrigenDatos.Conexion;
using FM.OrigenDatos.Modelos.Adjunto;
using FM.OrigenDatos.Modelos.Tickets;
using FM.OrigenDatos.Repositorios;
using FM.Programacion.Constantes;
using FM.Programacion.Servicios.Tickets;
using Microsoft.AspNetCore.Http;

namespace FM.Programacion.Servicios;

public class TicketServicio
{
    private readonly TicketRepositorio _tickets;
    private readonly AdjuntoServicio _adjuntos;
    private readonly SeguridadServicio _seguridad;

    // Pantallas que dan visibilidad sobre tickets de otros usuarios.
    private static readonly string[] PantallasVerTodos = { Pantallas.TicketTodos, Pantallas.TicketBandeja, Pantallas.TicketAprobacion };

    public TicketServicio(TicketRepositorio tickets, AdjuntoServicio adjuntos, SeguridadServicio seguridad)
    {
        _tickets = tickets;
        _adjuntos = adjuntos;
        _seguridad = seguridad;
    }

    private static RespuestaSp Prohibido(string mensaje) => new() { FiCodigo = 403, FcMensaje = mensaje, FbSucces = false };

    /// <summary>
    /// ¿Puede ver tickets de otros? Se decide por los permisos vigentes en BD (no por el nombre del rol):
    /// un rol sin TICKET_TODOS/BANDEJA/APROBACION solo ve los suyos.
    /// </summary>
    public async Task<bool> PuedeVerTodosAsync(int fiUsuarioId, CancellationToken ct = default)
    {
        if (fiUsuarioId <= 0) return false;
        var sesion = await _seguridad.ObtenerSesionVigenteAsync(fiUsuarioId, ct);
        if (sesion == null) return false;
        if (EsAdmin(sesion.FcRolCodigo)) return true;
        return PantallasVerTodos.Any(p => sesion.Permisos.Contains(p, StringComparer.OrdinalIgnoreCase));
    }

    private static bool EsAdmin(string? rol) => string.Equals(rol, Roles.Admin, StringComparison.OrdinalIgnoreCase);
    private static bool EsMant(string? rol) => string.Equals(rol, Roles.Mantenimiento, StringComparison.OrdinalIgnoreCase) || EsAdmin(rol);
    private static bool EsJefatura(string? rol) => string.Equals(rol, Roles.Jefatura, StringComparison.OrdinalIgnoreCase) || EsAdmin(rol);
    private static bool EsSolicitante(string? rol) => string.Equals(rol, Roles.Solicitante, StringComparison.OrdinalIgnoreCase);

    public async Task<RespuestaSp<TicketListaModelo>> ListarAsync(TicketFiltro filtro, int fiUsuarioId, string? rolCodigo, CancellationToken ct = default)
    {
        if (!await PuedeVerTodosAsync(fiUsuarioId, ct))
            filtro.FiSolicitanteId = fiUsuarioId;

        var param = new
        {
            p_fiSolicitanteId = filtro.FiSolicitanteId,
            p_fiEstadoId = filtro.FiEstadoId,
            p_fcEstadoCodigo = filtro.FcEstadoCodigo,
            p_fiSucursalId = filtro.FiSucursalId,
            p_fiPrioridadId = filtro.FiPrioridadId,
            p_fiTipoMantenimientoId = filtro.FiTipoMantenimientoId,
            p_fiCategoriaId = filtro.FiCategoriaId,
            p_fcTipoResponsable = filtro.FcTipoResponsable,
            p_fiTecnicoId = filtro.FiTecnicoId,
            p_fiProveedorId = filtro.FiProveedorId,
            p_fdDesde = filtro.FdDesde,
            p_fdHasta = filtro.FdHasta,
            p_fcTexto = filtro.FcTexto,
            p_fbSoloAbiertos = filtro.FbSoloAbiertos ? 1 : 0,
            p_fiPagina = filtro.FiPagina,
            p_fiTamano = filtro.FiTamano
        };
        return await _tickets.ListarAsync(param, ct);
    }

    public async Task<(TicketObtenerResultado Detalle, TicketAccionesDisponibles Acciones)> ObtenerAsync(int fiTicketId, int fiUsuarioId, string? rolCodigo, CancellationToken ct = default)
    {
        var det = await _tickets.ObtenerAsync(fiTicketId, ct);
        var acciones = new TicketAccionesDisponibles();
        if (!det.Cabecera.FbSucces || det.Ticket == null) return (det, acciones);

        var t = det.Ticket;
        var verTodos = await PuedeVerTodosAsync(fiUsuarioId, ct);
        if (!verTodos && t.FiSolicitanteId != fiUsuarioId)
        {
            det.Cabecera = Prohibido("No tiene permiso para ver este ticket");
            det.Ticket = null;
            return (det, acciones);
        }

        // Comentarios internos: solo para el personal (quien ve tickets de otros).
        if (!verTodos)
            det.Comentarios = det.Comentarios.Where(c => !c.FbInterno).ToList();

        acciones = CalcularAcciones(t, fiUsuarioId, rolCodigo);
        return (det, acciones);
    }

    public TicketAccionesDisponibles CalcularAcciones(TicketDetalleModelo t, int fiUsuarioId, string? rol)
    {
        var a = new TicketAccionesDisponibles();
        var est = t.FcEstadoCodigo ?? "";
        var esDueño = t.FiSolicitanteId == fiUsuarioId;
        var mant = EsMant(rol);
        var jef = EsJefatura(rol);
        var admin = EsAdmin(rol);
        var sol = EsSolicitante(rol) || esDueño;

        a.PuedeComentar = true;
        a.PuedeAdjuntos = mant || jef || admin || (esDueño && est is EstadosTicket.Recibido or EstadosTicket.EnEvaluacion or EstadosTicket.Asignado or EstadosTicket.EnProceso);

        if (est == EstadosTicket.Recibido && (mant || jef || admin)) a.PuedeEvaluar = true;
        if (est == EstadosTicket.EnEvaluacion && (jef || admin)) { a.PuedeAprobar = true; a.PuedeRechazar = true; a.PuedeCambiarPrioridad = true; }
        if ((est is EstadosTicket.Aprobado or EstadosTicket.Asignado or EstadosTicket.EnProceso) && (mant || jef || admin))
        {
            a.PuedeAsignar = true;
            a.PuedeCambiarPrioridad = jef || admin || mant;
        }
        // Emergencia nace en ASIGNADO sin responsable: no se inicia hasta asignarlo.
        if (est == EstadosTicket.Asignado && (mant || admin) && !string.IsNullOrWhiteSpace(t.FcTipoResponsable)) a.PuedeIniciar = true;
        if (est == EstadosTicket.EnProceso && (mant || admin))
        {
            a.PuedePonerEspera = true;
            a.PuedeResolver = true;
            a.PuedeEjecucion = true;
            a.PuedeMateriales = true;
        }
        if (est == EstadosTicket.EnEspera && (mant || admin))
        {
            a.PuedeSalirEspera = true;
            a.PuedeEjecucion = true;
            a.PuedeMateriales = true;
        }
        if (est == EstadosTicket.Resuelto && esDueño) a.PuedeEncuesta = true;
        if (est == EstadosTicket.Validado && (mant || jef || admin)) a.PuedeCerrar = true;
        if (est is EstadosTicket.Asignado && (mant || admin)) { a.PuedeEjecucion = true; a.PuedeMateriales = true; }
        return a;
    }

    public Task<RespuestaSp> CrearAsync(
        int fiUsuarioId, int fiSucursalId, int? fiUbicacionId, string? fcUbicacionDetalle,
        int? fiActivoId, int fiTipoId, int fiCategoriaId, int fiPrioridadId,
        string fcDescripcion, DateTime? fdFechaSugerida, CancellationToken ct = default) =>
        _tickets.CrearAsync(fiUsuarioId, fiSucursalId, fiUbicacionId, fcUbicacionDetalle, fiActivoId, fiTipoId, fiCategoriaId, fiPrioridadId, fcDescripcion, fdFechaSugerida, ct);

    public async Task<RespuestaSp> CambiarEstadoAsync(int fiTicketId, string fcEstado, int? fiMotivo, string? comentario, int fiUsuarioId, string? rol, CancellationToken ct = default)
    {
        var (det, acciones) = await ObtenerAsync(fiTicketId, fiUsuarioId, rol, ct);
        if (!det.Cabecera.FbSucces || det.Ticket == null) return det.Cabecera;

        var est = fcEstado.ToUpperInvariant();
        var ok = est switch
        {
            EstadosTicket.EnEvaluacion => acciones.PuedeEvaluar,
            EstadosTicket.Aprobado => acciones.PuedeAprobar,
            EstadosTicket.Rechazado => acciones.PuedeRechazar,
            EstadosTicket.EnProceso when det.Ticket.FcEstadoCodigo == EstadosTicket.Asignado => acciones.PuedeIniciar,
            EstadosTicket.EnProceso when det.Ticket.FcEstadoCodigo == EstadosTicket.EnEspera => acciones.PuedeSalirEspera,
            EstadosTicket.EnEspera => acciones.PuedePonerEspera,
            EstadosTicket.Resuelto => acciones.PuedeResolver,
            EstadosTicket.Cerrado => acciones.PuedeCerrar,
            _ => EsAdmin(rol)
        };
        if (!ok) return new RespuestaSp { FiCodigo = 403, FcMensaje = "No tiene permiso para esta transición", FbSucces = false };
        return await _tickets.CambiarEstadoAsync(fiTicketId, est, fiMotivo, comentario, fiUsuarioId, ct);
    }

    public async Task<RespuestaSp> AsignarAsync(int fiTicketId, string tipo, int? tecnicoId, int? proveedorId, DateTime? programada, int fiUsuarioId, string? rol, CancellationToken ct = default)
    {
        var (det, acciones) = await ObtenerAsync(fiTicketId, fiUsuarioId, rol, ct);
        if (!det.Cabecera.FbSucces) return det.Cabecera;
        if (!acciones.PuedeAsignar) return new RespuestaSp { FiCodigo = 403, FcMensaje = "No tiene permiso para asignar", FbSucces = false };
        return await _tickets.AsignarAsync(fiTicketId, tipo, tecnicoId, proveedorId, programada, fiUsuarioId, ct);
    }

    public async Task<RespuestaSp> CambiarPrioridadAsync(int fiTicketId, int fiPrioridadId, int fiUsuarioId, string? rol, CancellationToken ct = default)
    {
        var (det, acciones) = await ObtenerAsync(fiTicketId, fiUsuarioId, rol, ct);
        if (!det.Cabecera.FbSucces) return det.Cabecera;
        if (!acciones.PuedeCambiarPrioridad) return new RespuestaSp { FiCodigo = 403, FcMensaje = "No tiene permiso para cambiar la prioridad", FbSucces = false };
        return await _tickets.CambiarPrioridadAsync(fiTicketId, fiPrioridadId, fiUsuarioId, ct);
    }

    public async Task<RespuestaSp> GuardarEjecucionAsync(
        int fiTicketId, DateTime? inicio, DateTime? fin, decimal? horas, decimal? manoObra, decimal? proveedor,
        string? diagnostico, string? causa, string? trabajo, string? preventivas, int fiUsuarioId, string? rol, CancellationToken ct = default)
    {
        var (det, acciones) = await ObtenerAsync(fiTicketId, fiUsuarioId, rol, ct);
        if (!det.Cabecera.FbSucces) return det.Cabecera;
        if (!acciones.PuedeEjecucion) return new RespuestaSp { FiCodigo = 403, FcMensaje = "No tiene permiso para editar la ejecución", FbSucces = false };
        return await _tickets.GuardarEjecucionAsync(fiTicketId, inicio, fin, horas, manoObra, proveedor, diagnostico, causa, trabajo, preventivas, fiUsuarioId, ct);
    }

    public async Task<RespuestaSp> GuardarMaterialAsync(int? fiId, int fiTicketId, string desc, decimal cant, string? unidad, decimal costo, int fiUsuarioId, string? rol, CancellationToken ct = default)
    {
        var (det, acciones) = await ObtenerAsync(fiTicketId, fiUsuarioId, rol, ct);
        if (!det.Cabecera.FbSucces) return det.Cabecera;
        if (!acciones.PuedeMateriales) return new RespuestaSp { FiCodigo = 403, FcMensaje = "No tiene permiso para materiales", FbSucces = false };
        return await _tickets.GuardarMaterialAsync(fiId, fiTicketId, desc, cant, unidad, costo, fiUsuarioId, ct);
    }

    public async Task<RespuestaSp> EliminarMaterialAsync(int fiId, int fiTicketId, int fiUsuarioId, string? rol, CancellationToken ct = default)
    {
        var (det, acciones) = await ObtenerAsync(fiTicketId, fiUsuarioId, rol, ct);
        if (!det.Cabecera.FbSucces) return det.Cabecera;
        if (!acciones.PuedeMateriales) return new RespuestaSp { FiCodigo = 403, FcMensaje = "No tiene permiso para materiales", FbSucces = false };
        return await _tickets.EliminarMaterialAsync(fiId, fiUsuarioId, ct);
    }

    public Task<RespuestaSp> GuardarEncuestaAsync(int fiTicketId, int calificacion, bool conforme, string? comentario, int fiUsuarioId, CancellationToken ct = default) =>
        _tickets.GuardarEncuestaAsync(fiTicketId, calificacion, conforme, comentario, fiUsuarioId, ct);

    public async Task<RespuestaSp> AgregarComentarioAsync(int fiTicketId, string comentario, bool interno, int fiUsuarioId, string? rol, CancellationToken ct = default)
    {
        var (det, acciones) = await ObtenerAsync(fiTicketId, fiUsuarioId, rol, ct);
        if (!det.Cabecera.FbSucces || det.Ticket == null) return det.Cabecera;
        if (!acciones.PuedeComentar) return Prohibido("No tiene permiso para comentar este ticket");
        // Solo el personal puede dejar comentarios internos.
        if (interno && !await PuedeVerTodosAsync(fiUsuarioId, ct)) interno = false;
        return await _tickets.AgregarComentarioAsync(fiTicketId, comentario, interno, fiUsuarioId, ct);
    }

    // ===== Adjuntos del ticket (con control de acceso) =====

    public int MaxAdjuntosPorSubida => _adjuntos.MaxPorSubida;

    public async Task<RespuestaSp> SubirAdjuntoAsync(int fiTicketId, string? etapa, IFormFile archivo, int fiUsuarioId, string? rol, CancellationToken ct = default)
    {
        var (det, acciones) = await ObtenerAsync(fiTicketId, fiUsuarioId, rol, ct);
        if (!det.Cabecera.FbSucces || det.Ticket == null) return det.Cabecera;
        if (!acciones.PuedeAdjuntos) return Prohibido("No tiene permiso para adjuntar archivos a este ticket");

        var et = AdjuntoServicio.NormalizarEtapa(string.IsNullOrWhiteSpace(etapa) ? "SOLICITUD" : etapa);
        if (et == null) return new RespuestaSp { FiCodigo = 400, FcMensaje = "La etapa debe ser SOLICITUD, ANTES o DESPUES", FbSucces = false };
        // Evidencia ANTES/DESPUES solo la carga mantenimiento o jefatura.
        if (et != "SOLICITUD" && !EsMant(rol) && !EsJefatura(rol))
            return Prohibido("Solo mantenimiento puede cargar evidencia ANTES/DESPUES");

        return await _adjuntos.GuardarAsync(AdjuntoServicio.EntidadTicket, fiTicketId, et, archivo, fiUsuarioId, ct);
    }

    public async Task<RespuestaSp<AdjuntoModelo>> ListarAdjuntosAsync(int fiTicketId, string? etapa, int fiUsuarioId, string? rol, CancellationToken ct = default)
    {
        var (det, _) = await ObtenerAsync(fiTicketId, fiUsuarioId, rol, ct);
        if (!det.Cabecera.FbSucces || det.Ticket == null)
            return new RespuestaSp<AdjuntoModelo> { FiCodigo = det.Cabecera.FiCodigo, FcMensaje = det.Cabecera.FcMensaje, FbSucces = false };
        return await _adjuntos.ListarAsync(AdjuntoServicio.EntidadTicket, fiTicketId, etapa, ct);
    }

    /// <summary>Adjunto para descargar, solo si el usuario puede ver su ticket.</summary>
    public async Task<(RespuestaSp Cabecera, AdjuntoModelo? Adjunto, string? RutaFisica)> ObtenerAdjuntoParaDescargaAsync(
        int fiAdjuntoId, int fiUsuarioId, string? rol, CancellationToken ct = default)
    {
        var (cab, adj) = await _adjuntos.ObtenerAsync(fiAdjuntoId, ct);
        if (!cab.FbSucces || adj == null) return (cab, null, null);
        if (!string.Equals(adj.FcEntidad, AdjuntoServicio.EntidadTicket, StringComparison.OrdinalIgnoreCase))
            return (Prohibido("No tiene permiso para ver este adjunto"), null, null);

        var (det, _) = await ObtenerAsync(adj.FiEntidadId, fiUsuarioId, rol, ct);
        if (!det.Cabecera.FbSucces || det.Ticket == null)
            return (Prohibido("No tiene permiso para ver este adjunto"), null, null);

        return await _adjuntos.ObtenerParaDescargaAsync(fiAdjuntoId, ct);
    }

    /// <summary>Elimina un adjunto: requiere poder adjuntar en el ticket y ser el autor o de mantenimiento.</summary>
    public async Task<RespuestaSp> EliminarAdjuntoAsync(int fiAdjuntoId, int fiUsuarioId, string? rol, CancellationToken ct = default)
    {
        var (cab, adj) = await _adjuntos.ObtenerAsync(fiAdjuntoId, ct);
        if (!cab.FbSucces || adj == null) return cab;
        if (!string.Equals(adj.FcEntidad, AdjuntoServicio.EntidadTicket, StringComparison.OrdinalIgnoreCase))
            return Prohibido("No tiene permiso para eliminar este adjunto");

        var (det, acciones) = await ObtenerAsync(adj.FiEntidadId, fiUsuarioId, rol, ct);
        if (!det.Cabecera.FbSucces || det.Ticket == null || !acciones.PuedeAdjuntos
            || (adj.FiCreadoPor != fiUsuarioId && !EsMant(rol)))
            return Prohibido("No tiene permiso para eliminar este adjunto");

        return await _adjuntos.EliminarAsync(fiAdjuntoId, fiUsuarioId, ct);
    }
}

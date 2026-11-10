namespace FM.OrigenDatos.Modelos.Correo;

/// <summary>Fila de sp_correo_pendientes_listar (cuerpo cifrado; se descifra en Programación).</summary>
public class CorreoBandejaModelo
{
    public int FiId { get; set; }
    public string FcPara { get; set; } = "";
    public string FcAsunto { get; set; } = "";
    public string FcCuerpoCifrado { get; set; } = "";
    public string FcTipo { get; set; } = "";
    public string FcFormato { get; set; } = "TEXTO";
    public int? FiTicketId { get; set; }
    public int FiIntentos { get; set; }
    public DateTime FdCreado { get; set; }
}

/// <summary>Datos del ticket para las plantillas (sp_correo_ticket_datos, 2.º result set).</summary>
public class CorreoTicketModelo
{
    public int FiId { get; set; }
    public string FcNumero { get; set; } = "";
    public DateTime FdFechaIngreso { get; set; }
    public string? FcDescripcion { get; set; }
    public string? FcSolicitanteNombre { get; set; }
    public string? FcSucursalNombre { get; set; }
    public string? FcPrioridadNombre { get; set; }
    public string? FcEstadoCodigo { get; set; }
    public string? FcEstadoNombre { get; set; }
    public string? FcTipoNombre { get; set; }
    public bool FbRequiereAprobacion { get; set; } = true;
    public string? FcCategoriaNombre { get; set; }
    public string? FcMotivoEsperaNombre { get; set; }
    public string? FcTipoResponsable { get; set; }
    public string? FcResponsableNombre { get; set; }
    public DateTime? FdFechaProgramada { get; set; }
    public DateTime? FdLimiteRespuesta { get; set; }
    public DateTime? FdLimiteSolucion { get; set; }
    public string? FcUltimoComentario { get; set; }
}

/// <summary>Destinatario por grupo: SOLICITANTE, RESPONSABLE, JEFATURA, MANTENIMIENTO.</summary>
public class CorreoDestinatarioModelo
{
    public string FcGrupo { get; set; } = "";
    public string FcCorreo { get; set; } = "";
    public string? FcNombre { get; set; }
}

/// <summary>Alerta SLA sin correo encolado (sp_correo_sla_alertas_pendientes).</summary>
public class CorreoSlaAlertaModelo
{
    public int FiId { get; set; }
    public int FiTicketId { get; set; }
    public string FcTipo { get; set; } = "";
    public DateTime FdFecha { get; set; }
    public string? FcDetalle { get; set; }
}

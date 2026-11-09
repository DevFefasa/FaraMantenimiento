# Revisión de código y seguridad — Fara Mantenimiento

Fecha: 2026-11-09 · Revisor: claude2 · Alcance: solo lectura (código C#, vistas, db/migrations 01-59 y consultas SELECT a la BD local).
Rutas relativas a `FaraMantenimiento/` salvo las de `db/`. `Web` = `FaraMantenimiento/FaraMantenimiento`.

Resumen: **1 crítico, 5 altos, 9 medios, 12 bajos.** Lo más urgente: los adjuntos no validan permisos (cualquiera
descarga o borra cualquier archivo) y la ruta de subida permite path traversal.

Verificado y correcto (sin hallazgo):
- Todos los POST llevan `[ValidateAntiForgeryToken]`; todos los controladores tienen `[Authorize]` y `[RequierePermiso]` a nivel de clase o de acción (excepto lo indicado abajo).
- Sin SQL dinámico: no hay `PREPARE` en SP de negocio (solo índices condicionales en 09/29) y todo el C# usa Dapper con parámetros.
- Todos los SP de la BD devuelven la fila estándar (`fiCodigo/fcMensaje/fbSucces/fjData`); todas las columnas cumplen prefijo y tipo (consulta a `information_schema`, 0 excepciones).
- Migraciones idempotentes (`IF NOT EXISTS`, `DROP PROCEDURE IF EXISTS`, `INSERT IGNORE`, índices condicionales).
- Numeración de tickets segura en concurrencia (`ticketsecuencia` + `SELECT … FOR UPDATE` dentro de transacción + `uk_ticket_numero`).
- Emergencia (`fbRequiereAprobacion=0`) entra directo a `ASIGNADO`.
- Reloj SLA en `EN_ESPERA`: al salir se suman los minutos y se corren ambos límites; la tarea SLA excluye `EN_ESPERA`.
- Encuesta: solo el solicitante y solo en `RESUELTO` (`sp_ticket_encuesta_guardar`).
- `ReturnUrl` validado con `Url.IsLocalUrl`; `appsettings.json` sin credenciales; los SP devuelven mensajes genéricos en el 500.
- `Html.Raw(JsonSerializer.Serialize(...))` es seguro (System.Text.Json escapa `<`, `>` y `&`).

---

## CRÍTICO

### C1. Adjuntos sin control de acceso (IDOR: leer, listar, borrar, subir) [CORREGIDO]
- **Aplicado:** `AdjuntosController` solo acepta `TICKET` y delega en `TicketServicio.ListarAdjuntosAsync/ObtenerAdjuntoParaDescargaAsync/EliminarAdjuntoAsync/SubirAdjuntoAsync`, que validan el acceso al ticket con `ObtenerAsync`. Eliminar exige `PuedeAdjuntos` y ser el autor o de MANTENIMIENTO/ADMIN. Detalle lista adjuntos por el mismo camino.
- **Dónde:** `Web/Controllers/AdjuntosController.cs:17` (Listar), `:24` (Subir), `:32` (Ver), `:41` (Eliminar); `FM.Programacion/Servicios/AdjuntoServicio.cs:74-102`.
- **Problema:** el controlador solo tiene `[Authorize]`. No revisa si el usuario puede ver la entidad dueña del adjunto (el ticket), y `sp_adjunto_eliminar` no revisa quién lo subió.
- **Cómo falla:** un SOLICITANTE abre `/Adjuntos/Ver/1`, `/Ver/2`… y descarga fotos y documentos de tickets de otras sucursales. Con `POST /Adjuntos/Eliminar id=N` borra (lógicamente y del disco) evidencia ANTES/DESPUÉS de cualquier ticket. Con `/Adjuntos/Listar?entidad=TICKET&entidadId=N` enumera los adjuntos de cualquier ticket.
- **Corrección:** en `AdjuntoServicio`, recibir `fiUsuarioId` y rol y validar con `TicketServicio.ObtenerAsync` (misma regla que Detalle) antes de listar, ver o eliminar. Para eliminar: exigir `PuedeAdjuntos` y que sea el autor (`fiCreadoPor`) o un rol MANTENIMIENTO/ADMIN. Aceptar solo `fcEntidad` de una lista blanca (`TICKET`, …). Si el controlador genérico no hace falta, quitarlo y dejar solo las acciones dentro de `TicketsController`.

## ALTO

### A1. Path traversal al subir adjuntos (`entidad` viene del usuario) [CORREGIDO]
- **Aplicado:** `AdjuntoServicio` usa lista blanca de entidad (`TICKET`) y etapa (`SOLICITUD/ANTES/DESPUES`), arma la ruta relativa él mismo y `RutaSegura()` comprueba con `Path.GetFullPath` que quede dentro de `RutaBase` (también al ver y eliminar). Probado: `entidad=..\..\..\Temp` → 400 sin escribir en disco.
- **Dónde:** `FM.Programacion/Servicios/AdjuntoServicio.cs:53` (`Path.Combine(RutaBaseAbsoluta(), fcEntidad, …)`), llamado desde `Web/Controllers/AdjuntosController.cs:24`.
- **Problema:** `fcEntidad` no se valida y el archivo se escribe en disco **antes** de llamar al SP. `Path.Combine` acepta `..\..\` y, si `fcEntidad` es una ruta absoluta (`C:\inetpub\wwwroot`), descarta la ruta base.
- **Cómo falla:** `POST /Adjuntos/Subir entidad=..\..\..\inetpub\wwwroot&entidadId=1&etapa=X` crea `…\wwwroot\1\<guid>.pdf` (el SP rechaza la etapa, pero el archivo ya se escribió; solo se borra en ese caso, y con una etapa válida queda). Con eso se escribe en cualquier carpeta donde el pool de IIS tenga permiso.
- **Corrección:** lista blanca de entidades (`"TICKET"`), validar etapa en C#, y comprobar `Path.GetFullPath(dir).StartsWith(Path.GetFullPath(base) + Path.DirectorySeparatorChar)`. Aplicar la misma comprobación en `ObtenerParaDescargaAsync` (`:81`) y `EliminarAsync` (`:95`) como defensa.

### A2. Subir adjunto a cualquier ticket sin validar acceso [CORREGIDO]
- **Aplicado:** `TicketServicio.SubirAdjuntoAsync` exige acceso al ticket y `PuedeAdjuntos`; ANTES/DESPUES solo MANTENIMIENTO/JEFATURA/ADMIN.
- **Dónde:** `Web/Controllers/TicketsController.cs:301-306` → `TicketServicio.SubirAdjuntoAsync` (`FM.Programacion/Servicios/TicketServicio.cs:192`).
- **Problema:** no se llama a `ObtenerAsync` ni se revisa `PuedeAdjuntos`.
- **Cómo falla:** un SOLICITANTE sube archivos (hasta 110 MB por petición) a tickets ajenos o cerrados, o carga evidencia `DESPUES` en un ticket ajeno.
- **Corrección:** igual que `AsignarAsync`: `ObtenerAsync` y luego exigir `acciones.PuedeAdjuntos`; validar que la etapa corresponda al rol (SOLICITUD para el solicitante; ANTES/DESPUES para mantenimiento).

### A3. Comentarios en tickets ajenos y comentarios "internos" del solicitante [CORREGIDO]
- **Aplicado:** `AgregarComentarioAsync` valida acceso con `ObtenerAsync`; `interno` se fuerza a `false` si el usuario no tiene permiso de ver tickets de otros.
- **Dónde:** `Web/Controllers/TicketsController.cs:294-299`, `TicketServicio.cs:189-190`, `db/migrations/26_sp_ticket_comentario_agregar` (sin validación de usuario).
- **Problema:** no se valida acceso al ticket ni quién puede marcar `interno`.
- **Cómo falla:** un SOLICITANTE manda `POST /Tickets/Comentario id=<ajeno>&interno=true`; el comentario queda en un ticket que no es suyo y solo lo ve el personal (sirve para spam o ingeniería social).
- **Corrección:** `ObtenerAsync` primero (403 si no tiene acceso) y forzar `interno=false` cuando el rol es SOLICITANTE.

### A4. Usuario desactivado o con rol cambiado conserva el acceso [CORREGIDO]
- **Aplicado:** migración `60_sp_seguridad_permisos_usuario_rol.sql` (devuelve el rol vigente en `fjData` y 404/403 si el usuario o el rol están inactivos). `PermisosClaimsTransformation` relee rol, `fiRolId` y permisos en cada petición; si no hay sesión vigente, la petición queda anónima y se borra la cookie.
- **Dónde:** `Web/Helpers/PermisosClaimsTransformation.cs:24`, `Web/Helpers/AppAccess.cs:15`, `Web/Program.cs:18-19`.
- **Problema:** si el usuario se desactiva, `sp_seguridad_permisos_usuario` devuelve 404 y la transformación **devuelve el principal sin cambios** (con los permisos que trae la cookie). Además, el claim `ClaimTypes.Role` nunca se relee; `TienePermiso` da todo a quien tenga `ADMIN` en la cookie, y `TicketServicio` decide por ese rol.
- **Cómo falla:** se desactiva a un ADMIN o se le baja a SOLICITANTE; con la expiración deslizante de 8 h sigue entrando como ADMIN mientras use la aplicación.
- **Corrección:** si la respuesta no es exitosa, devolver un principal anónimo (o llamar a `SignOutAsync` desde un `OnValidatePrincipal` de la cookie). Releer también el código de rol (extender `sp_seguridad_permisos_usuario` para que lo devuelva, o crear `sp_seguridad_usuario_obtener`) y reemplazar el claim `Role`. Lo ideal es `CookieAuthenticationEvents.OnValidatePrincipal` con `RejectPrincipal()`.

### A5. El ticket queda atascado si el solicitante dice "no conforme" [CORREGIDO]
- **Dónde:** `db/migrations/26_sp_ticket_encuesta_comentario.sql:35` (`El ticket ya tiene encuesta`) + `db/migrations/12_ticket_tablas.sql` (`uk_ticketencuesta_ticket`).
- **Problema:** "no conforme" guarda la encuesta y regresa el ticket a `EN_PROCESO`. Cuando mantenimiento lo resuelve otra vez, el solicitante ya no puede validarlo (409) y `CambiarEstadoAsync` a `VALIDADO` solo lo permite ADMIN.
- **Cómo falla:** el ticket se queda en `RESUELTO` hasta que el cierre automático (5 días) lo cierra como "validado automático". La conformidad y la calificación del segundo intento se pierden, y los reportes de satisfacción quedan sesgados.
- **Corrección:** permitir una encuesta por ciclo de resolución: quitar la UNIQUE o agregar `fiCiclo`/`fdResuelto` a la llave, o hacer UPDATE de la encuesta si la anterior es `fbConforme=0`. Los reportes deben tomar la última.

## MEDIO

### M1. La visibilidad de tickets depende del código de rol, no de permisos [CORREGIDO]
- **Aplicado:** `TicketServicio.PuedeVerTodosAsync` (ADMIN o permiso `TICKET_TODOS`/`TICKET_BANDEJA`/`TICKET_APROBACION` vigente en BD) decide listado, detalle, acciones POST y comentarios internos. Sin ese permiso solo ve los suyos.
- **Dónde:** `FM.Programacion/Servicios/TicketServicio.cs:28` y `:60`.
- **Problema:** solo se restringe si el rol es literalmente `SOLICITANTE`. Cualquier otro rol (GERENCIA o uno nuevo creado en Seguridad → Roles) ve y lista **todos** los tickets en Detalle y en las acciones POST, aunque no tenga `TICKET_TODOS`.
- **Cómo falla:** el administrador crea el rol `SUPERVISOR_SUCURSAL` con solo `TICKET_CREAR`/`TICKET_MIOS`; ese usuario abre `/Tickets/Detalle/<cualquier id>` y ve tickets ajenos con comentarios internos.
- **Corrección:** basar la regla en permisos: puede ver todo si tiene `TICKET_TODOS`, `TICKET_BANDEJA` o `TICKET_APROBACION`; si no, solo los suyos. Pasar los permisos (o el `ClaimsPrincipal` resumido) al servicio. Lo mismo para filtrar comentarios internos.

### M2. El dashboard muestra datos globales al SOLICITANTE [CORREGIDO]
- **Dónde:** `Web/Controllers/DashboardController.cs:33-37`; seed de permisos (SOLICITANTE tiene `DASHBOARD`).
- **Problema:** el requerimiento dice que el solicitante "consulta el estado de los suyos", pero el dashboard muestra totales, SLA y costos de toda la empresa.
- **Corrección:** quitar `DASHBOARD` a SOLICITANTE en una migración nueva, o filtrar `ReporteFiltro` por `fiSolicitanteId` cuando no tenga `REPORTES`/`TICKET_TODOS`.

### M3. Contraseñas locales con SHA-256 sin sal y sin bloqueo por intentos [CORREGIDO]
- **Aplicado:** hash `pbkdf2$210000$sal$hash` (PBKDF2-SHA256, sal de 16 bytes) con comparación `FixedTimeEquals`. Los hashes SHA-256 viejos siguen siendo válidos y se rehacen al entrar. Bloqueo de 15 min tras 5 fallos por usuario (`LOGIN_BLOQUEADO` en bitácora) y límite de 20 intentos cada 5 min por IP (`AddRateLimiter`, política `login`).
- **Dónde:** `FM.Programacion/Servicios/SeguridadServicio.cs:37`; `AccountController.Login` POST.
- **Problema:** el hash es rápido y no tiene sal (vulnerable a tablas precalculadas); no hay límite de intentos ni retardo. La comparación no es de tiempo constante.
- **Corrección:** usar `PasswordHasher<T>` de ASP.NET Core Identity (PBKDF2 con sal) o `Rfc2898DeriveBytes.Pbkdf2` con 100k iteraciones o más; contar `LOGIN_FAIL` en `bitacoraacceso` y bloquear N minutos; `CryptographicOperations.FixedTimeEquals`. Agregar `AddRateLimiter` a `/Account/Login`.

### M4. Clave maestra única para todos los usuarios locales sin hash (incluye admin) [CORREGIDO]
- **Aplicado:** la clave maestra solo funciona si el usuario local no tiene hash. Su uso se registra en `bitacoraacceso` (`LOGIN_OK` "Local con clave maestra" + `CLAVE_MAESTRA`) y redirige a la nueva pantalla `Account/CambiarClave`, donde el usuario crea su clave. Desde ese momento la clave maestra deja de servirle. Probado con `admin`.
- **Dónde:** `SeguridadServicio.cs:53-56`; BD: `admin` es `fbEsLocal=1` con `fcClaveHash NULL`.
- **Problema:** `Auth:LocalPassword` abre **cualquier** usuario local sin hash, incluido el ADMIN. Si se filtra (variable de entorno, captura de pantalla), se tiene acceso de administrador.
- **Corrección:** usar la clave maestra solo para el primer acceso de `admin` y obligar a cambiarla (guardar hash), o eliminarla en producción. Registrar en bitácora cuando se use.

### M5. Login AD por HTTP en claro
- **Dónde:** `appsettings.json` → `ActiveDirectory:BaseUrl = http://192.168.10.65:7026`; `FM.OrigenDatos/Api/ActiveDirectoryApi.cs`.
- **Problema:** usuario y contraseña de dominio viajan sin cifrar por la LAN.
- **Corrección:** publicar el API de AD con HTTPS (aunque sea con certificado interno) y cambiar la URL. Pendiente de infraestructura; igual que en Fleet.

### M6. Transiciones sin bloqueo de fila (carreras) [CORREGIDO]
- **Dónde:** `db/migrations/22_sp_ticket_cambiar_estado.sql:41-44`, `23_sp_ticket_asignar_prioridad.sql` (lectura de estado), `26_…encuesta` (lectura de estado).
- **Problema:** el estado actual se lee fuera de la transacción y sin `FOR UPDATE`.
- **Cómo falla:** dos técnicos pulsan "Iniciar" o "Resolver" a la vez: ambos pasan la validación, se duplica el historial y los minutos de espera se suman dos veces (los límites SLA se corren el doble).
- **Corrección:** `START TRANSACTION` antes de leer y `SELECT … FROM ticket WHERE fiId = p_fiTicketId FOR UPDATE`; o un `UPDATE … WHERE fiId=? AND fiEstadoId=v_estadoActId` revisando `ROW_COUNT()`.

### M7. Ticket de Emergencia se puede iniciar sin responsable [CORREGIDO]
- **Aplicado (C#):** `CalcularAcciones` solo habilita `PuedeIniciar` si `fcTipoResponsable` tiene valor.
- **Dónde:** `FM.Programacion/Servicios/TicketServicio.cs:96` (`PuedeIniciar` solo revisa el estado); `22_sp_ticket_cambiar_estado.sql` (`ASIGNADO→EN_PROCESO` sin validar responsable).
- **Problema:** Emergencia nace en `ASIGNADO` "pendiente de responsable", pero se puede pasar a `EN_PROCESO` con `fcTipoResponsable` NULL.
- **Cómo falla:** el reporte de productividad por técnico o proveedor pierde los tickets de emergencia.
- **Corrección:** en el SP, rechazar `EN_PROCESO` con 409 si `fcTipoResponsable IS NULL`; en `CalcularAcciones`, `PuedeIniciar` solo si hay responsable.

### M8. XSS almacenado en el formulario de catálogos [CORREGIDO]
- **Dónde:** `Web/Views/Catalogos/Entidad.cshtml` (`inp`/`opt`/`sel`/`form.innerHTML`).
- **Problema:** los valores de catálogo (nombre, dirección, contacto…) se insertaban en HTML sin escapar.
- **Cómo falla:** un usuario con `CATALOGOS` guarda contacto `"><img src=x onerror=…>`; al editar, el script corre con la sesión del ADMIN.
- **Corrección:** función `esc()` (& < > " ') aplicada a valores en `inp`/`opt`/`sel`/`chk`; Preventivos ya usaba `textContent`/`@` (sin cambio).

### M9. La capa Web usa tipos de FM.OrigenDatos directamente
- **Dónde:** `Web/Controllers/SeguridadController.cs:43`, `TicketsController.cs:106,132`, `CatalogosController`, `PreventivosController`, `ReportesController`, `Models/ReporteFiltroViewModel.cs`, `ViewModels/*`, y vistas `Seguridad/*`, `Reportes/*`, `Catalogos/Entidad`, `Dashboard/Index`, `Preventivos/Index`, `Tickets/Crear`.
- **Problema:** CONVENCIONES §1 dice que el Web nunca usa OrigenDatos. No hay `ProjectReference` directa (bien), pero se usan sus modelos por la referencia transitiva.
- **Corrección:** a corto plazo, aceptarlo como "modelos compartidos" y documentarlo en CONVENCIONES. Si se quiere estricto, mover los DTO a FM.Programacion (`Modelos/`) o poner `<PrivateAssets>`/`DisableTransitiveProjectReferences=true` en el csproj Web y mapear.

## BAJO

| # | Dónde | Problema / escenario | Corrección |
|---|---|---|---|
| B1 [CORREGIDO; `AllowedHosts` pendiente del nombre del servidor] | `Web/Program.cs:13-20` — aplicado: cookie `.Fara.Auth` HttpOnly, SameSite=Lax, Secure=Always (salvo Development o `Auth:PermitirCookieHttp=true`); antiforgery Strict; cabeceras `nosniff`, `X-Frame-Options`, `Referrer-Policy` | La cookie no fuerza `Secure` ni `SameSite`; con HTTP la cookie viaja en claro. `AllowedHosts: "*"`. | `options.Cookie.SecurePolicy = Always; SameSite = Lax; HttpOnly = true; Cookie.Name = ".Fara.Auth"`; fijar `AllowedHosts` al host real. |
| B2 [CORREGIDO] | `AdjuntoServicio.cs:45-66` — aplicado: el MIME sale de la extensión (al guardar y al descargar) y se validan los primeros bytes de cada tipo; `nosniff` global. Probado: un `.pdf` falso → 400 | Solo valida la extensión; el `ContentType` del cliente se guarda y se devuelve en `Ver`. Un `.jpg` con contenido HTML y MIME `text/html` se sirve como HTML (mitigado porque `PhysicalFile` con nombre envía `attachment`). | Derivar el MIME de la extensión en el servidor (`FileExtensionContentTypeProvider`) y validar los primeros bytes (JPEG/PNG/PDF/ZIP-OOXML/MP4). Agregar `X-Content-Type-Options: nosniff`. |
| B3 [CORREGIDO] | `AdjuntosOptions.MaxPorSubida`, `TicketsController.cs:164-168` — aplicado: Crear acepta como máximo `MaxPorSubida` archivos y muestra en `TempData["Error"]` los omitidos o rechazados con su motivo | `MaxPorSubida` no se usa; en Crear se aceptan N archivos de 25 MB hasta 110 MB por petición y se ignoran los errores de cada uno. | Validar la cantidad contra `MaxPorSubida` y devolver al usuario los archivos rechazados. |
| B4 [CORREGIDO] | `TicketsController.cs:281-285` + `25_sp_ticket_material.sql` (`sp_ticket_material_eliminar`) | Se valida el permiso sobre el ticket `id`, pero el SP borra `materialId` sin comprobar que sea de ese ticket (IDOR entre tickets, solo para roles de mantenimiento). | Pasar `p_fiTicketId` al SP y filtrar `WHERE fiId=? AND fiTicketId=?`. |
| B5 [CORREGIDO] | `24_sp_ticket_ejecucion.sql`, `25_sp_ticket_material.sql` | Se aceptan costos, horas y cantidades negativos, y `fdFechaFin < fdFechaInicio`; esto distorsiona los reportes de costos en L. | Validar `>= 0` y orden de fechas con 400. |
| B6 [CORREGIDO] | `31_sp_sla_revisar_vencimientos.sql:62,73` + `uk_slaalerta_ticket_tipo_dia` | La alerta "por vencer" de respuesta y la de solución usan el mismo `fcTipo='POR_VENCER'`; la llave única por día hace que la segunda se descarte. | Tipos separados `POR_VENCER_RESPUESTA` / `POR_VENCER_SOLUCION`. |
| B7 [CORREGIDO] | `31_…:67-81` | El 75 % se calcula desde `fdFechaIngreso` hasta un límite ya corrido por la espera, así que la alerta sale más tarde de lo esperado. | Restar `fiMinutosEnEspera` del tiempo transcurrido. |
| B8 [CORREGIDO] | `21_sp_ticket_crear.sql:111` | La reincidencia cuenta tickets `RECHAZADO` del mismo activo y categoría. | Excluir estados `RECHAZADO` (o marcados como no válidos). |
| B9 [CORREGIDO] | `23_sp_ticket_asignar_prioridad.sql:49-50` | MariaDB asigna el `SET` de izquierda a derecha: `fbSlaRespuestaCumplido` ve el `fdPrimeraRespuesta` ya actualizado y nunca se calcula ahí (hoy no afecta porque EN_EVALUACION ya fijó la primera respuesta). | Calcular en variables antes del UPDATE, como en el SP 22. |
| B10 [CORREGIDO] | `23_…sp_ticket_cambiar_prioridad` | No deja historial ni recalcula `fbSla*Cumplido`; se permite en `RESUELTO`/`VALIDADO`, lo que cambia los límites sin recalcular el cumplimiento. | Insertar registro de auditoría (comentario de sistema), permitirlo solo antes de `RESUELTO`, recalcular las banderas. |
| B11 [CORREGIDO] | `28_sp_ticket_listar.sql` | No tiene `EXIT HANDLER`; `fiPagina` enorme desborda `v_offset` y la excepción llega al controlador (página de error). | Limitar `v_pag` (p. ej. ≤ 100000) y agregar un handler 500 genérico. |
| B12 [CORREGIDO] | `31_…:86`, `32_…:171` | `fjData` se arma con `CONCAT` en lugar de `JSON_OBJECT`/`JSON_ARRAYAGG` (es frágil si cambia un tipo). | Usar funciones JSON. |

---

## Orden sugerido de corrección
1. C1 + A1 + A2 (adjuntos): un solo cambio en `AdjuntoServicio` y `AdjuntosController`/`TicketsController`.
2. A4 (revocación de sesión) y A3 (comentarios).
3. A5 (encuesta por ciclo): migración nueva en el rango 20-29 y ajuste del reporte de satisfacción.
4. M1, M2, M6, M7 (reglas de visibilidad y flujo), M8 (coordinar con cursor1).
5. M3, M4 antes de producción; M5 con infraestructura.
6. Bajos según disponibilidad.

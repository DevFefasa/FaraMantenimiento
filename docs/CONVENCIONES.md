# Convenciones del proyecto (obligatorias)

Leer completo antes de escribir código. Si algo no está aquí, seguir el estilo de lo ya existente.

## 1. Solución en capas

```
FaraMantenimiento/FaraMantenimiento.sln
├─ FaraMantenimiento/   (Web MVC: Controllers, Views, wwwroot, ViewModels de pantalla)
├─ FM.Programacion/     (lógica de negocio: Servicios)
└─ FM.OrigenDatos/      (conexión BD, llamadas a API externas, Modelos, Repositorios)
```

- Web → Programación → OrigenDatos. **El Web nunca llama a OrigenDatos ni a la BD directo**, solo a servicios de Programación.
  Excepción aceptada: el Web puede usar las clases de `FM.OrigenDatos/Modelos` como DTO de solo lectura (modelos compartidos);
  nunca repositorios, conexión ni `EjecutorSp`.
- Los controladores son delgados: validan entrada, llaman al servicio y devuelven la vista o JSON.
- Reglas de negocio (flujo, SLA, reincidencia, permisos de transición) van en Programación.
- OrigenDatos solo ejecuta SP y mapea resultados; no decide nada.

Carpetas:
- `FM.OrigenDatos/Conexion/` (fábrica de conexión, ejecutor de SP)
- `FM.OrigenDatos/Modelos/<Modulo>/` (clases que mapean columnas de SP)
- `FM.OrigenDatos/Repositorios/` (un repositorio por módulo: `SeguridadRepositorio`, `CatalogoRepositorio`, `TicketRepositorio`, `ReporteRepositorio`, `AdjuntoRepositorio`)
- `FM.OrigenDatos/Api/` (`ActiveDirectoryApi`)
- `FM.Programacion/Servicios/` (`SeguridadServicio`, `CatalogoServicio`, `TicketServicio`, `SlaServicio`, `ReporteServicio`, `ExportacionServicio`, `AdjuntoServicio`)
- `FM.Programacion/Tareas/` (BackgroundService: vencimientos SLA, cierre automático)
- Registro DI: cada capa expone una extensión (`AddOrigenDatos`, `AddProgramacion`); el Web solo llama `AddProgramacion(config)`.

Nombres en español. Propiedades C# en PascalCase **con el prefijo del campo**: columna `fcNombre` → propiedad `FcNombre` (Dapper mapea sin distinguir mayúsculas).

## 2. Base de datos (MariaDB 10.4, base `faramantenimiento`, utf8mb4)

### Nomenclatura de campos
| Prefijo | Tipo | Ejemplo |
|---|---|---|
| `fc` | carácter (VARCHAR/TEXT/CHAR) | `fcNombre` |
| `fi` | entero (INT/BIGINT/TINYINT no booleano) | `fiId`, `fiSucursalId` |
| `fd` | fecha / fecha-hora | `fdCreado` |
| `fb` | booleano (TINYINT(1)) | `fbActivo` |
| `fn` | decimal | `fnCostoManoObra` |
| `fj` | JSON | `fjData` |

- Llave primaria siempre `fiId` (INT AUTO_INCREMENT). Llaves foráneas `fi<Entidad>Id`.
- Tablas en minúscula, singular, sin guiones: `usuario`, `sucursal`, `ticket`, `ticketestado`.
- Auditoría en tablas de negocio: `fdCreado`, `fiCreadoPor`, `fdModificado`, `fiModificadoPor`, `fbActivo`.
- Moneda: **Lempiras (LPS)**, `DECIMAL(14,2)`.

### Procedimientos almacenados (todo el acceso a datos)
- Nombre: `sp_<modulo>_<accion>` → `sp_ticket_crear`, `sp_catalogo_sucursal_listar`, `sp_seguridad_usuario_guardar`.
- Parámetros: `p_` + nombre del campo → `p_fiSucursalId`, `p_fcDescripcion`. Usuario que ejecuta: `p_fiUsuarioId`.
- **Todo SP devuelve como PRIMER result set una fila con exactamente:**

| Columna | Tipo | Significado |
|---|---|---|
| `fiCodigo` | INT | 200 ok, 201 creado, 400 validación, 401/403 sin permiso, 404 no existe, 409 conflicto, 500 error |
| `fcMensaje` | VARCHAR | texto en español para el usuario ("Ticket creado correctamente", "La sucursal no existe") |
| `fbSucces` | TINYINT(1) | 1 si salió bien, 0 si no (se escribe así: `fbSucces`) |
| `fjData` | JSON | ids afectados: `JSON_OBJECT('ticket', 15, 'ticketestado', JSON_ARRAY(33))`; `NULL` o `'{}'` si no aplica |

- Los SP de consulta devuelven después de esa fila los result sets de datos (2.º, 3.º…).
- Escrituras en varias tablas: dentro de transacción, con `DECLARE EXIT HANDLER FOR SQLEXCEPTION` que hace ROLLBACK y devuelve `500` con mensaje genérico (sin detalles técnicos al usuario).
- Validaciones de negocio en el SP devuelven `400`/`404`/`409` con mensaje claro, **no** SIGNAL.

Plantilla:
```sql
DROP PROCEDURE IF EXISTS sp_catalogo_region_guardar;
DELIMITER $$
CREATE PROCEDURE sp_catalogo_region_guardar(IN p_fiId INT, IN p_fcNombre VARCHAR(100), IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar la región' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  START TRANSACTION;
  ...
  COMMIT;
  SELECT 200 AS fiCodigo, 'Región guardada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('region', v_id) AS fjData;
END$$
DELIMITER ;
```

### Migraciones
- Carpeta `db/migrations/NN_nombre.sql` (raíz del repo), **idempotentes**: `CREATE TABLE IF NOT EXISTS`, `DROP PROCEDURE IF EXISTS` + `CREATE`, columnas nuevas con `ADD COLUMN IF NOT EXISTS`, datos iniciales con `INSERT IGNORE` sobre llave única.
- Rangos por responsable (para no chocar):
  - `01–09` seguridad, usuarios, adjuntos (hecho)
  - `10–19` catálogos y tablas de tickets (hecho)
  - `20–29` SP de tickets, flujo, ejecución, encuesta (cursor1)
  - `30–39` SP de SLA, tareas programadas, catálogos CRUD extra (claude2)
  - `40–49` SP de reportes e indicadores (cursor2)
  - `50–54` fase 5: hoja de vida de activo (cursor2)
  - `55–59` fase 5: plan/calendario preventivo (hecho)
  - `60–64` correcciones de seguridad de docs/REVISION.md (claude2)
  - `65–69` correcciones de flujo/SP de docs/REVISION.md (cursor2)
  - `70–74` mejoras catálogos y preventivos (cursor1)
  - `75–79` mejoras seguridad: CRUD roles/pantallas, usuarios, bandeja de correos (cursor2)
  - `80–84` mejoras layout, notificaciones, tickets (claude2)
  - `85–89` módulo de correos: bandeja, envío SMTP (claude2)
- Aplicar local: `docker exec -i MariaLocal sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" faramantenimiento' < db/migrations/NN_x.sql`
- Script `db/aplicar.sh` aplica todas en orden.

## 3. Datos de referencia fijos (códigos)

Códigos de estado (únicas constantes en código, `FM.Programacion/Constantes/EstadosTicket.cs`):
`RECIBIDO, EN_EVALUACION, APROBADO, RECHAZADO, ASIGNADO, EN_PROCESO, EN_ESPERA, RESUELTO, VALIDADO, CERRADO`

Reglas acordadas con el negocio:
- Todo ticket pasa por aprobación de Jefatura **excepto Emergencia**, que al crearse queda directo en `ASIGNADO` pendiente de responsable (campo `fbRequiereAprobacion` en `tipomantenimiento`).
- SLA en **horas corridas**. El tiempo en `EN_ESPERA` **no cuenta** (se acumula en `fiMinutosEnEspera` y se corren los límites).
- Cierre automático: `RESUELTO` sin validar del solicitante pasa a `CERRADO` a los **5 días** (parámetro `DIAS_CIERRE_AUTOMATICO`).
- Reincidencia: mismo activo + misma categoría en los últimos **N días** (parámetro `DIAS_REINCIDENCIA`, 90).
- Materiales: texto, cantidad, costo unitario (sin SAP). Moneda LPS (parámetro `MONEDA`).
- Correos: envío real por SMTP desde la bandeja `correopendiente` (ver sección 6).

Roles (`rol.fcCodigo`): `ADMIN, SOLICITANTE, MANTENIMIENTO, JEFATURA, GERENCIA`.

Pantallas/permisos (`fcPantalla`), usados en el menú y en `[RequierePermiso("...")]`:
`DASHBOARD, TICKET_CREAR, TICKET_MIOS, TICKET_BANDEJA, TICKET_APROBACION, TICKET_TODOS, CATALOGOS, REPORTES, SEGURIDAD`

## 4. Web (frontend)
- Plantilla Spike + identidad FEFASA (`wwwroot/assets/css/fara-identidad.css`). Prefijo de clases propias: `fara-`. **Nada de "fegec"**.
- Logo: `wwwroot/assets/images/FefasaLogo.png`, favicon `FefasaIco.png`.
- **Responsive obligatorio**: probar a 375 px. Tablas con `.table-responsive` o vista de tarjetas en móvil; formularios en una columna en móvil; botones táctiles ≥ 40 px; `<input type="file" accept="image/*,video/*,..." capture>` para fotos en sitio.
- Textos de UI en español. Fechas `dd/MM/yyyy HH:mm`. Moneda `L 1,234.56`.
- Controladores por módulo: `AccountController`, `HomeController`, `SeguridadController` (claude2), `TicketsController` (claude2), `CatalogosController` (cursor1), `ReportesController`/`DashboardController` (cursor2).
- Respuestas AJAX: devolver el mismo objeto estándar `{ fiCodigo, fcMensaje, fbSucces, fjData, datos }` y mostrar con `FaraComun.mostrarMensaje(resp)` (éxito = toast, error = SweetAlert).

### 4.1 Reglas de UI (obligatorias, pedidas por el usuario)
- **Alertas**: nunca `<div class="alert">` fijos para resultados de acciones. Éxito → `FaraComun.toast(true, msg)`; error → `FaraComun.mostrarMensaje(resp)` (SweetAlert). Tras redirect usar solo `TempData["Exito"]` / `TempData["Error"]` (los pinta `_Alertas` como toast/SweetAlert). `.alert` solo para avisos informativos permanentes.
- **Crear/editar: modal en computadora, página en teléfono** (`wwwroot/js/fara-modal.js`, `Helpers/ModalExtensions.cs`):
  - Botón: `<a href="/Modulo/Editar/5" class="btn ..." data-fara-modal data-fara-titulo="Editar X">`. ≥ 992 px abre modal; < 992 px navega a la página.
  - GET: `return Request.EsModal() ? PartialView("_FormularioX", vm) : View(vm);` (la vista completa hace `<partial name="_FormularioX" />`). El parcial contiene un `<form method="post" asp-action="...">` con antiforgery y botón `type="submit"`; el enlace Cancelar lleva `data-fara-cancelar`.
  - POST: `if (Request.EsModal()) return Json(respuestaEstandar);` si no, `TempData["Exito"/"Error"]` + `RedirectToAction`. El JS hace toast y recarga al éxito; en error muestra SweetAlert y deja el modal abierto.
  - Si el parcial necesita JS, escuchar `document.getElementById('faraModal').addEventListener('fara:modal-cargado', ...)`. select2 se inicia solo dentro del modal.
- **Scripts de página**: siempre dentro de `@section Scripts { }` (se cargan después de jQuery/Bootstrap). Nunca `<script>` suelto en el cuerpo que use `bootstrap`, `$` o `Swal`.
- **Tablas**: la columna de acciones es la **primera** columna (`<th class="fara-col-accion">Acciones</th>`). Editar = `btn btn-sm btn-outline-primary`; Desactivar = `btn btn-sm btn-outline-danger` (rojo); Activar = `btn btn-sm btn-outline-success`. Mínimo 40 px de alto.
- **Badges** (estilo transparente, color vivo; definidos en `fara-identidad.css`):
  - Estado activo/inactivo: `<span class="fara-badge fara-badge-activo">Activo</span>` / `<span class="fara-badge fara-badge-inactivo">Inactivo</span>`.
  - Color de catálogo (estados de ticket, prioridades): `<span class="fara-badge" style="--fara-badge-color:@color">@nombre</span>` (fondo del color al 15 %, borde y texto del color).
- **Exportar a Excel**: toda bandeja/listado de tickets tiene botón "Exportar Excel" que respeta los filtros (ClosedXML vía `ExportacionServicio`).
- **Adjuntos**: siempre Dropzone múltiple (`wwwroot/js/dropzone-adjuntos.js`), nunca `<input type=file>` simple.

## 5. Seguridad y configuración
- Sin credenciales en appsettings. Conexión: `ConnectionStrings:FaraMantenimiento` (User Secrets en dev, `ConnectionStrings__FaraMantenimiento` en servidor).
- Login AD vía API interna (`ActiveDirectory:BaseUrl` = `http://192.168.10.65:7026`, `AppName` = `faramantenimiento`), igual que Fleet. Usuarios locales soportados.
- Siempre parámetros en SP (nunca concatenar SQL). Antiforgery en todos los POST.
- Compilar con `dotnet build FaraMantenimiento/FaraMantenimiento.sln` después de cada bloque.

## 6. Correos
- **Nunca se envía directo**: se encola en `correopendiente` y `Tareas/CorreoTarea` lo envía cada `Smtp:SegundosIntervalo` (reintentos con espera creciente hasta `Smtp:FiMaxIntentos`; el error queda en `fcError`).
- Código en `FM.Programacion/Servicios/Correo/`: `SmtpOptions`, `SmtpCorreoSender` (SMTP + logo `cid:fefasaLogo` desde `wwwroot/assets/images/FefasaLogo.png`), `CorreoHtml` (piezas del formato institucional), `PlantillaCorreo` (textos por evento), `CorreoServicio` (encolar y enviar). Datos: `CorreoRepositorio` → SP `sp_correo_*` (migraciones 85-86).
- **Cuerpo siempre cifrado** con Data Protection (propósito `FaraMantenimiento.Correo`): `fcFormato='JSON'` guarda `{html,texto}`; `fcFormato='TEXTO'` (bienvenida de Seguridad) se arma con la plantilla al enviar. No registrar ni imprimir cuerpos ni credenciales.
- **Configuración**: sección `Smtp` de appsettings; `Smtp:Usuario` y `Smtp:Password` solo en User Secrets / variables `Smtp__Usuario`, `Smtp__Password`. `Smtp:UrlBase` = URL pública (botón "Ver ticket"). En Development todo va a `Smtp:CorreoPruebas`; sin él no se envía nada. `Smtp:Habilitado=false` detiene el envío (se sigue encolando).
- **Cómo agregar un correo nuevo**:
  1. Agregar el evento en `EventosCorreo` y su `case` en `PlantillaCorreo.Ticket` (etiqueta, título con `Acento`, intro, asunto y cajas extra), o una plantilla nueva con `CorreoHtml.PlantillaBase`. Siempre con versión de texto plano.
  2. En `CorreoServicio`, un método `EncolarXxxAsync` que elija los grupos de destinatarios (`SOLICITANTE`, `RESPONSABLE`, `JEFATURA`, `MANTENIMIENTO`, que devuelve `sp_correo_ticket_datos`) y llame a `EncolarTicketAsync`, o a `EncolarAsync(para, correo, tipo, ticketId, usuarioId)` para uno suelto.
  3. Llamarlo desde el servicio de Programación **después** del SP exitoso (`if (resp.FbSucces) await _correos.EncolarXxxAsync(...)`). Los `Encolar*` no lanzan excepción: si fallan, registran en el log y la operación sigue.
- Eventos actuales: ticket creado (solicitante + jefatura; emergencia → mantenimiento/ADMIN), asignado (responsable + solicitante), aprobado / rechazado / en espera / resuelto / cerrado (solicitante), alerta SLA (responsable + jefatura; marca `slaalerta.fbCorreoEncolado` para no repetir; `fbNotificado` queda para la campana), cierre automático (solicitante), bienvenida (Seguridad).
- **Servidor**: las claves de Data Protection deben persistir y ser las mismas entre reinicios (perfil de usuario cargado en IIS o `PersistKeysToFileSystem`); si cambian, los correos pendientes no se pueden descifrar.

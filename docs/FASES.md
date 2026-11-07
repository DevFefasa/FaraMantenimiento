# Fara Mantenimiento — Plan por fases

**Fecha:** 2026-11-07
**Proyecto:** plataforma de tickets de mantenimiento para sucursales y áreas de Ferretería FARA.
**Requerimiento completo:** [`REQUERIMIENTO.md`](REQUERIMIENTO.md)

---

## 1. Resumen

Se construye como **aplicación independiente** que parte de la base técnica de Fleet FB Planta (login con Active Directory, seguridad por roles, adjuntos y diseño). Se integra al menú de módulos de Fleet mediante la tabla `modulo` y comparte las cuentas de usuario.

| | |
|---|---|
| Duración estimada total (fases 0–4) | **10 a 13 semanas** |
| Primera versión usable por los gerentes | al terminar la **fase 2** (≈ 6 semanas) |
| Equipo | 1 desarrollador con apoyo de asistentes de IA |

Los tiempos suponen que las preguntas de la sección 6 se responden en la primera semana y que la infraestructura (servidor IIS, base de datos, correo SMTP) está disponible.

### Por qué una aplicación aparte y no dentro de Fleet Planta
- Usuarios distintos: gerentes de todo el país, no solo personal de planta.
- Proceso distinto: mantenimiento de instalaciones (edificios, aire acondicionado, eléctrico…) en lugar de maquinaria de producción; otros estados, otros catálogos y nuevos requisitos (SLA, encuestas, indicadores).
- Publicar o corregir una no detiene a la otra.

---

## 2. Qué se reutiliza de Fleet FB Planta

| Pieza | En Fleet | Uso en Fara Mantenimiento |
|---|---|---|
| Login con Active Directory | `ActiveDirectoryAuthService`, `AccountController` | Igual; los gerentes entran con su usuario de dominio |
| Usuarios, roles y permisos por pantalla | `SecurityRepository`, `AppAccess`, `RequireAppAccessAttribute`, tabla `rolpermisoapp` | Igual, con los 4 roles nuevos |
| Acceso por módulo | tablas `modulo` / `user_modulo` | Nuevo módulo `MANTENIMIENTO` |
| Adjuntos | `AdjuntoService`, `AdjuntosController`, zona de arrastre | Se amplía a **videos y documentos** (PDF, Word, Excel) |
| Bitácora de estados | `solicitudtallerestados` | Mismo patrón para el historial del ticket |
| Diseño, menú, selects con búsqueda | `_Layout`, `_Sidebar`, `selects.js` | Igual, con otra marca |
| Catálogos configurables con caché | `CatalogoService` | Estados, prioridades, tipos y categorías en tablas |

**Lo nuevo:** SLA y su cálculo, correos automáticos, tareas programadas, encuesta de satisfacción, reincidencia, costos, indicadores (MTTR/MTBF), exportación Excel/PDF y tablero.

---

## 3. Fases

### Fase 0 — Base del proyecto · 1 semana
- Proyecto ASP.NET Core 8 MVC + Dapper + MariaDB, copiando de Fleet: login AD, seguridad, adjuntos, diseño.
- Base de datos nueva `faramantenimiento` + scripts de migración (`db/migrations/`).
- Registro del módulo `MANTENIMIENTO` en el menú de Fleet.
- Credenciales fuera del código (User Secrets / variables de entorno).
- Publicación de prueba en el servidor.

**Entregable:** la app abre, los usuarios entran con su cuenta de dominio y ven el menú según su rol.

### Fase 1 — Catálogos y registro de tickets · 2 a 3 semanas
- Catálogos: sucursales/áreas/departamentos (con **región**), ubicaciones dentro de la sucursal, **activos por sucursal**, tipos de mantenimiento (7), categorías/especialidades (12), prioridades (4).
- Roles: Solicitante, Mantenimiento, Jefatura de Proyectos, Gerencia.
- Crear ticket: número y fecha automáticos, datos del solicitante tomados de su usuario (cargo, correo, teléfono), sucursal, ubicación, activo, tipo, categoría, prioridad, descripción y adjuntos (fotos, videos, documentos).
- Flujo de estados completo con historial (fecha, hora y responsable de cada cambio):
  Recibido → En evaluación → Aprobado / Rechazado → Asignado → En proceso → En espera (con motivo: materiales, proveedor, presupuesto, autorización) → Resuelto → Validado → Cerrado.
- Pantallas: Mis tickets (solicitante), bandeja de Mantenimiento, bandeja de aprobación (Jefatura), todos los tickets.

**Entregable:** los gerentes registran tickets y ven su estado; Mantenimiento y Jefatura los mueven por el flujo.

### Fase 2 — Ejecución, cierre y encuesta · 2 semanas
- Asignación a **técnico interno o proveedor externo** (catálogo de proveedores).
- Fechas programada, de inicio y de fin; horas trabajadas.
- Materiales y repuestos usados; costos de mano de obra, materiales y proveedor.
- Diagnóstico, causa raíz y trabajo realizado; fotos **antes / después**.
- Validación del solicitante con **encuesta breve** (calificación + comentario).
- **Reincidencia**: aviso automático si el mismo activo tuvo un ticket de la misma categoría en los últimos N días (N configurable).
- Tipo "Análisis post-falla": campos de causa raíz y acciones preventivas.

**Entregable:** ciclo completo de un ticket, de la solicitud al cierre con conformidad. **Primera versión para salir a producción.**

### Fase 3 — SLA y notificaciones · 2 semanas
- SLA configurable por prioridad: tiempo objetivo de **respuesta** y de **solución**.
- Cálculo de cumplimiento (cumplido / vencido) y semáforo en las bandejas.
- Correos automáticos: al crear, al asignar, al cambiar de estado, al acercarse el vencimiento, al vencer y al cerrar.
- Tarea en segundo plano que revisa vencimientos cada pocos minutos.
- Plantillas de correo editables; registro de correos enviados.
- *(Opcional, según respuesta de la reunión)* segundo canal: Microsoft Teams.

**Entregable:** nadie tiene que revisar la app para enterarse; los SLA se miden solos.

### Fase 4 — Reportes y tablero · 2 a 3 semanas
- Filtros comunes: fecha, sucursal, región, tipo, categoría, prioridad, estado, responsable.
- Indicadores:
  - Recibidos, abiertos, cerrados y pendientes (backlog)
  - Tiempo promedio de respuesta y de solución (MTTR)
  - Cumplimiento de SLA por prioridad
  - Preventivo vs. correctivo
  - Tiempo medio entre fallas (MTBF) por activo o sucursal
  - Tasa de reincidencia
  - Costos por sucursal, categoría y activo
  - Carga y productividad por técnico o proveedor
  - Satisfacción de los solicitantes
- Tablero resumen con gráficos.
- Exportar a **Excel** y **PDF**.

**Entregable:** reportes para definir el alcance del área y medir el desempeño del equipo.

### Fase 5 — Deseables a futuro · a estimar después
| Funcionalidad | Estimado |
|---|---|
| Calendario de mantenimientos preventivos que genera tickets solos (y el indicador "cumplimiento del plan preventivo") | 2 semanas |
| Hoja de vida por activo (historial completo, costos acumulados) | 1 semana |
| Uso desde celular: la app será adaptable desde la fase 1; una app instalable (PWA) con cámara directa | 1 a 2 semanas |

---

## 4. Cronograma

| Semana | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F0 Base | ■ | | | | | | | | | | | | |
| F1 Catálogos y tickets | | ■ | ■ | ■ | | | | | | | | | |
| F2 Ejecución y cierre | | | | | ■ | ■ | | | | | | | |
| *Salida a producción* | | | | | | ★ | | | | | | | |
| F3 SLA y correos | | | | | | | ■ | ■ | | | | | |
| F4 Reportes | | | | | | | | | ■ | ■ | ■ | | |
| Pruebas y ajustes | | | | | | | | | | | | ■ | ■ |

Las semanas 12–13 son margen para pruebas con usuarios y cambios que surjan.

---

## 5. Riesgos

| Riesgo | Efecto | Cómo se mitiga |
|---|---|---|
| No existe un catálogo de activos por sucursal | La fase 1 se alarga o el campo queda opcional | Empezar con activo opcional y cargarlos por Excel cuando estén |
| Gerentes sin usuario de dominio | No pueden entrar | Usuarios locales (ya soportado en la base) o crear cuentas en AD |
| Definición de SLA tardía | Fase 3 no puede cerrarse | Valores iniciales propuestos, editables después |
| Videos pesados | Llenan el disco del servidor | Límite de tamaño y carpeta en disco separado |
| Licencia de la librería PDF | Costo no previsto | Evaluar alternativas sin licencia comercial |

---

## 6. Preguntas para la reunión

**Alcance y usuarios**
1. ¿Cuántos gerentes/usuarios y cuántas sucursales aproximadamente?
2. ¿Todos los gerentes tienen usuario de dominio (Active Directory)?
3. ¿Existe ya un listado de sucursales, áreas, departamentos y regiones? ¿Se toma de SAP o se carga a mano?
4. ¿Existe inventario de activos por sucursal? ¿Están en SAP (activos fijos) o en Excel?

**Flujo**
5. ¿Todos los tickets pasan por aprobación de Jefatura, o solo algunos (por tipo, costo o prioridad)? ¿Emergencias se saltan la aprobación?
6. Si el solicitante no valida un ticket resuelto, ¿se cierra solo después de X días?
7. ¿Quién puede cambiar la prioridad que puso el solicitante?

**SLA**
8. Tiempos de respuesta y solución por prioridad (Crítica, Alta, Media, Baja).
9. ¿El SLA cuenta horas hábiles (qué horario y feriados) o horas corridas?
10. ¿El tiempo "En espera" (materiales, proveedor, presupuesto) detiene el reloj del SLA?

**Ejecución y costos**
11. ¿Los materiales salen de inventario en SAP (como en Fleet, con salida de mercancía) o solo se registran como texto y costo?
12. ¿Los proveedores externos se toman del catálogo de SAP?
13. ¿Moneda de los costos? ¿Se registra la factura del proveedor?

**Notificaciones y reportes**
14. ¿Servidor de correo (SMTP / Office 365) y cuenta remitente?
15. ¿Segundo canal deseado: Teams, WhatsApp?
16. ¿Qué reportes se necesitan primero, para priorizar la fase 4?

---

## 7. Siguiente paso

Revisar este plan en la reunión, responder la sección 6 y confirmar las prioridades. Con eso se ajustan tiempos y se inicia la fase 0.

# Requerimiento original — Plataforma de tickets de mantenimiento

**Origen:** correo del área de Proyectos (recibido 2026-11-06).
**Objetivo:** que todas las solicitudes de mantenimiento de las sucursales y áreas de Ferretería FARA a nivel nacional se canalicen por un solo medio, se les dé seguimiento hasta su cierre y la plataforma genere reportes para definir el alcance del área y medir el desempeño del equipo de mantenimiento.

Se pide acondicionar la herramienta existente (Fleet FB Planta) como base.

---

## Datos generales del ticket
- Número de ticket (automático)
- Fecha y hora de ingreso (automática)
- Solicitante, cargo, correo y teléfono
- Sucursal / área / departamento (catálogo nacional)
- Ubicación específica dentro de la sucursal
- Activo o equipo afectado (idealmente con un catálogo de activos por sucursal)
- Descripción de la necesidad
- Adjuntos: fotografías, videos o documentos

## Tipo de mantenimiento
- Correctivo (falla o daño existente)
- Preventivo (rutinario, según calendario)
- Predictivo (basado en inspección o condición del equipo)
- Programado / planificado con anticipación (con fecha sugerida)
- Emergencia (riesgo a personas, operación o inventario)
- Mejora o adecuación (cambios, remodelaciones menores)
- Análisis post-falla (post-mortem): causa raíz y acciones para evitar recurrencia

## Categoría / especialidad
Eléctrico; plomería e hidrosanitario; aire acondicionado y ventilación; obra civil e infraestructura (techos, pisos, paredes, pintura); estructuras y estanterías; puertas, cortinas y portones; montacargas y equipo de carga; plantas eléctricas; sistemas de seguridad (cámaras, alarmas, extintores); iluminación; señalización; otros.

## Prioridad e impacto
- **Crítica:** detiene la operación o representa riesgo de seguridad
- **Alta:** afecta parcialmente la operación
- **Media:** puede esperar algunos días
- **Baja:** puede programarse

Cada nivel con tiempo objetivo de respuesta y de solución (SLA) configurable; la plataforma indica si se cumplió o no.

## Flujo y estados
Recibido → En evaluación → Aprobado / Rechazado → Asignado → En proceso → En espera (materiales, proveedor, presupuesto o autorización) → Resuelto → Validado por el solicitante → Cerrado.

Registro automático de fecha, hora y responsable de cada cambio de estado.

## Ejecución y cierre
- Responsable asignado (personal interno o proveedor externo)
- Fecha programada, de inicio y de finalización
- Horas de trabajo invertidas
- Materiales y repuestos utilizados
- Costo de mano de obra, materiales y proveedor
- Diagnóstico y causa raíz de la falla
- Trabajo realizado y fotos de antes/después
- Conformidad del solicitante y calificación del servicio (encuesta breve)
- Marca de reincidencia (si la falla ya había ocurrido en ese activo)

## Roles y permisos
- **Solicitante (gerentes):** crear tickets y consultar el estado de los suyos
- **Mantenimiento:** evaluar, asignar, actualizar y cerrar
- **Jefatura de Proyectos:** aprobar, priorizar y ver todo
- **Gerencia / Dirección:** consulta de reportes

## Notificaciones
Correo (y de ser posible otro canal) al crear el ticket, al asignarlo, al cambiar de estado, al acercarse o vencer el SLA y al cerrarse.

## Reportes e indicadores
Filtros por fecha, sucursal, región, tipo, categoría, prioridad, estado y responsable; exportar a Excel/PDF.
- Tickets recibidos, abiertos, cerrados y pendientes (backlog)
- Tiempo promedio de respuesta y de solución (MTTR)
- Cumplimiento de SLA por prioridad
- Proporción preventivo vs. correctivo
- Cumplimiento del plan de mantenimiento preventivo
- Tiempo medio entre fallas (MTBF) por activo o sucursal
- Tasa de reincidencia
- Costos por sucursal, categoría y activo
- Carga de trabajo y productividad por técnico o proveedor
- Satisfacción de los solicitantes
- Tablero (dashboard) resumen

## Deseable a futuro
- Calendario de mantenimientos preventivos que genere tickets automáticamente
- Historial completo por activo (hoja de vida del equipo)
- Acceso desde celular para registrar solicitudes y fotos en sitio

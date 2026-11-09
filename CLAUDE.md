# Fara Mantenimiento

Plataforma de tickets de mantenimiento para sucursales de Ferretería FARA.
ASP.NET Core 8 MVC + Dapper + MariaDB. Sin EF: esquema en db/ y migraciones en db/migrations/.
BD local: contenedor Docker "MariaLocal" puerto 3306, base `faramantenimiento`.

## Documentos de referencia (leer en vez de explorar)
- docs/REQUERIMIENTO.md: lo que pidió el negocio.
- docs/FASES.md: plan por fases, qué se reutiliza y preguntas abiertas.

## Base técnica
Se copia de Fleet FB Planta (`../FleetFbPlanta/FleetFBPlanta/FleetFBPlanta/`), no se referencia:
login AD (`Services/ActiveDirectoryAuthService.cs`, `Controllers/AccountController.cs`), seguridad
(`Data/SecurityRepository.cs`, `Helpers/AppAccess.cs`, `RequireAppAccessAttribute.cs`, `PermisosClaimsTransformation.cs`),
módulos (`Data/ModuloRepository.cs`), adjuntos (`Services/AdjuntoService.cs`), catálogos con caché (`Data/CatalogoService.cs`),
diseño (`Views/Shared/_Layout`, `_Sidebar`, `wwwroot/js/selects.js`, `dropzone-adjuntos.*`).
Al copiar, quitar todo lo de SAP/maquinaria que no aplique.

## Reglas
- **Leer docs/CONVENCIONES.md antes de programar**: solución en 3 capas (Web → FM.Programacion → FM.OrigenDatos),
  campos fc/fi/fd/fb/fn/fj, todo por procedimientos almacenados con respuesta estándar fiCodigo/fcMensaje/fbSucces/fjData.
- Textos de UI en español.
- Cada cambio de BD va en un script nuevo en db/migrations/NN_nombre.sql, idempotente.
- Datos de negocio (estados, prioridades, SLA, tipos, categorías) en tablas, no en el código; solo los códigos de estado del flujo son constantes.
- No mostrar contraseñas. appsettings.json NO lleva credenciales: van en User Secrets (desarrollo) o variables de entorno (servidor).
- Compilar con `dotnet build` después de cada bloque.

## Coordinación multi-agente (herdr)
Eres el coordinador. No implementes tú las tareas grandes.
- Divide el trabajo en tareas independientes.
- Usa la skill de herdr para enviar cada tarea a los agentes en los otros paneles
  (claude2, cursor) y espera a que terminen.
- Revisa lo que hicieron y dame un resumen.
- Asigna a cada agente archivos o módulos distintos para que no se pisen.
- Después de enviar una tarea a otro agente, lee su panel con herdr.
- Si ves "hit your session limit" o "hit your weekly limit", ese agente
  ya no puede trabajar hasta la hora indicada.
- En ese caso, reasigna la tarea a otro agente disponible (claude2, cursor1,
  cursor2) y avísame qué agente quedó sin límite y a qué hora se reinicia.

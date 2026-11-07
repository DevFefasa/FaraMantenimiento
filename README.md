# Fara Mantenimiento

Plataforma de gestión de **tickets de mantenimiento** para las sucursales y áreas de Ferretería FARA a nivel nacional: registro de solicitudes, seguimiento hasta el cierre, SLA, notificaciones y reportes de desempeño del equipo de mantenimiento.

**Estado:** planificación.

## Documentos
- [Requerimiento original](docs/REQUERIMIENTO.md)
- [Plan por fases](docs/FASES.md)

## Stack (previsto)
- ASP.NET Core 8 MVC + Razor
- Dapper + MariaDB/MySQL
- Login con Active Directory (API interna), igual que Fleet FB Planta
- Base técnica tomada de [Fleet FB Planta](../FleetFbPlanta): seguridad, adjuntos y diseño

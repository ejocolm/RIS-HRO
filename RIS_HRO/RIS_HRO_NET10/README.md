# RIS_HRO — Sistema de Citas de Radiología

Proyecto web ASP.NET Core / Razor Pages para gestión y control de citas del Departamento de Radiología del Hospital Regional de Occidente.

## Inicio rápido

1. Abra SQL Server Management Studio.
2. Ejecute `SQL/00_FULL_SETUP_DEV.sql`.
3. Ejecute `SQL/01_CHECK_INSTALLATION.sql`.
4. Ajuste `ConnectionStrings:DefaultConnection` en `appsettings.Development.json`.
5. Abra `RIS_HRO.sln` con Visual Studio Community 2026.
6. Restaure paquetes NuGet.
7. Compile y ejecute con F5.
8. Inicie sesión con:
   - `ADMIN01 / Admin123*`
   - `CITAS01 / Citas123*`

## Guía completa

Consulte:

`Docs/GUIA_COMPLETA.md`

## Checklist

Consulte:

`Docs/CHECKLIST_PRUEBAS.md`

## Regla central de capacidad

Cada registro de `DETALLE_CITA` consume un cupo de la prueba (`IdPrueba`) correspondiente. La categoría únicamente clasifica los estudios.

## Integración institucional

El flujo WebService/HL7 está preparado, pero la conexión definitiva queda deshabilitada hasta disponer del contrato técnico real del Hospital Regional de Occidente.

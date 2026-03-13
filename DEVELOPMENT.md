# 🛠️ Guía de Desarrollo - RentInLondon PRO

Este documento describe el flujo de trabajo técnico, las herramientas disponibles y la arquitectura de datos del sistema.

## 🏗️ Arquitectura de Datos (Supabase)

La base de datos centralizada en Supabase es la **única fuente de verdad**. Los archivos JSON locales en `openclaw/services/` están deprecados.

### Herramientas de Base de Datos
- **`read_db`**: Solo para consultas `SELECT`. Usa filtros para optimizar.
- **`execute_db_rpc`**: Para cualquier operación de **escritura** o lógica compleja. 
  - *Ejemplo*: `fn_archive_lead`, `fn_create_booking`, `fn_record_score_change`.
- **Procedimiento de Escritura**: No edites las tablas directamente desde el bot. Usa siempre las funciones RPC definidas en `supabase/migrations/` para asegurar que los triggers y el historial se disparen correctamente.

## 💬 Mensajería e Interacciones
- **Registro**: Todas las interacciones de WhatsApp/Telegram deben registrarse en la tabla `interactions`.
- **Mensajes Internos**: Usa `POST /interactions` con el flag `is_internal: true` para notas entre agentes o recordatorios del sistema.

## 🤖 Agentes y Roles
- **Alex**: Coordinador central. Único con permisos de escritura en `shared/MEMORY.md`.
- **Ivy/Rose/Salo**: Especialistas en ventas (Marketplaces/Ads).
- **Jeanette**: Especialista Internacional y casos complejos (DSS, escalaciones).

## 🚀 Despliegue y Mantenimiento
1. **Migraciones**: Los cambios de esquema deben ir en `supabase/migrations/`.
2. **Sincronización**: Usa `rsync` para subir cambios al servidor y reinicia con `pm2 restart openclaw`.
3. **Logs**: Revisa `pm2 logs openclaw` para depuración en tiempo real.

## 🧪 Pruebas
Se recomiendan pruebas de integración manuales tras cambios en triggers:
1. Crea un booking y verifica que el estado del lead cambie a `viewing_programado`.
2. Cambia el score de un lead y verifica que se cree una entrada en `lead_score_history`.

---
*Referencia de Base de Datos: [openclaw/services/README_DATABASE.md](file:///Users/wilfredy/Ivylettings/rentinlondon-pro/openclaw/services/README_DATABASE.md)*

# Plan Operativo — RentInLondon PRO

## Fase de Implementación Actual

### Semana 1-2: Infraestructura
- [ ] Servidor Ubuntu 22.04 configurado (setup/01-server-setup.sh)
- [ ] Supabase proyecto creado y migrado
- [ ] Variables de entorno configuradas
- [ ] OpenClaw gateway instalado

### Semana 2-3: Agentes
- [ ] Alex activo y recibiendo reportes por Telegram
- [ ] Ivy, Rose, Salo activos en WhatsApp
- [ ] Jeanette activa para leads internacionales
- [ ] ads-fb y ads-gumtree conectados a sus plataformas
- [ ] script-runner ejecutando tareas programadas

### Semana 3-4: Pipelines y optimización
- [ ] 6 pipelines activos y verificados
- [ ] Google Sheets sincronizando automáticamente
- [ ] Primer reporte semanal generado por Alex
- [ ] Sistema de reactivación probado y aprobado

## Propiedades a Gestionar

Agregar propiedades disponibles en `properties` de Supabase:
- Dirección completa
- Zona de Londres
- Tipo (room/studio/1bed/2bed/etc.)
- Precio mensual
- Fecha de disponibilidad
- Fotos (URLs)
- Amenidades

## Campañas de Ads a Configurar

### Facebook/Instagram
- Campaña de awareness: zonas premium (Shoreditch, Clapham, Islington)
- Campaña de leads: formulario directo con preguntas clave
- Remarketing: visitantes del sitio web

### Gumtree/Marketplaces
- Listing activo por cada propiedad disponible
- Refresh bisemanal (automatizado con listings-refresh pipeline)
- Featured listings para propiedades de alta demanda

## Contactos del Sistema

| Rol | Contacto | Canal |
|-----|----------|-------|
| Dueño de la agencia | [CONFIGURAR] | Telegram |
| Soporte técnico | [CONFIGURAR] | Email |
| Proveedor WhatsApp API | Meta Business | Dashboard |
| Supabase | support@supabase.io | Email |

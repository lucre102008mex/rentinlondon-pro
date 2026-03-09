# Pipeline: Listings Refresh
# Ejecuta lunes y jueves a las 11:00 AM Europe/London
# ads-gumtree actualiza todos los anuncios activos en marketplaces

name: listings-refresh
description: "Actualización bisemanal de listados en Gumtree y marketplaces"
timezone: Europe/London
schedule: "0 11 * * 1,4"

steps:
  - id: query_active_properties
    name: "Obtener propiedades disponibles actualmente"
    agent: ads-gumtree
    action: supabase_query
    params:
      table: properties
      filter: "estado.in.(available,void)"
      select: "id,direccion,zona,tipo,precio_mensual,disponible_desde,descripcion,fotos_urls,amenities,bills_incluidos,deposito_semanas,min_contrato_meses"

  - id: query_active_listings
    name: "Obtener listados activos en plataformas"
    agent: ads-gumtree
    action: supabase_query
    params:
      table: listings_history
      filter: "estado.eq.activo"
      select: "id,property_id,plataforma,listing_id_ext,url,vistas,mensajes,precio_listado,fecha_inicio,metadata"

  - id: query_let_properties
    name: "Obtener propiedades recién alquiladas"
    agent: ads-gumtree
    action: supabase_query
    params:
      table: properties
      filter: "estado.eq.let"
      select: "id"

  - id: pause_let_listings
    name: "Pausar listados de propiedades ya alquiladas"
    agent: ads-gumtree
    action: pause_listings_batch
    depends_on:
      - query_let_properties
      - query_active_listings
    params:
      source: "cross_reference"
      note: "Pausar en plataforma + UPDATE listings_history.estado = 'expirado'"

  - id: refresh_existing_listings
    name: "Renovar listados activos (subir a top de búsqueda)"
    agent: ads-gumtree
    action: refresh_listings_batch
    depends_on:
      - query_active_listings
      - pause_let_listings
    params:
      platforms:
        gumtree:
          action: repost
          method: "refresh_api"
        spareroom:
          action: bump
          method: "bump_api"
        openrent:
          action: refresh
          method: "refresh_api"
      update_after_refresh:
        table: listings_history
        set:
          metadata->last_refresh: "${now}"
          metadata->refresh_count: "increment"

  - id: create_missing_listings
    name: "Crear listados para propiedades sin anuncio activo"
    agent: ads-gumtree
    action: create_listings_for_unisted
    depends_on:
      - query_active_properties
      - query_active_listings
    params:
      find_unlisted_properties: true
      platforms:
        - gumtree
        - spareroom
        - openrent
      listing_template:
        include_photos: true
        include_amenities: true
        include_transport: true
        language: "en"
        compliance_check: true

  - id: check_price_vs_market
    name: "Verificar precios vs. zone_ranges del mercado"
    agent: ads-gumtree
    action: supabase_query
    depends_on:
      - query_active_properties
    params:
      query: |
        SELECT 
          p.id,
          p.zona,
          p.tipo,
          p.precio_mensual,
          zr.room_min,
          zr.room_max,
          zr.studio_min,
          zr.studio_max,
          zr.bed1_min,
          zr.bed1_max
        FROM properties p
        LEFT JOIN zone_ranges zr ON lower(zr.zona) = lower(p.zona)
        WHERE p.estado IN ('available', 'void')

  - id: report_price_alerts
    name: "Reportar propiedades con precio fuera de mercado"
    agent: ads-gumtree
    action: check_price_competitiveness
    depends_on:
      - check_price_vs_market
    params:
      tolerance_percent: 15
      report_to: agent_logs

  - id: update_views_messages
    name: "Actualizar estadísticas de vistas y mensajes de plataformas"
    agent: ads-gumtree
    action: sync_platform_stats
    depends_on:
      - refresh_existing_listings
    params:
      stats:
        - metric: views
          field: vistas
        - metric: messages
          field: mensajes

  - id: generate_refresh_report
    name: "Generar reporte del refresh"
    agent: ads-gumtree
    action: generate_refresh_report
    depends_on:
      - refresh_existing_listings
      - create_missing_listings
      - report_price_alerts
    params:
      include: listing_count, refreshed_count, created_count, paused_count, price_alerts

  - id: log_to_alex
    name: "Enviar resumen del refresh a Alex para reporte diario"
    agent: ads-gumtree
    action: supabase_insert
    depends_on:
      - generate_refresh_report
    params:
      table: agent_logs
      data:
        agente: "ads-gumtree"
        accion: "listings_refresh_completed"
        exito: true
        metadata:
          listings_refreshed: "${refresh_existing_listings.count}"
          listings_created: "${create_missing_listings.count}"
          listings_paused: "${pause_let_listings.count}"
          price_alerts: "${report_price_alerts.count}"

  - id: notify_owner_if_alerts
    name: "Alertar al dueño si hay propiedades con precio fuera de mercado"
    agent: ads-gumtree
    action: conditional_internal_notify
    depends_on:
      - report_price_alerts
    params:
      condition: "${report_price_alerts.count} > 0"
      target_agent: alex
      event: listings.price_alert
      payload:
        count: "${report_price_alerts.count}"
        properties: "${report_price_alerts.details}"

on_error:
  - action: log_action
    params:
      agente: "ads-gumtree"
      accion: "listings_refresh_error"
      exito: false
      error_msg: "${error.message}"
  - action: internal_notify
    params:
      target_agent: alex
      event: pipeline.error
      payload:
        pipeline: listings-refresh
        error: "${error.message}"

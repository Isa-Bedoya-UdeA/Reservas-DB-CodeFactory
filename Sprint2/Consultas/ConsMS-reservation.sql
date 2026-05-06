MS-RESERVATION-SERVICE
--Tablas: reserva
--Q1. Crear Reserva (INSERT)
--El cliente solicita una cita. Antes de insertar, el servicio debe: 1) validar que el servicio existe (MS-CATALOG), 2) confirmar disponibilidad del empleado (MS-SCHEDULE), y 3) verificar que no hay conflicto de horario con la función del DDL.
SQL:
-- PASO 1: Verificar conflicto de horario (retorna TRUE si hay conflicto)
SELECT validar_conflicto_horario(
    'uuid-del-empleado',
    '2026-06-15 10:00:00+00',   -- fecha_hora_inicio
    '2026-06-15 11:00:00+00'    -- fecha_hora_fin
);
-- Si retorna TRUE → rechazar la solicitud
 
-- PASO 2: Si no hay conflicto → insertar la reserva
INSERT INTO reserva (
    id_cliente,
    id_servicio,
    id_empleado,
    id_proveedor,
    fecha_hora_inicio,
    fecha_hora_fin,
    estado,
    comentarios
) VALUES (
    'uuid-del-cliente',
    'uuid-del-servicio',
    'uuid-del-empleado',
    'uuid-del-proveedor',
    '2026-06-15 10:00:00+00',
    '2026-06-15 11:00:00+00',
    'PENDIENTE',
    'Por favor llegar 5 minutos antes'
)
RETURNING id_reserva, estado, fecha_hora_inicio, fecha_creacion;

--Q2. Confirmar Reserva — Cambio de Estado (UPDATE)
--El proveedor o el sistema confirma una reserva pendiente. El estado transiciona de PENDIENTE → CONFIRMADA.
SQL:
UPDATE reserva
SET estado = 'CONFIRMADA'
WHERE id_reserva  = 'uuid-de-la-reserva'
  AND id_proveedor = 'uuid-del-proveedor'
  AND estado       = 'PENDIENTE'        -- solo se puede confirmar si está pendiente
RETURNING id_reserva, estado, updated_at;
 
-- Flujo completo de estados válidos:
-- PENDIENTE → CONFIRMADA → EN_PROGRESO → COMPLETADA
--                        ↘ CANCELADA
--                                      ↘ NO_SHOW

--Q3. Cancelar Reserva (UPDATE)
--El cliente o el proveedor cancela una reserva. El trigger actualizar_fecha_cancelacion registra automáticamente la fecha. También libera el bloqueo en MS-SCHEDULE.
SQL:
-- Opción A: UPDATE directo con comentario de cancelación
UPDATE reserva
SET
    estado      = 'CANCELADA',
    comentarios = COALESCE(comentarios || ' | ', '') || 'Cancelada por el cliente: cambio de plans'
WHERE id_reserva = 'uuid-de-la-reserva'
  AND id_cliente = 'uuid-del-cliente'   -- solo el dueño puede cancelar la suya
  AND estado NOT IN ('CANCELADA', 'COMPLETADA', 'NO_SHOW')
RETURNING id_reserva, estado, fecha_cancelacion, updated_at;
 
-- Opción B: Usando la función del DDL
SELECT cancelar_reserva(
    'uuid-de-la-reserva',
    'Cancelada por el cliente: cambio de planes'
);

--Q4. Historial de Reservas de un Cliente (SELECT)
--Devuelve todas las reservas de un cliente ordenadas por fecha descendente. Soporta filtro opcional por estado.
SQL:
-- Todas las reservas del cliente
SELECT
    r.id_reserva,
    r.id_servicio,
    r.id_proveedor,
    r.fecha_hora_inicio,
    r.fecha_hora_fin,
    r.estado,
    r.comentarios,
    r.fecha_creacion,
    r.fecha_cancelacion,
    EXTRACT(EPOCH FROM (r.fecha_hora_fin - r.fecha_hora_inicio)) / 60
        AS duracion_minutos
FROM reserva r
WHERE r.id_cliente = 'uuid-del-cliente'
ORDER BY r.fecha_hora_inicio DESC;
 
-- Filtrar solo las COMPLETADAS (historial de servicios tomados)
SELECT * FROM obtener_reservas_por_cliente('uuid-del-cliente', 'COMPLETADA');
 
-- Filtrar activas (PENDIENTE, CONFIRMADA)
SELECT * FROM vista_reservas_activas
WHERE id_cliente = 'uuid-del-cliente';

--Q5. Agenda de Reservas de un Empleado por Rango de Fechas (SELECT)
--Retorna todas las reservas asignadas a un empleado en un período. Útil para el proveedor al planificar la semana.
SQL:
-- Usando la función del DDL
SELECT
    r.id_reserva,
    r.id_cliente,
    r.id_servicio,
    r.fecha_hora_inicio,
    r.fecha_hora_fin,
    r.estado
FROM obtener_reservas_por_empleado(
    'uuid-del-empleado',
    '2026-06-09 00:00:00+00',   -- inicio semana
    '2026-06-15 23:59:59+00'    -- fin semana
) r;
 
-- Reservas de hoy del empleado
SELECT * FROM vista_reservas_dia_actual_por_empleado
WHERE id_empleado = 'uuid-del-empleado';
 
-- Próximas 24 horas (todas, sin filtro de empleado)
SELECT * FROM vista_reservas_proximas;

--Q6. Estadísticas de Reservas por Proveedor (Reporte)
--Reporte gerencial del proveedor: totales por estado y tasa de cancelación para un período dado. Esencial para el dashboard de administración.
SQL:
-- Usando la función del DDL con rango de fechas
SELECT
    total_reservas,
    reservas_pendientes,
    reservas_confirmadas,
    reservas_completadas,
    reservas_canceladas,
    tasa_cancelacion   AS tasa_cancelacion_pct
FROM obtener_estadisticas_reservas_proveedor(
    'uuid-del-proveedor',
    '2026-01-01 00:00:00+00',
    '2026-06-30 23:59:59+00'
);
 
-- Vista global por proveedor (sin filtro de fechas, solo ADMIN)
SELECT
    id_proveedor,
    total_reservas,
    reservas_completadas,
    reservas_canceladas,
    reservas_no_show,
    ROUND(
        reservas_canceladas * 100.0 / NULLIF(total_reservas, 0), 2
    ) AS tasa_cancelacion_pct,
    ROUND(duracion_promedio_minutos, 0) AS duracion_promedio_min
FROM vista_estadisticas_reservas_proveedor
ORDER BY total_reservas DESC;

--Q7. Validar Conflicto de Horario antes de Reagendar (SELECT)
--Antes de cambiar la fecha/hora de una reserva existente, se verifica que el nuevo tramo no colisione con otras reservas del empleado, excluyendo la reserva actual.
SQL:
-- Verificar si hay conflicto para el nuevo horario
-- (excluyendo la propia reserva que se va a reagendar)
SELECT validar_conflicto_horario(
    'uuid-del-empleado',
    '2026-06-20 14:00:00+00',   -- nuevo inicio
    '2026-06-20 15:00:00+00',   -- nuevo fin
    'uuid-de-la-reserva'        -- excluir esta reserva del chequeo
);
-- FALSE = sin conflicto → se puede reagendar
-- TRUE  = hay conflicto → proponer otro horario
 
-- Si no hay conflicto, actualizar la reserva
UPDATE reserva
SET
    fecha_hora_inicio = '2026-06-20 14:00:00+00',
    fecha_hora_fin    = '2026-06-20 15:00:00+00',
    estado            = 'PENDIENTE'
WHERE id_reserva = 'uuid-de-la-reserva'
  AND estado NOT IN ('COMPLETADA', 'CANCELADA', 'NO_SHOW')
RETURNING id_reserva, fecha_hora_inicio, fecha_hora_fin, estado;

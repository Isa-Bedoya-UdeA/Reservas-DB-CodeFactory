MS-SCHEDULE-SERVICE
--Tablas: empleado, empleado_servicio, horario_laboral, bloqueo_horario
--Q1. Crear Empleado (INSERT)
--El proveedor registra un nuevo empleado. El id_proveedor es FK lógica hacia MS-AUTH y debe validarse vía Feign Client antes del INSERT.
SQL:
INSERT INTO empleado (
    id_proveedor,
    nombre_completo,
    telefono,
    activo,
    fecha_contratacion,
    notas
) VALUES (
    'uuid-del-proveedor',
    'Carlos Andrés Ramírez',
    '+57 310 456 7890',
    TRUE,
    '2024-03-01 00:00:00+00',
    'Especialista en masajes terapéuticos y técnicas orientales'
)
RETURNING id_empleado, nombre_completo, activo, created_at;

--Q2. Listar Empleados Activos de un Proveedor (SELECT)
--Retorna todos los empleados activos de un proveedor con el conteo de servicios asignados y horarios configurados.
SQL:
-- Opción A: Query directo con agregaciones
SELECT
    e.id_empleado,
    e.nombre_completo,
    e.telefono,
    e.fecha_contratacion,
    COUNT(DISTINCT es.id_servicio)  AS servicios_asignados,
    COUNT(DISTINCT hl.id_horario)   AS dias_horario_configurados
FROM empleado e
LEFT JOIN empleado_servicio es
    ON e.id_empleado = es.id_empleado AND es.activo = TRUE
LEFT JOIN horario_laboral hl
    ON e.id_empleado = hl.id_empleado AND hl.activo = TRUE
WHERE e.id_proveedor = 'uuid-del-proveedor'
  AND e.activo = TRUE
GROUP BY e.id_empleado, e.nombre_completo, e.telefono, e.fecha_contratacion
ORDER BY e.nombre_completo ASC;
 
-- Opción B: Usando la función del DDL
SELECT * FROM obtener_empleados_por_proveedor('uuid-del-proveedor', TRUE);

--Q3. Actualizar Empleado (UPDATE)
--Permite modificar los datos de contacto y notas de un empleado. El trigger updated_at se dispara automáticamente.
SQL:
UPDATE empleado
SET
    nombre_completo     = 'Carlos Andrés Ramírez López',
    telefono            = '+57 310 999 1111',
    notas               = 'Especialista en masajes terapéuticos, aromaterapia y reflexología'
WHERE id_empleado  = 'uuid-del-empleado'
  AND id_proveedor = 'uuid-del-proveedor'   -- solo el dueño puede modificar
RETURNING id_empleado, nombre_completo, telefono, updated_at;

--Q4. Desactivar / Reactivar Empleado (Soft Delete)
--Marca el empleado como inactivo sin eliminarlo físicamente. Sus horarios y bloqueos asociados quedan intactos.
SQL:
-- Desactivar
UPDATE empleado
SET activo = FALSE
WHERE id_empleado  = 'uuid-del-empleado'
  AND id_proveedor = 'uuid-del-proveedor'
RETURNING id_empleado, nombre_completo, activo;
 
-- Usando la función del DDL:
SELECT desactivar_empleado('uuid-del-empleado');
 
-- Reactivar:
SELECT activar_empleado('uuid-del-empleado');

--Q5. Asignar Servicio a Empleado (INSERT empleado_servicio)
--Relaciona un empleado con un servicio del catálogo. El id_servicio es FK lógica a MS-CATALOG validada vía Feign.
SQL:
-- Opción A: INSERT directo
INSERT INTO empleado_servicio (
    id_empleado,
    id_servicio,
    activo,
    fecha_asignacion
) VALUES (
    'uuid-del-empleado',
    'uuid-del-servicio',
    TRUE,
    CURRENT_TIMESTAMP
)
RETURNING id_empleado_servicio, id_empleado, id_servicio, fecha_asignacion;
 
-- Opción B: Usando la función del DDL
SELECT asignar_servicio_a_empleado('uuid-del-empleado', 'uuid-del-servicio');
 
-- Remover asignación (soft delete):
SELECT remover_servicio_de_empleado('uuid-del-empleado', 'uuid-del-servicio');

--Q6. Configurar Horario Laboral Semanal (INSERT horario_laboral)
--Define los bloques de trabajo recurrentes de un empleado por día de la semana. Se puede insertar un registro por cada día.
SQL:
-- Configurar horario de lunes a viernes 8am-6pm y sábados 9am-2pm
INSERT INTO horario_laboral (id_empleado, dia_semana, hora_inicio, hora_fin, activo)
VALUES
    ('uuid-del-empleado', 'LUNES',     '08:00', '18:00', TRUE),
    ('uuid-del-empleado', 'MARTES',    '08:00', '18:00', TRUE),
    ('uuid-del-empleado', 'MIERCOLES', '08:00', '18:00', TRUE),
    ('uuid-del-empleado', 'JUEVES',    '08:00', '18:00', TRUE),
    ('uuid-del-empleado', 'VIERNES',   '08:00', '18:00', TRUE),
    ('uuid-del-empleado', 'SABADO',    '09:00', '14:00', TRUE);
 
-- Consultar horario configurado:
SELECT * FROM obtener_horario_laboral_por_empleado('uuid-del-empleado');
 
-- Desactivar un día (empleado no trabaja ese día):
UPDATE horario_laboral
SET activo = FALSE
WHERE id_empleado = 'uuid-del-empleado'
  AND dia_semana  = 'SABADO'
RETURNING id_horario, dia_semana, activo;

--Q7. Crear Bloqueo de Horario (INSERT bloqueo_horario)
--Bloquea un tramo de tiempo específico para un empleado. Las reservas generan bloqueos de tipo RESERVA; los administrativos (vacaciones, permisos) se gestionan directamente.
SQL:
-- Bloqueo por RESERVA (lo crea MS-RESERVATION al confirmar una cita)
INSERT INTO bloqueo_horario (
    id_empleado,
    id_reserva,
    fecha,
    hora_inicio,
    hora_fin,
    tipo_bloqueo,
    activo
) VALUES (
    'uuid-del-empleado',
    'uuid-de-la-reserva',
    '2026-06-15',
    '10:00',
    '11:00',
    'RESERVA',
    TRUE
)
RETURNING id_bloqueo, fecha, hora_inicio, hora_fin, tipo_bloqueo;
 
-- Bloqueo ADMINISTRATIVO (vacaciones sin reserva asociada)
INSERT INTO bloqueo_horario (
    id_empleado,
    id_reserva,
    fecha,
    hora_inicio,
    hora_fin,
    tipo_bloqueo,
    activo
) VALUES (
    'uuid-del-empleado',
    NULL,
    '2026-07-20',
    '00:00',
    '23:59',
    'VACACIONES',
    TRUE
);
 
-- Usando la función del DDL:
SELECT crear_bloqueo_horario(
    'uuid-del-empleado',
    'uuid-de-la-reserva',
    '2026-06-15',
    '10:00',
    '11:00',
    'RESERVA'
);

--Q8. Verificar Disponibilidad de un Empleado (SELECT)
--Comprueba si un empleado tiene horario laboral activo y no tiene bloqueos en el tramo solicitado. Usado antes de crear una reserva.
SQL:
-- Opción A: Usando la función del DDL (recomendado)
SELECT empleado_disponible_en_fecha(
    'uuid-del-empleado',
    '2026-06-15',      -- fecha a consultar
    '10:00',           -- hora inicio solicitada
    '11:00'            -- hora fin solicitada
);
-- Retorna TRUE si disponible, FALSE si ocupado o fuera de horario
 
-- Opción B: Consulta manual paso a paso
-- 1. Verificar que trabaja ese día de la semana
SELECT EXISTS (
    SELECT 1
    FROM horario_laboral
    WHERE id_empleado  = 'uuid-del-empleado'
      AND dia_semana   = 'DOMINGO'          -- día de la fecha consultada
      AND activo       = TRUE
      AND hora_inicio <= '10:00'
      AND hora_fin    >= '11:00'
) AS tiene_horario_laboral;
 
-- 2. Verificar que no hay bloqueos solapados
SELECT id_bloqueo, tipo_bloqueo, hora_inicio, hora_fin
FROM bloqueo_horario
WHERE id_empleado = 'uuid-del-empleado'
  AND fecha       = '2026-06-15'
  AND activo      = TRUE
  AND hora_inicio < '11:00'
  AND hora_fin    > '10:00';  -- solapamiento: inicio_bloqueo < fin_req AND fin_bloqueo > inicio_req

--Q9. Agenda del Día de un Empleado (SELECT)
--Retorna todos los bloqueos activos de un empleado para una fecha específica, ordenados por hora. Útil para el panel del proveedor.
SQL:
SELECT
    bh.hora_inicio,
    bh.hora_fin,
    bh.tipo_bloqueo,
    bh.id_reserva,
    EXTRACT(EPOCH FROM (bh.hora_fin::TIME - bh.hora_inicio::TIME)) / 60
        AS duracion_minutos
FROM bloqueo_horario bh
WHERE bh.id_empleado = 'uuid-del-empleado'
  AND bh.fecha       = CURRENT_DATE
  AND bh.activo      = TRUE
ORDER BY bh.hora_inicio ASC;
 
-- Ver agenda de todos los empleados de un proveedor hoy:
SELECT
    e.nombre_completo,
    bh.hora_inicio,
    bh.hora_fin,
    bh.tipo_bloqueo,
    bh.id_reserva
FROM bloqueo_horario bh
JOIN empleado e ON bh.id_empleado = e.id_empleado
WHERE e.id_proveedor = 'uuid-del-proveedor'
  AND bh.fecha       = CURRENT_DATE
  AND bh.activo      = TRUE
ORDER BY e.nombre_completo, bh.hora_inicio ASC;

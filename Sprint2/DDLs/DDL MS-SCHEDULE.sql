CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE empleado (
    id_empleado UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_proveedor UUID NOT NULL,
    nombre_completo VARCHAR(150) NOT NULL,
    telefono VARCHAR(20) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_contratacion TIMESTAMPTZ NULL,
    notas VARCHAR(500) NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_empleado_proveedor ON empleado(id_proveedor);
CREATE INDEX idx_empleado_nombre ON empleado(nombre_completo);
CREATE INDEX idx_empleado_proveedor_activo ON empleado(id_proveedor, activo) WHERE activo = TRUE;

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_empleado_updated_at
    BEFORE UPDATE ON empleado
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE empleado IS 'Empleados o trabajadores asociados a un proveedor (barberos, estilistas, terapeutas, etc.)';
COMMENT ON COLUMN empleado.id_empleado IS 'Identificador único del empleado (UUID)';
COMMENT ON COLUMN empleado.id_proveedor IS 'Referencia lógica al proveedor dueño del empleado (MS-AUTH-SERVICE - validada vía Feign)';
COMMENT ON COLUMN empleado.nombre_completo IS 'Nombre completo del empleado';
COMMENT ON COLUMN empleado.telefono IS 'Número de contacto del empleado';
COMMENT ON COLUMN empleado.activo IS 'Indica si el empleado está activo (TRUE) o inactivo (FALSE)';
COMMENT ON COLUMN empleado.fecha_contratacion IS 'Fecha de contratación del empleado';
COMMENT ON COLUMN empleado.notas IS 'Notas adicionales sobre el empleado';
CREATE TABLE empleado_servicio (
    id_empleado_servicio UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_empleado UUID NOT NULL,
    id_servicio UUID NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_asignacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_empleado_servicio_empleado 
        FOREIGN KEY (id_empleado) 
        REFERENCES empleado(id_empleado) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE
);

CREATE INDEX idx_empleado_servicio_empleado ON empleado_servicio(id_empleado);
CREATE INDEX idx_empleado_servicio_servicio ON empleado_servicio(id_servicio);
CREATE INDEX idx_empleado_servicio_activo ON empleado_servicio(id_empleado, id_servicio, activo) WHERE activo = TRUE;

CREATE TRIGGER trigger_empleado_servicio_updated_at
    BEFORE UPDATE ON empleado_servicio
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE empleado_servicio IS 'Relación muchos-a-muchos entre empleados y servicios (qué empleados pueden realizar qué servicios)';
COMMENT ON COLUMN empleado_servicio.id_empleado_servicio IS 'Identificador único de la asignación (UUID)';
COMMENT ON COLUMN empleado_servicio.id_empleado IS 'Referencia al empleado (FK FÍSICA → empleado.id_empleado)';
COMMENT ON COLUMN empleado_servicio.id_servicio IS 'Referencia al servicio (FK lógica a MS-CATALOG-SERVICE - solo se almacena el ID)';
COMMENT ON COLUMN empleado_servicio.activo IS 'Indica si la asignación está activa (TRUE) o inactiva (FALSE)';
COMMENT ON COLUMN empleado_servicio.fecha_asignacion IS 'Fecha en que se asignó el servicio al empleado';
CREATE TABLE horario_laboral (
    id_horario UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_empleado UUID NOT NULL,
    dia_semana VARCHAR(10) NOT NULL
        CHECK (dia_semana IN ('LUNES', 'MARTES', 'MIERCOLES', 'JUEVES', 'VIERNES', 'SABADO', 'DOMINGO')),
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_horario_laboral_empleado 
        FOREIGN KEY (id_empleado) 
        REFERENCES empleado(id_empleado) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,

    CONSTRAINT chk_horario_laboral_horas_validas 
        CHECK (hora_fin > hora_inicio)
);

CREATE INDEX idx_horario_laboral_empleado ON horario_laboral(id_empleado);
CREATE INDEX idx_horario_laboral_dia_semana ON horario_laboral(dia_semana);
CREATE INDEX idx_horario_laboral_empleado_dia_activo ON horario_laboral(id_empleado, dia_semana, activo) WHERE activo = TRUE;

CREATE TRIGGER trigger_horario_laboral_updated_at
    BEFORE UPDATE ON horario_laboral
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE horario_laboral IS 'Horarios laborales recurrentes por empleado (ej: todos los lunes 8am-2pm). Define cuándo trabaja el empleado SEMANALMENTE.';
COMMENT ON COLUMN horario_laboral.id_horario IS 'Identificador único del horario laboral (UUID)';
COMMENT ON COLUMN horario_laboral.id_empleado IS 'Referencia al empleado (FK FÍSICA → empleado.id_empleado)';
COMMENT ON COLUMN horario_laboral.dia_semana IS 'Día de la semana (LUNES, MARTES, MIERCOLES, JUEVES, VIERNES, SABADO, DOMINGO)';
COMMENT ON COLUMN horario_laboral.hora_inicio IS 'Hora de inicio del bloque laboral';
COMMENT ON COLUMN horario_laboral.hora_fin IS 'Hora de fin del bloque laboral';
COMMENT ON COLUMN horario_laboral.activo IS 'Indica si este horario está activo (TRUE) o eliminado (FALSE). Si es FALSE, el empleado NO trabaja ese día NUNCA.';
CREATE TABLE bloqueo_horario (
    id_bloqueo UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_empleado UUID NOT NULL,
    id_reserva UUID NULL,
    fecha DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    tipo_bloqueo VARCHAR(20) NOT NULL DEFAULT 'RESERVA'
        CHECK (tipo_bloqueo IN ('RESERVA', 'VACACIONES', 'PERMISO', 'ADMINISTRATIVO')),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bloqueo_horario_empleado 
        FOREIGN KEY (id_empleado) 
        REFERENCES empleado(id_empleado) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,

    CONSTRAINT chk_bloqueo_horario_horas_validas 
        CHECK (hora_fin > hora_inicio)
);

CREATE INDEX idx_bloqueo_horario_empleado_fecha ON bloqueo_horario(id_empleado, fecha);
CREATE INDEX idx_bloqueo_horario_fecha ON bloqueo_horario(fecha);
CREATE INDEX idx_bloqueo_horario_empleado_fecha_activo ON bloqueo_horario(id_empleado, fecha, activo) WHERE activo = TRUE;
CREATE INDEX idx_bloqueo_horario_reserva ON bloqueo_horario(id_reserva) WHERE id_reserva IS NOT NULL;

CREATE TRIGGER trigger_bloqueo_horario_updated_at
    BEFORE UPDATE ON bloqueo_horario
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE bloqueo_horario IS 'Bloqueos de horario por fecha ESPECÍFICA. Cada reserva crea un bloqueo. También sirve para vacaciones, permisos, etc.';
COMMENT ON COLUMN bloqueo_horario.id_bloqueo IS 'Identificador único del bloqueo (UUID)';
COMMENT ON COLUMN bloqueo_horario.id_empleado IS 'Referencia al empleado (FK FÍSICA → empleado.id_empleado)';
COMMENT ON COLUMN bloqueo_horario.id_reserva IS 'Referencia a la reserva (FK lógica a MS-RESERVATION-SERVICE). NULL si es bloqueo administrativo.';
COMMENT ON COLUMN bloqueo_horario.fecha IS 'Fecha ESPECÍFICA del bloqueo (ej: 2026-12-15). NO es recurrente.';
COMMENT ON COLUMN bloqueo_horario.hora_inicio IS 'Hora de inicio del bloqueo';
COMMENT ON COLUMN bloqueo_horario.hora_fin IS 'Hora de fin del bloqueo';
COMMENT ON COLUMN bloqueo_horario.tipo_bloqueo IS 'Tipo de bloqueo: RESERVA (cliente), VACACIONES, PERMISO, ADMINISTRATIVO';
COMMENT ON COLUMN bloqueo_horario.activo IS 'Indica si el bloqueo está activo. Para reservas, siempre TRUE mientras la reserva exista.';
CREATE OR REPLACE VIEW vista_empleados_activos_por_proveedor AS
SELECT
    e.id_empleado,
    e.id_proveedor,
    e.nombre_completo,
    e.telefono,
    e.fecha_contratacion,
    COUNT(DISTINCT es.id_servicio) AS total_servicios_asignados,
    COUNT(DISTINCT hl.id_horario) AS total_horarios_laborales,
    COUNT(DISTINCT bh.id_bloqueo) AS total_bloqueos_futuros
FROM empleado e
LEFT JOIN empleado_servicio es ON e.id_empleado = es.id_empleado AND es.activo = TRUE
LEFT JOIN horario_laboral hl ON e.id_empleado = hl.id_empleado AND hl.activo = TRUE
LEFT JOIN bloqueo_horario bh ON e.id_empleado = bh.id_empleado AND bh.fecha >= CURRENT_DATE AND bh.activo = TRUE
WHERE e.activo = TRUE
GROUP BY e.id_empleado, e.id_proveedor, e.nombre_completo, e.telefono, e.fecha_contratacion;
CREATE OR REPLACE VIEW vista_servicios_por_empleado AS
SELECT
    e.id_empleado,
    e.nombre_completo,
    e.id_proveedor,
    es.id_servicio,
    es.activo AS asignacion_activa,
    es.fecha_asignacion
FROM empleado e
JOIN empleado_servicio es ON e.id_empleado = es.id_empleado
WHERE es.activo = TRUE AND e.activo = TRUE;
CREATE OR REPLACE VIEW vista_horario_laboral_semanal AS
SELECT
    e.id_empleado,
    e.nombre_completo,
    e.id_proveedor,
    hl.dia_semana,
    hl.hora_inicio,
    hl.hora_fin,
    hl.activo
FROM empleado e
JOIN horario_laboral hl ON e.id_empleado = hl.id_empleado
WHERE hl.activo = TRUE AND e.activo = TRUE
ORDER BY e.id_empleado, 
    CASE hl.dia_semana
        WHEN 'LUNES' THEN 1
        WHEN 'MARTES' THEN 2
        WHEN 'MIERCOLES' THEN 3
        WHEN 'JUEVES' THEN 4
        WHEN 'VIERNES' THEN 5
        WHEN 'SABADO' THEN 6
        WHEN 'DOMINGO' THEN 7
    END,
    hl.hora_inicio;
CREATE OR REPLACE VIEW vista_bloqueos_futuros AS
SELECT
    e.id_empleado,
    e.nombre_completo,
    bh.fecha,
    bh.hora_inicio,
    bh.hora_fin,
    bh.tipo_bloqueo,
    bh.id_reserva,
    bh.activo
FROM empleado e
JOIN bloqueo_horario bh ON e.id_empleado = bh.id_empleado
WHERE bh.fecha >= CURRENT_DATE AND bh.activo = TRUE
ORDER BY e.id_empleado, bh.fecha, bh.hora_inicio;
CREATE OR REPLACE VIEW vista_empleado_servicio_completo AS
SELECT
    es.id_empleado_servicio,
    e.id_empleado,
    e.nombre_completo,
    e.id_proveedor,
    es.id_servicio,
    es.activo,
    es.fecha_asignacion,
    es.created_at
FROM empleado_servicio es
JOIN empleado e ON es.id_empleado = e.id_empleado
WHERE e.activo = TRUE;
CREATE OR REPLACE FUNCTION obtener_empleados_por_proveedor(
    p_id_proveedor UUID,
    p_solo_activos BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    id_empleado UUID,
    nombre_completo VARCHAR,
    telefono VARCHAR,
    activo BOOLEAN,
    total_servicios_asignados BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.id_empleado,
        e.nombre_completo,
        e.telefono,
        e.activo,
        COUNT(DISTINCT es.id_servicio) AS total_servicios_asignados
    FROM empleado e
    LEFT JOIN empleado_servicio es ON e.id_empleado = es.id_empleado AND es.activo = TRUE
    WHERE e.id_proveedor = p_id_proveedor
    AND (p_solo_activos = FALSE OR e.activo = TRUE)
    GROUP BY e.id_empleado, e.nombre_completo, e.telefono, e.activo
    ORDER BY e.nombre_completo ASC;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION obtener_servicios_por_empleado(
    p_id_empleado UUID,
    p_solo_activos BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    id_servicio UUID,
    activo BOOLEAN,
    fecha_asignacion TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        es.id_servicio,
        es.activo,
        es.fecha_asignacion
    FROM empleado_servicio es
    WHERE es.id_empleado = p_id_empleado
    AND (p_solo_activos = FALSE OR es.activo = TRUE)
    ORDER BY es.fecha_asignacion DESC;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION obtener_horario_laboral_por_empleado(
    p_id_empleado UUID,
    p_dia_semana VARCHAR DEFAULT NULL,
    p_solo_activos BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    id_horario UUID,
    dia_semana VARCHAR,
    hora_inicio TIME,
    hora_fin TIME,
    activo BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        hl.id_horario,
        hl.dia_semana,
        hl.hora_inicio,
        hl.hora_fin,
        hl.activo
    FROM horario_laboral hl
    WHERE hl.id_empleado = p_id_empleado
    AND (p_dia_semana IS NULL OR hl.dia_semana = p_dia_semana)
    AND (p_solo_activos = FALSE OR hl.activo = TRUE)
    ORDER BY 
        CASE hl.dia_semana
            WHEN 'LUNES' THEN 1
            WHEN 'MARTES' THEN 2
            WHEN 'MIERCOLES' THEN 3
            WHEN 'JUEVES' THEN 4
            WHEN 'VIERNES' THEN 5
            WHEN 'SABADO' THEN 6
            WHEN 'DOMINGO' THEN 7
        END,
        hl.hora_inicio;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION obtener_bloqueos_por_empleado(
    p_id_empleado UUID,
    p_fecha_inicio DATE DEFAULT CURRENT_DATE,
    p_fecha_fin DATE DEFAULT NULL
)
RETURNS TABLE (
    id_bloqueo UUID,
    fecha DATE,
    hora_inicio TIME,
    hora_fin TIME,
    tipo_bloqueo VARCHAR,
    id_reserva UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        bh.id_bloqueo,
        bh.fecha,
        bh.hora_inicio,
        bh.hora_fin,
        bh.tipo_bloqueo,
        bh.id_reserva
    FROM bloqueo_horario bh
    WHERE bh.id_empleado = p_id_empleado
    AND bh.fecha >= p_fecha_inicio
    AND (p_fecha_fin IS NULL OR bh.fecha <= p_fecha_fin)
    AND bh.activo = TRUE
    ORDER BY bh.fecha, bh.hora_inicio;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION empleado_disponible_en_fecha(
    p_id_empleado UUID,
    p_fecha DATE,
    p_hora_inicio TIME,
    p_hora_fin TIME
)
RETURNS BOOLEAN AS $$
DECLARE
    v_dia_semana VARCHAR;
    v_horario_laboral BOOLEAN;
    v_bloqueo_existente BOOLEAN;
BEGIN
    SELECT INTO v_dia_semana
        CASE EXTRACT(DOW FROM p_fecha)
            WHEN 0 THEN 'DOMINGO'
            WHEN 1 THEN 'LUNES'
            WHEN 2 THEN 'MARTES'
            WHEN 3 THEN 'MIERCOLES'
            WHEN 4 THEN 'JUEVES'
            WHEN 5 THEN 'VIERNES'
            WHEN 6 THEN 'SABADO'
        END;
    SELECT INTO v_horario_laboral EXISTS (
        SELECT 1 FROM horario_laboral hl
        WHERE hl.id_empleado = p_id_empleado
        AND hl.dia_semana = v_dia_semana
        AND hl.activo = TRUE
        AND hl.hora_inicio <= p_hora_inicio
        AND hl.hora_fin >= p_hora_fin
    );
    IF NOT v_horario_laboral THEN
        RETURN FALSE;
    END IF;
    SELECT INTO v_bloqueo_existente EXISTS (
        SELECT 1 FROM bloqueo_horario bh
        WHERE bh.id_empleado = p_id_empleado
        AND bh.fecha = p_fecha
        AND bh.activo = TRUE
        AND (
            (bh.hora_inicio <= p_hora_inicio AND bh.hora_fin > p_hora_inicio) OR
            (bh.hora_inicio < p_hora_fin AND bh.hora_fin >= p_hora_fin) OR
            (bh.hora_inicio >= p_hora_inicio AND bh.hora_fin <= p_hora_fin)
        )
    );
    IF v_bloqueo_existente THEN
        RETURN FALSE;
    END IF;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION crear_bloqueo_horario(
    p_id_empleado UUID,
    p_id_reserva UUID,
    p_fecha DATE,
    p_hora_inicio TIME,
    p_hora_fin TIME,
    p_tipo_bloqueo VARCHAR DEFAULT 'RESERVA'
)
RETURNS UUID AS $$
DECLARE
    v_id_bloqueo UUID;
BEGIN
    INSERT INTO bloqueo_horario (id_empleado, id_reserva, fecha, hora_inicio, hora_fin, tipo_bloqueo, activo)
    VALUES (p_id_empleado, p_id_reserva, p_fecha, p_hora_inicio, p_hora_fin, p_tipo_bloqueo, TRUE)
    RETURNING id_bloqueo INTO v_id_bloqueo;
    
    RETURN v_id_bloqueo;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION eliminar_bloqueo_horario(
    p_id_bloqueo UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE bloqueo_horario
    SET activo = FALSE
    WHERE id_bloqueo = p_id_bloqueo AND activo = TRUE;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION desactivar_empleado(
    p_id_empleado UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE empleado
    SET activo = FALSE
    WHERE id_empleado = p_id_empleado AND activo = TRUE;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION activar_empleado(
    p_id_empleado UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE empleado
    SET activo = TRUE
    WHERE id_empleado = p_id_empleado AND activo = FALSE;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION asignar_servicio_a_empleado(
    p_id_empleado UUID,
    p_id_servicio UUID
)
RETURNS UUID AS $$
DECLARE
    v_id_empleado_servicio UUID;
BEGIN
    INSERT INTO empleado_servicio (id_empleado, id_servicio, activo, fecha_asignacion)
    VALUES (p_id_empleado, p_id_servicio, TRUE, CURRENT_TIMESTAMP)
    RETURNING id_empleado_servicio INTO v_id_empleado_servicio;
    
    RETURN v_id_empleado_servicio;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION remover_servicio_de_empleado(
    p_id_empleado UUID,
    p_id_servicio UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE empleado_servicio
    SET activo = FALSE
    WHERE id_empleado = p_id_empleado AND id_servicio = p_id_servicio AND activo = TRUE;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

ALTER TABLE empleado ENABLE ROW LEVEL SECURITY;
ALTER TABLE empleado_servicio ENABLE ROW LEVEL SECURITY;
ALTER TABLE horario_laboral ENABLE ROW LEVEL SECURITY;
ALTER TABLE bloqueo_horario ENABLE ROW LEVEL SECURITY;

ALTER TABLE empleado FORCE ROW LEVEL SECURITY;
ALTER TABLE empleado_servicio FORCE ROW LEVEL SECURITY;
ALTER TABLE horario_laboral FORCE ROW LEVEL SECURITY;
ALTER TABLE bloqueo_horario FORCE ROW LEVEL SECURITY;
CREATE POLICY "proveedores_pueden_ver_sus_empleados"
ON empleado
FOR SELECT
USING (
    id_proveedor = auth.uid()
    OR
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);
CREATE POLICY "proveedores_pueden_crear_sus_empleados"
ON empleado
FOR INSERT
WITH CHECK (
    id_proveedor = auth.uid()
    AND
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'tipo_usuario' = 'PROVEEDOR'
    )
);
CREATE POLICY "proveedores_pueden_actualizar_sus_empleados"
ON empleado
FOR UPDATE
USING (
    id_proveedor = auth.uid()
    OR
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
)
WITH CHECK (
    id_proveedor = id_proveedor
);
CREATE POLICY "proveedores_pueden_desactivar_sus_empleados"
ON empleado
FOR UPDATE
USING (
    id_proveedor = auth.uid()
)
WITH CHECK (
    id_proveedor = id_proveedor
    AND activo = FALSE
);
CREATE POLICY "admin_puede_ver_todos_empleados"
ON empleado
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);
CREATE POLICY "solo_admin_puede_eliminar_empleados"
ON empleado
FOR DELETE
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);
CREATE POLICY "proveedores_pueden_ver_sus_empleado_servicios"
ON empleado_servicio
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM empleado e
        WHERE e.id_empleado = empleado_servicio.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    OR
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);
CREATE POLICY "proveedores_pueden_crear_sus_empleado_servicios"
ON empleado_servicio
FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM empleado e
        WHERE e.id_empleado = empleado_servicio.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    AND
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'tipo_usuario' = 'PROVEEDOR'
    )
);
CREATE POLICY "proveedores_pueden_actualizar_sus_empleado_servicios"
ON empleado_servicio
FOR UPDATE
USING (
    EXISTS (
        SELECT 1
        FROM empleado e
        WHERE e.id_empleado = empleado_servicio.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    OR
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
)
WITH CHECK (
    id_empleado = id_empleado
);
CREATE POLICY "proveedores_pueden_ver_sus_horarios_laborales"
ON horario_laboral
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM empleado e
        WHERE e.id_empleado = horario_laboral.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    OR
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);
CREATE POLICY "proveedores_pueden_crear_sus_horarios_laborales"
ON horario_laboral
FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM empleado e
        WHERE e.id_empleado = horario_laboral.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    AND
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'tipo_usuario' = 'PROVEEDOR'
    )
);
CREATE POLICY "proveedores_pueden_actualizar_sus_horarios_laborales"
ON horario_laboral
FOR UPDATE
USING (
    EXISTS (
        SELECT 1
        FROM empleado e
        WHERE e.id_empleado = horario_laboral.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    OR
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
)
WITH CHECK (
    id_empleado = id_empleado
);
CREATE POLICY "proveedores_pueden_ver_sus_bloqueos_horarios"
ON bloqueo_horario
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM empleado e
        WHERE e.id_empleado = bloqueo_horario.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    OR
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);
CREATE POLICY "sistema_puede_crear_bloqueos_horarios"
ON bloqueo_horario
FOR INSERT
WITH CHECK (
    TRUE
);
CREATE POLICY "proveedores_pueden_actualizar_sus_bloqueos_horarios"
ON bloqueo_horario
FOR UPDATE
USING (
    EXISTS (
        SELECT 1
        FROM empleado e
        WHERE e.id_empleado = bloqueo_horario.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    OR
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
)
WITH CHECK (
    id_empleado = id_empleado
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_account_role') THEN
        CREATE ROLE service_account_role;
    END IF;
END $$;

GRANT USAGE ON SCHEMA public TO service_account_role;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO service_account_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_account_role;
CREATE POLICY "service_account_empleado_full_access"
ON empleado
FOR ALL
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'service_account'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'service_account'
    )
);

CREATE POLICY "service_account_empleado_servicio_full_access"
ON empleado_servicio
FOR ALL
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'service_account'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'service_account'
    )
);

CREATE POLICY "service_account_horario_laboral_full_access"
ON horario_laboral
FOR ALL
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'service_account'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'service_account'
    )
);

CREATE POLICY "service_account_bloqueo_horario_full_access"
ON bloqueo_horario
FOR ALL
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'service_account'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'service_account'
    )
);
CREATE OR REPLACE FUNCTION es_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION es_proveedor()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'tipo_usuario' = 'PROVEEDOR'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION es_cuenta_servicio()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'service_account'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION obtener_id_usuario_actual()
RETURNS UUID AS $$
BEGIN
    RETURN auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE INDEX IF NOT EXISTS idx_empleado_proveedor_estado ON empleado(id_proveedor, activo);
CREATE INDEX IF NOT EXISTS idx_horario_laboral_empleado_dia ON horario_laboral(id_empleado, dia_semana);
CREATE INDEX IF NOT EXISTS idx_empleado_servicio_empleado_activo ON empleado_servicio(id_empleado, activo);
CREATE INDEX IF NOT EXISTS idx_empleado_servicio_servicio_activo ON empleado_servicio(id_servicio, activo);
CREATE INDEX IF NOT EXISTS idx_bloqueo_horario_fecha_empleado ON bloqueo_horario(fecha, id_empleado);

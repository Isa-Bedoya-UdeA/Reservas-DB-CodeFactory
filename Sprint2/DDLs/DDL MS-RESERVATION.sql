
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE reserva (
    id_reserva UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_cliente UUID NOT NULL,
    id_servicio UUID NOT NULL,
    id_empleado UUID NOT NULL,
    id_proveedor UUID NOT NULL,
    fecha_hora_inicio TIMESTAMPTZ NOT NULL,
    fecha_hora_fin TIMESTAMPTZ NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE'
        CHECK (estado IN ('PENDIENTE', 'CONFIRMADA', 'EN_PROGRESO', 'COMPLETADA', 'CANCELADA', 'NO_SHOW')),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_cancelacion TIMESTAMPTZ NULL,
    comentarios VARCHAR(500) NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_reserva_fechas_validas 
        CHECK (fecha_hora_fin > fecha_hora_inicio),

    CONSTRAINT chk_reserva_fecha_cancelacion_valida 
        CHECK (fecha_cancelacion IS NULL OR fecha_cancelacion >= fecha_creacion)
);

CREATE INDEX idx_reserva_cliente ON reserva(id_cliente);

CREATE INDEX idx_reserva_empleado ON reserva(id_empleado);

CREATE INDEX idx_reserva_proveedor ON reserva(id_proveedor);

CREATE INDEX idx_reserva_servicio ON reserva(id_servicio);

CREATE INDEX idx_reserva_estado ON reserva(estado);

CREATE INDEX idx_reserva_fecha_inicio ON reserva(fecha_hora_inicio);

CREATE INDEX idx_reserva_cliente_estado ON reserva(id_cliente, estado);

CREATE INDEX idx_reserva_empleado_fecha ON reserva(id_empleado, fecha_hora_inicio DESC);

CREATE INDEX idx_reserva_proveedor_estado ON reserva(id_proveedor, estado);

CREATE INDEX idx_reserva_validacion_horario ON reserva(id_empleado, fecha_hora_inicio, fecha_hora_fin, estado)
    WHERE estado IN ('PENDIENTE', 'CONFIRMADA', 'EN_PROGRESO');

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_reserva_updated_at
    BEFORE UPDATE ON reserva
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE FUNCTION actualizar_fecha_cancelacion()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.estado != 'CANCELADA' AND NEW.estado = 'CANCELADA' THEN
        NEW.fecha_cancelacion = CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_reserva_fecha_cancelacion
    BEFORE UPDATE ON reserva
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_fecha_cancelacion();

COMMENT ON TABLE reserva IS 'Registro transaccional de citas/reservas agendadas por clientes';
COMMENT ON COLUMN reserva.id_reserva IS 'Identificador único de la reserva (UUID)';
COMMENT ON COLUMN reserva.id_cliente IS 'Referencia lógica al cliente que realiza la reserva (MS-AUTH-SERVICE)';
COMMENT ON COLUMN reserva.id_servicio IS 'Referencia lógica al servicio contratado (MS-CATALOG-SERVICE)';
COMMENT ON COLUMN reserva.id_empleado IS 'Referencia lógica al empleado que realizará el servicio (MS-SCHEDULE-SERVICE)';
COMMENT ON COLUMN reserva.id_proveedor IS 'Referencia lógica al proveedor dueño del empleado (MS-AUTH-SERVICE)';
COMMENT ON COLUMN reserva.fecha_hora_inicio IS 'Fecha y hora exacta de inicio de la cita';
COMMENT ON COLUMN reserva.fecha_hora_fin IS 'Fecha y hora estimada de finalización de la cita';
COMMENT ON COLUMN reserva.estado IS 'Estado actual de la reserva (PENDIENTE, CONFIRMADA, EN_PROGRESO, COMPLETADA, CANCELADA, NO_SHOW)';
COMMENT ON COLUMN reserva.fecha_creacion IS 'Fecha y hora de creación de la reserva';
COMMENT ON COLUMN reserva.fecha_cancelacion IS 'Fecha y hora de cancelación (NULL si no fue cancelada)';
COMMENT ON COLUMN reserva.comentarios IS 'Observaciones adicionales del cliente o proveedor';

CREATE OR REPLACE VIEW vista_reservas_activas AS
SELECT
    id_reserva,
    id_cliente,
    id_servicio,
    id_empleado,
    id_proveedor,
    fecha_hora_inicio,
    fecha_hora_fin,
    estado,
    fecha_creacion,
    comentarios
FROM reserva
WHERE estado IN ('PENDIENTE', 'CONFIRMADA', 'EN_PROGRESO')
ORDER BY fecha_hora_inicio ASC;

CREATE OR REPLACE VIEW vista_reservas_por_cliente AS
SELECT
    r.id_reserva,
    r.id_cliente,
    r.id_servicio,
    r.id_empleado,
    r.id_proveedor,
    r.fecha_hora_inicio,
    r.fecha_hora_fin,
    r.estado,
    r.fecha_creacion,
    r.fecha_cancelacion,
    r.comentarios
FROM reserva r
ORDER BY r.fecha_creacion DESC;

CREATE OR REPLACE VIEW vista_reservas_dia_actual_por_empleado AS
SELECT
    r.id_reserva,
    r.id_empleado,
    r.id_cliente,
    r.id_servicio,
    r.fecha_hora_inicio,
    r.fecha_hora_fin,
    r.estado,
    r.comentarios
FROM reserva r
WHERE DATE(r.fecha_hora_inicio) = CURRENT_DATE
AND r.estado IN ('PENDIENTE', 'CONFIRMADA', 'EN_PROGRESO')
ORDER BY r.fecha_hora_inicio ASC;

CREATE OR REPLACE VIEW vista_estadisticas_reservas_proveedor AS
SELECT
    id_proveedor,
    COUNT(*) AS total_reservas,
    COUNT(*) FILTER (WHERE estado = 'PENDIENTE') AS reservas_pendientes,
    COUNT(*) FILTER (WHERE estado = 'CONFIRMADA') AS reservas_confirmadas,
    COUNT(*) FILTER (WHERE estado = 'EN_PROGRESO') AS reservas_en_progreso,
    COUNT(*) FILTER (WHERE estado = 'COMPLETADA') AS reservas_completadas,
    COUNT(*) FILTER (WHERE estado = 'CANCELADA') AS reservas_canceladas,
    COUNT(*) FILTER (WHERE estado = 'NO_SHOW') AS reservas_no_show,
    AVG(EXTRACT(EPOCH FROM (fecha_hora_fin - fecha_hora_inicio))/60) AS duracion_promedio_minutos
FROM reserva
GROUP BY id_proveedor;

CREATE OR REPLACE VIEW vista_reservas_proximas AS
SELECT
    id_reserva,
    id_cliente,
    id_servicio,
    id_empleado,
    id_proveedor,
    fecha_hora_inicio,
    fecha_hora_fin,
    estado,
    comentarios
FROM reserva
WHERE fecha_hora_inicio BETWEEN CURRENT_TIMESTAMP AND (CURRENT_TIMESTAMP + INTERVAL '24 hours')
AND estado IN ('PENDIENTE', 'CONFIRMADA')
ORDER BY fecha_hora_inicio ASC;

CREATE OR REPLACE FUNCTION obtener_reservas_por_cliente(
    p_id_cliente UUID,
    p_estado VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    id_reserva UUID,
    id_servicio UUID,
    id_empleado UUID,
    id_proveedor UUID,
    fecha_hora_inicio TIMESTAMPTZ,
    fecha_hora_fin TIMESTAMPTZ,
    estado VARCHAR,
    fecha_creacion TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id_reserva,
        r.id_servicio,
        r.id_empleado,
        r.id_proveedor,
        r.fecha_hora_inicio,
        r.fecha_hora_fin,
        r.estado,
        r.fecha_creacion
    FROM reserva r
    WHERE r.id_cliente = p_id_cliente
    AND (p_estado IS NULL OR r.estado = p_estado)
    ORDER BY r.fecha_hora_inicio DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION obtener_reservas_por_empleado(
    p_id_empleado UUID,
    p_fecha_inicio TIMESTAMPTZ,
    p_fecha_fin TIMESTAMPTZ
)
RETURNS TABLE (
    id_reserva UUID,
    id_cliente UUID,
    id_servicio UUID,
    fecha_hora_inicio TIMESTAMPTZ,
    fecha_hora_fin TIMESTAMPTZ,
    estado VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id_reserva,
        r.id_cliente,
        r.id_servicio,
        r.fecha_hora_inicio,
        r.fecha_hora_fin,
        r.estado
    FROM reserva r
    WHERE r.id_empleado = p_id_empleado
    AND r.fecha_hora_inicio BETWEEN p_fecha_inicio AND p_fecha_fin
    ORDER BY r.fecha_hora_inicio ASC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cancelar_reserva(
    p_id_reserva UUID,
    p_comentarios VARCHAR DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE reserva
    SET 
        estado = 'CANCELADA',
        comentarios = COALESCE(comentarios || ' | ', '') || COALESCE(p_comentarios, 'Cancelada por usuario')
    WHERE id_reserva = p_id_reserva
    AND estado NOT IN ('CANCELADA', 'COMPLETADA', 'NO_SHOW');
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION validar_conflicto_horario(
    p_id_empleado UUID,
    p_fecha_hora_inicio TIMESTAMPTZ,
    p_fecha_hora_fin TIMESTAMPTZ,
    p_id_reserva_excluir UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_conflicto INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_conflicto
    FROM reserva
    WHERE id_empleado = p_id_empleado
    AND estado IN ('PENDIENTE', 'CONFIRMADA', 'EN_PROGRESO')
    AND (
        (fecha_hora_inicio < p_fecha_hora_fin AND fecha_hora_fin > p_fecha_hora_inicio)
    )
    AND (p_id_reserva_excluir IS NULL OR id_reserva != p_id_reserva_excluir);
    
    RETURN v_conflicto > 0;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION obtener_estadisticas_reservas_proveedor(
    p_id_proveedor UUID,
    p_fecha_inicio TIMESTAMPTZ,
    p_fecha_fin TIMESTAMPTZ
)
RETURNS TABLE (
    total_reservas BIGINT,
    reservas_pendientes BIGINT,
    reservas_confirmadas BIGINT,
    reservas_completadas BIGINT,
    reservas_canceladas BIGINT,
    tasa_cancelacion NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*) AS total_reservas,
        COUNT(*) FILTER (WHERE estado = 'PENDIENTE') AS reservas_pendientes,
        COUNT(*) FILTER (WHERE estado = 'CONFIRMADA') AS reservas_confirmadas,
        COUNT(*) FILTER (WHERE estado = 'COMPLETADA') AS reservas_completadas,
        COUNT(*) FILTER (WHERE estado = 'CANCELADA') AS reservas_canceladas,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                ROUND(COUNT(*) FILTER (WHERE estado = 'CANCELADA') * 100.0 / COUNT(*), 2)
            ELSE 0 
        END AS tasa_cancelacion
    FROM reserva
    WHERE id_proveedor = p_id_proveedor
    AND fecha_creacion BETWEEN p_fecha_inicio AND p_fecha_fin;
END;
$$ LANGUAGE plpgsql;

ALTER TABLE reserva ENABLE ROW LEVEL SECURITY;

ALTER TABLE reserva FORCE ROW LEVEL SECURITY;

CREATE POLICY "clientes_pueden_ver_sus_reservas"
ON reserva
FOR SELECT
USING (
    id_cliente = auth.uid()
    OR
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);

CREATE POLICY "proveedores_pueden_ver_sus_reservas"
ON reserva
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

CREATE POLICY "clientes_pueden_crear_sus_reservas"
ON reserva
FOR INSERT
WITH CHECK (
    id_cliente = auth.uid()
    AND
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'tipo_usuario' = 'CLIENTE'
    )
);

CREATE POLICY "clientes_pueden_cancelar_sus_reservas"
ON reserva
FOR UPDATE
USING (
    id_cliente = auth.uid()
)
WITH CHECK (
    id_cliente = id_cliente
    AND estado IN ('CANCELADA', 'NO_SHOW')
);

CREATE POLICY "proveedores_pueden_actualizar_sus_reservas"
ON reserva
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

CREATE POLICY "admin_puede_ver_todas_reservas"
ON reserva
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_eliminar_reservas"
ON reserva
FOR DELETE
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
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

CREATE POLICY "service_account_reserva_full_access"
ON reserva
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

CREATE OR REPLACE FUNCTION es_cliente()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'tipo_usuario' = 'CLIENTE'
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

CREATE INDEX IF NOT EXISTS idx_reserva_cliente_fecha ON reserva(id_cliente, fecha_hora_inicio);

CREATE INDEX IF NOT EXISTS idx_reserva_empleado_estado ON reserva(id_empleado, estado);

CREATE INDEX IF NOT EXISTS idx_reserva_proveedor_fecha ON reserva(id_proveedor, fecha_hora_inicio);

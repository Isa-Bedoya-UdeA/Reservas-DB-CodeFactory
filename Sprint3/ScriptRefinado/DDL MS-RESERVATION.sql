-- ============================================================================
--  MS-SCHEDULE-SERVICE
--  Triggers y procedimientos, organizados por HU
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ────────────────────────────────────────────────────────────────────────────
--  HU: GESTIÓN DE EMPLEADOS, HORARIOS Y BLOQUEOS
--  Triggers updated_at de las 4 tablas.
-- ────────────────────────────────────────────────────────────────────────────

CREATE TRIGGER trigger_empleado_updated_at
    BEFORE UPDATE ON empleado
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_empleado_servicio_updated_at
    BEFORE UPDATE ON empleado_servicio
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_horario_laboral_updated_at
    BEFORE UPDATE ON horario_laboral
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_bloqueo_horario_updated_at
    BEFORE UPDATE ON bloqueo_horario
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- ────────────────────────────────────────────────────────────────────────────
--  HU: ACTIVAR / DESACTIVAR EMPLEADO (soft delete)
-- ────────────────────────────────────────────────────────────────────────────

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


-- ────────────────────────────────────────────────────────────────────────────
--  HU: ASIGNAR / REMOVER SERVICIOS A UN EMPLEADO (relación N:M)
-- ────────────────────────────────────────────────────────────────────────────

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


-- ────────────────────────────────────────────────────────────────────────────
--  HU: GESTIÓN DE BLOQUEOS DE HORARIO (reservas, vacaciones, permisos)
-- ────────────────────────────────────────────────────────────────────────────

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


-- ────────────────────────────────────────────────────────────────────────────
--  HU: VERIFICAR DISPONIBILIDAD DE UN EMPLEADO (soporte al agendamiento)
--  Comprueba horario laboral vigente y ausencia de bloqueos solapados.
-- ────────────────────────────────────────────────────────────────────────────

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


-- ────────────────────────────────────────────────────────────────────────────
--  Funciones auxiliares de seguridad (RLS) de SCHEDULE
-- ────────────────────────────────────────────────────────────────────────────

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

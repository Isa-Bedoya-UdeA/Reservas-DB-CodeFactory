-- ============================================================================
--  MS-RESERVATION-SERVICE
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
--  HU: CREAR / GESTIONAR RESERVAS
--  Trigger updated_at y registro automático de fecha_cancelacion.
-- ────────────────────────────────────────────────────────────────────────────

CREATE TRIGGER trigger_reserva_updated_at
    BEFORE UPDATE ON reserva
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- Al pasar una reserva a estado CANCELADA, registra automáticamente la fecha
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


-- ────────────────────────────────────────────────────────────────────────────
--  HU: CANCELAR RESERVA
--  Cambia el estado a CANCELADA y concatena el comentario de cancelación,
--  siempre que la reserva no esté ya cerrada.
-- ────────────────────────────────────────────────────────────────────────────

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


-- ────────────────────────────────────────────────────────────────────────────
--  HU: CREAR / REAGENDAR RESERVA — validación de conflicto de horario
--  Devuelve TRUE si el empleado ya tiene una reserva solapada en el tramo.
-- ────────────────────────────────────────────────────────────────────────────

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


-- ────────────────────────────────────────────────────────────────────────────
--  Funciones auxiliares de seguridad (RLS) de RESERVATION
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

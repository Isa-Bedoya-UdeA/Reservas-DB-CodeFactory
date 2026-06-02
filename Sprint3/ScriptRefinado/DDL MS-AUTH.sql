-- ============================================================================
--  MS-AUTH-SERVICE
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
--  HU: REGISTRO DE USUARIOS (Cliente / Proveedor / Admin)
--  Triggers updated_at + validación de coherencia de tipo_usuario.
-- ────────────────────────────────────────────────────────────────────────────

CREATE TRIGGER trigger_usuario_updated_at
    BEFORE UPDATE ON usuario
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_cliente_updated_at
    BEFORE UPDATE ON cliente
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_proveedor_updated_at
    BEFORE UPDATE ON proveedor
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_admin_updated_at
    BEFORE UPDATE ON admin
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- Validación de tipo al registrar un CLIENTE
CREATE OR REPLACE FUNCTION validar_cliente_tipo_usuario()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM usuario
        WHERE id_usuario = NEW.id_usuario
        AND tipo_usuario = 'CLIENTE'
    ) THEN
        RAISE EXCEPTION 'El usuario debe tener tipo_usuario = ''CLIENTE'' para ser registrado como cliente';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validar_cliente_tipo ON cliente;
CREATE TRIGGER trigger_validar_cliente_tipo
    BEFORE INSERT OR UPDATE ON cliente
    FOR EACH ROW
    EXECUTE FUNCTION validar_cliente_tipo_usuario();


-- Validación de tipo al registrar un PROVEEDOR
CREATE OR REPLACE FUNCTION validar_proveedor_tipo_usuario()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM usuario
        WHERE id_usuario = NEW.id_usuario
        AND tipo_usuario = 'PROVEEDOR'
    ) THEN
        RAISE EXCEPTION 'El usuario debe tener tipo_usuario = ''PROVEEDOR'' para ser registrado como proveedor';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validar_proveedor_tipo ON proveedor;
CREATE TRIGGER trigger_validar_proveedor_tipo
    BEFORE INSERT OR UPDATE ON proveedor
    FOR EACH ROW
    EXECUTE FUNCTION validar_proveedor_tipo_usuario();


-- Validación de tipo al registrar un ADMIN
CREATE OR REPLACE FUNCTION validar_admin_tipo_usuario()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM usuario
        WHERE id_usuario = NEW.id_usuario
        AND tipo_usuario = 'ADMIN'
    ) THEN
        RAISE EXCEPTION 'El usuario debe tener tipo_usuario = ''ADMIN'' para ser registrado como administrador';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validar_admin_tipo ON admin;
CREATE TRIGGER trigger_validar_admin_tipo
    BEFORE INSERT OR UPDATE ON admin
    FOR EACH ROW
    EXECUTE FUNCTION validar_admin_tipo_usuario();


-- ────────────────────────────────────────────────────────────────────────────
--  HU: VERIFICACIÓN DE CORREO ELECTRÓNICO
--  Al marcar el token como usado, confirma automáticamente el email.
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION verificar_email_usuario()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.usado = TRUE AND OLD.usado = FALSE THEN
        UPDATE usuario
        SET email_verificado = TRUE
        WHERE id_usuario = NEW.id_usuario;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_email_verification_token_usado
    AFTER UPDATE ON email_verification_token
    FOR EACH ROW
    EXECUTE FUNCTION verificar_email_usuario();


-- ────────────────────────────────────────────────────────────────────────────
--  HU: LOGIN / AUTENTICACIÓN (control de intentos fallidos y bloqueo)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION actualizar_intentos_fallidos(
    p_id_usuario UUID,
    p_intentos INTEGER
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE usuario
    SET intentos_fallidos = p_intentos
    WHERE id_usuario = p_id_usuario;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION bloquear_usuario(
    p_id_usuario UUID,
    p_bloqueado_hasta TIMESTAMPTZ,
    p_estado VARCHAR
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE usuario
    SET
        bloqueado_hasta = p_bloqueado_hasta,
        estado = p_estado
    WHERE id_usuario = p_id_usuario;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION bloquear_usuario_por_intentos(
    p_id_usuario UUID,
    p_horas_bloqueo INTEGER DEFAULT 24
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE usuario
    SET
        bloqueado_hasta = CURRENT_TIMESTAMP + (p_horas_bloqueo || ' hours')::INTERVAL,
        estado = 'BLOQUEADO'
    WHERE id_usuario = p_id_usuario;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION resetear_intentos_fallidos(
    p_id_usuario UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE usuario
    SET
        intentos_fallidos = 0,
        bloqueado_hasta = NULL,
        estado = 'ACTIVO'
    WHERE id_usuario = p_id_usuario;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ────────────────────────────────────────────────────────────────────────────
--  HU: SEGURIDAD Y AUDITORÍA (transversal)
--  Registra automáticamente los cambios sensibles sobre la tabla usuario.
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION auditar_cambios_sensibles()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'usuario' THEN
        IF OLD.password_hash IS DISTINCT FROM NEW.password_hash
        OR OLD.email IS DISTINCT FROM NEW.email
        OR OLD.estado IS DISTINCT FROM NEW.estado THEN
            INSERT INTO public.registro_auditoria (
                nombre_tabla,
                id_registro_afectado,
                operacion,
                modificado_por,
                fecha_modificacion,
                valores_anteriores,
                valores_nuevos
            ) VALUES (
                TG_TABLE_NAME,
                NEW.id_usuario,
                TG_OP,
                auth.uid(),
                NOW(),
                to_jsonb(OLD),
                to_jsonb(NEW)
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_auditar_cambios_usuario
    AFTER UPDATE ON usuario
    FOR EACH ROW
    EXECUTE FUNCTION auditar_cambios_sensibles();


-- ────────────────────────────────────────────────────────────────────────────
--  HU: MANTENIMIENTO / TAREAS PROGRAMADAS (limpieza de tokens y datos)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION limpiar_tokens_expirados()
RETURNS void AS $$
BEGIN
    DELETE FROM token_refresh
    WHERE fecha_expiracion < CURRENT_TIMESTAMP
    AND revocado = FALSE;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION limpiar_datos_expirados()
RETURNS INTEGER AS $$
DECLARE
    v_deleted_count INTEGER := 0;
    v_temp_count INTEGER;
BEGIN
    DELETE FROM token_refresh
    WHERE fecha_expiracion < CURRENT_TIMESTAMP;
    GET DIAGNOSTICS v_temp_count = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_temp_count;

    DELETE FROM token_reset_password
    WHERE fecha_expiracion < CURRENT_TIMESTAMP OR usado = TRUE;
    GET DIAGNOSTICS v_temp_count = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_temp_count;

    DELETE FROM email_verification_token
    WHERE fecha_expiracion < CURRENT_TIMESTAMP OR usado = TRUE;
    GET DIAGNOSTICS v_temp_count = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_temp_count;

    DELETE FROM intento_login
    WHERE fecha_hora < CURRENT_TIMESTAMP - INTERVAL '30 days';
    GET DIAGNOSTICS v_temp_count = ROW_COUNT;
    v_deleted_count := v_deleted_count + v_temp_count;

    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ────────────────────────────────────────────────────────────────────────────
--  Funciones auxiliares de seguridad (RLS) usadas por las políticas de AUTH
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

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE usuario (
    id_usuario UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email_verificado BOOLEAN NOT NULL DEFAULT FALSE,
    intentos_fallidos INTEGER NOT NULL DEFAULT 0,
    bloqueado_hasta TIMESTAMPTZ NULL,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO'
        CHECK (estado IN ('ACTIVO', 'INACTIVO', 'SUSPENDIDO', 'BLOQUEADO')),
    tipo_usuario VARCHAR(20) NOT NULL
        CHECK (tipo_usuario IN ('CLIENTE', 'PROVEEDOR', 'ADMIN')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_usuario_email ON usuario(email);

CREATE INDEX idx_usuario_estado_tipo ON usuario(estado, tipo_usuario);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_usuario_updated_at
    BEFORE UPDATE ON usuario
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE usuario IS 'Entidad base que centraliza la autenticación y seguridad para todos los usuarios';
COMMENT ON COLUMN usuario.email IS 'Correo electrónico único para login y notificaciones';
COMMENT ON COLUMN usuario.password_hash IS 'Contraseña encriptada con bcrypt/argon2';
COMMENT ON COLUMN usuario.email_verificado IS 'Indica si el usuario verificó su correo electrónico';
COMMENT ON COLUMN usuario.intentos_fallidos IS 'Contador de intentos fallidos consecutivos de inicio de sesión';
COMMENT ON COLUMN usuario.bloqueado_hasta IS 'Fecha y hora hasta la cual la cuenta está bloqueada (NULL si no está bloqueada)';
COMMENT ON COLUMN usuario.estado IS 'Estado del usuario: ACTIVO, INACTIVO, SUSPENDIDO, BLOQUEADO';
COMMENT ON COLUMN usuario.tipo_usuario IS 'Rol del usuario: CLIENTE, PROVEEDOR o ADMIN';

CREATE TABLE cliente (
    id_usuario UUID PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(20) NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cliente_usuario 
        FOREIGN KEY (id_usuario) 
        REFERENCES usuario(id_usuario) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE
);

CREATE INDEX idx_cliente_nombre ON cliente(nombre);

CREATE TRIGGER trigger_cliente_updated_at
    BEFORE UPDATE ON cliente
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE cliente IS 'Especialización de USUARIO para personas naturales que utilizan la plataforma';
COMMENT ON COLUMN cliente.id_usuario IS 'Hereda PK de USUARIO (relación 1:1)';
COMMENT ON COLUMN cliente.nombre IS 'Nombre completo del cliente';
COMMENT ON COLUMN cliente.telefono IS 'Número de contacto';

CREATE TABLE proveedor (
    id_usuario UUID PRIMARY KEY,
    nombre_comercial VARCHAR(150) NOT NULL,
    id_categoria UUID NOT NULL,
    direccion VARCHAR(200) NULL,
    telefono_contacto VARCHAR(20) NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_proveedor_usuario 
        FOREIGN KEY (id_usuario) 
        REFERENCES usuario(id_usuario) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE
);

CREATE INDEX idx_proveedor_categoria ON proveedor(id_categoria);

CREATE INDEX idx_proveedor_nombre ON proveedor(nombre_comercial);

CREATE TRIGGER trigger_proveedor_updated_at
    BEFORE UPDATE ON proveedor
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE proveedor IS 'Especialización de USUARIO para negocios o profesionales que ofrecen servicios';
COMMENT ON COLUMN proveedor.id_usuario IS 'Hereda PK de USUARIO (relación 1:1)';
COMMENT ON COLUMN proveedor.nombre_comercial IS 'Nombre del negocio o profesional';
COMMENT ON COLUMN proveedor.id_categoria IS 'Referencia lógica a CATEGORIA_SERVICIO (MS-CATALOG-SERVICE) - validada vía Feign';
COMMENT ON COLUMN proveedor.direccion IS 'Ubicación física del proveedor';
COMMENT ON COLUMN proveedor.telefono_contacto IS 'Teléfono del establecimiento';

CREATE TABLE admin (
    id_usuario UUID PRIMARY KEY,
    nombre_completo VARCHAR(150) NOT NULL,
    codigo_empleado VARCHAR(50) NULL,
    telefono VARCHAR(20) NULL,
    fecha_asignacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_por UUID NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_admin_usuario 
        FOREIGN KEY (id_usuario) 
        REFERENCES usuario(id_usuario) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,

    CONSTRAINT fk_admin_creado_por 
        FOREIGN KEY (creado_por) 
        REFERENCES admin(id_usuario) 
        ON DELETE SET NULL 
        ON UPDATE CASCADE
);

CREATE INDEX idx_admin_nombre ON admin(nombre_completo);

CREATE INDEX idx_admin_codigo ON admin(codigo_empleado);

CREATE INDEX idx_admin_activo ON admin(activo) WHERE activo = TRUE;

CREATE TRIGGER trigger_admin_updated_at
    BEFORE UPDATE ON admin
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE admin IS 'Especialización de USUARIO para administradores con permisos completos del sistema';
COMMENT ON COLUMN admin.id_usuario IS 'Hereda PK de USUARIO (relación 1:1)';
COMMENT ON COLUMN admin.nombre_completo IS 'Nombre completo del administrador';
COMMENT ON COLUMN admin.codigo_empleado IS 'Código único de empleado (opcional)';
COMMENT ON COLUMN admin.telefono IS 'Número de contacto del administrador';
COMMENT ON COLUMN admin.fecha_asignacion IS 'Fecha en que se asignó el rol de administrador';
COMMENT ON COLUMN admin.activo IS 'Indica si el administrador está activo (TRUE) o inactivo (FALSE)';
COMMENT ON COLUMN admin.creado_por IS 'Referencia al administrador que creó este registro (auto auditoría)';

CREATE TABLE intento_login (
    id_intento UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NOT NULL,
    fecha_hora TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    exitoso BOOLEAN NOT NULL,
    direccion_ip VARCHAR(45) NOT NULL,
    info_dispositivo VARCHAR(255) NULL,
    mensaje_error VARCHAR(200) NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_intento_login_usuario 
        FOREIGN KEY (id_usuario) 
        REFERENCES usuario(id_usuario) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE
);

CREATE INDEX idx_intento_login_usuario ON intento_login(id_usuario);
CREATE INDEX idx_intento_login_fecha ON intento_login(fecha_hora);
CREATE INDEX idx_intento_login_exitoso ON intento_login(exitoso);
CREATE INDEX idx_intento_login_ip ON intento_login(direccion_ip);
CREATE INDEX idx_intento_login_usuario_fecha ON intento_login(id_usuario, fecha_hora DESC);

COMMENT ON TABLE intento_login IS 'Registro de auditoría de todos los intentos de inicio de sesión (exitosos y fallidos)';
COMMENT ON COLUMN intento_login.id_intento IS 'Identificador único del intento de login';
COMMENT ON COLUMN intento_login.id_usuario IS 'Referencia al usuario que intentó iniciar sesión';
COMMENT ON COLUMN intento_login.fecha_hora IS 'Fecha y hora del intento de login';
COMMENT ON COLUMN intento_login.exitoso IS 'TRUE = éxito, FALSE = fallido';
COMMENT ON COLUMN intento_login.direccion_ip IS 'Dirección IP desde la cual se intentó el acceso (IPv4/IPv6)';
COMMENT ON COLUMN intento_login.info_dispositivo IS 'Información del navegador/dispositivo utilizado';
COMMENT ON COLUMN intento_login.mensaje_error IS 'Descripción del error si el intento falló';

CREATE TABLE token_refresh (
    id_token UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NOT NULL,
    token VARCHAR(500) NOT NULL UNIQUE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion TIMESTAMPTZ NOT NULL,
    revocado BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_revocacion TIMESTAMPTZ NULL,
    info_dispositivo VARCHAR(255) NULL,
    direccion_ip VARCHAR(45) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_token_refresh_usuario 
        FOREIGN KEY (id_usuario) 
        REFERENCES usuario(id_usuario) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,

    CONSTRAINT chk_token_refresh_fechas 
        CHECK (fecha_expiracion > fecha_creacion),

    CONSTRAINT chk_token_refresh_revocacion 
        CHECK (fecha_revocacion IS NULL OR fecha_revocacion >= fecha_creacion)
);

CREATE INDEX idx_token_refresh_usuario ON token_refresh(id_usuario);
CREATE INDEX idx_token_refresh_token ON token_refresh(token);
CREATE INDEX idx_token_refresh_expiracion ON token_refresh(fecha_expiracion);
CREATE INDEX idx_token_refresh_revocado ON token_refresh(revocado);
CREATE INDEX idx_token_refresh_usuario_activo ON token_refresh(id_usuario, revocado, fecha_expiracion);

CREATE OR REPLACE FUNCTION limpiar_tokens_expirados()
RETURNS void AS $$
BEGIN
    DELETE FROM token_refresh
    WHERE fecha_expiracion < CURRENT_TIMESTAMP
    AND revocado = FALSE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE token_refresh IS 'Almacena los tokens de refresh para mantener sesiones activas de forma segura';
COMMENT ON COLUMN token_refresh.id_token IS 'Identificador único del token de refresh';
COMMENT ON COLUMN token_refresh.id_usuario IS 'Referencia al usuario propietario del token';
COMMENT ON COLUMN token_refresh.token IS 'Hash del token de refresh (valor único y seguro)';
COMMENT ON COLUMN token_refresh.fecha_creacion IS 'Fecha y hora de creación del token';
COMMENT ON COLUMN token_refresh.fecha_expiracion IS 'Fecha y hora de expiración del token';
COMMENT ON COLUMN token_refresh.revocado IS 'TRUE = token revocado, FALSE = activo';
COMMENT ON COLUMN token_refresh.fecha_revocacion IS 'Fecha y hora de revocación del token (NULL si no está revocado)';
COMMENT ON COLUMN token_refresh.info_dispositivo IS 'Información del dispositivo (navegador, SO, etc.)';
COMMENT ON COLUMN token_refresh.direccion_ip IS 'Dirección IP desde la cual se creó el token';

CREATE TABLE token_reset_password (
    id_token UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NOT NULL,
    token VARCHAR(255) NOT NULL UNIQUE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion TIMESTAMPTZ NOT NULL,
    usado BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_uso TIMESTAMPTZ NULL,
    direccion_ip_solicitud VARCHAR(45) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_token_reset_password_usuario 
        FOREIGN KEY (id_usuario) 
        REFERENCES usuario(id_usuario) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,

    CONSTRAINT chk_token_reset_password_fechas 
        CHECK (fecha_expiracion > fecha_creacion),

    CONSTRAINT chk_token_reset_password_uso 
        CHECK (fecha_uso IS NULL OR fecha_uso >= fecha_creacion),

    CONSTRAINT chk_token_reset_password_uso_expiracion 
        CHECK (fecha_uso IS NULL OR fecha_uso <= fecha_expiracion)
);

CREATE INDEX idx_token_reset_password_usuario ON token_reset_password(id_usuario);
CREATE INDEX idx_token_reset_password_token ON token_reset_password(token);
CREATE INDEX idx_token_reset_password_expiracion ON token_reset_password(fecha_expiracion);
CREATE INDEX idx_token_reset_password_usado ON token_reset_password(usado);
CREATE INDEX idx_token_reset_password_usuario_activo ON token_reset_password(id_usuario, usado, fecha_expiracion);

COMMENT ON TABLE token_reset_password IS 'Tokens temporales y de un solo uso para permitir la recuperación de contraseña de forma segura';
COMMENT ON COLUMN token_reset_password.id_token IS 'Identificador único del token de recuperación';
COMMENT ON COLUMN token_reset_password.id_usuario IS 'Referencia al usuario que solicitó el reset';
COMMENT ON COLUMN token_reset_password.token IS 'Token único y seguro para recuperación de contraseña';
COMMENT ON COLUMN token_reset_password.fecha_creacion IS 'Fecha y hora de creación del token';
COMMENT ON COLUMN token_reset_password.fecha_expiracion IS 'Fecha y hora de expiración del token (generalmente 1-24 horas)';
COMMENT ON COLUMN token_reset_password.usado IS 'TRUE = token ya utilizado, FALSE = disponible';
COMMENT ON COLUMN token_reset_password.fecha_uso IS 'Fecha y hora en que se utilizó el token (NULL si no se ha usado)';
COMMENT ON COLUMN token_reset_password.direccion_ip_solicitud IS 'Dirección IP desde la cual se solicitó el reset de contraseña';

CREATE TABLE email_verification_token (
    id_token UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NOT NULL UNIQUE,
    token VARCHAR(500) NOT NULL UNIQUE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion TIMESTAMPTZ NOT NULL,
    usado BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_email_verification_token_usuario 
        FOREIGN KEY (id_usuario) 
        REFERENCES usuario(id_usuario) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,

    CONSTRAINT chk_email_verification_token_fechas 
        CHECK (fecha_expiracion > fecha_creacion),

    CONSTRAINT chk_email_verification_token_expiracion_48h 
        CHECK (fecha_expiracion <= fecha_creacion + INTERVAL '48 hours')
);

CREATE INDEX idx_email_verification_token_usuario ON email_verification_token(id_usuario);
CREATE INDEX idx_email_verification_token_token ON email_verification_token(token);
CREATE INDEX idx_email_verification_token_expiracion ON email_verification_token(fecha_expiracion);
CREATE INDEX idx_email_verification_token_usado ON email_verification_token(usado);

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

COMMENT ON TABLE email_verification_token IS 'Tokens temporales y de un solo uso para permitir la verificación del correo electrónico de forma segura después del registro del usuario';
COMMENT ON COLUMN email_verification_token.id_token IS 'Identificador único del token de verificación';
COMMENT ON COLUMN email_verification_token.id_usuario IS 'Referencia al usuario que debe verificar su email (UNIQUE: un token activo por usuario)';
COMMENT ON COLUMN email_verification_token.token IS 'Token único y seguro para verificación de email';
COMMENT ON COLUMN email_verification_token.fecha_creacion IS 'Fecha y hora de creación del token';
COMMENT ON COLUMN email_verification_token.fecha_expiracion IS 'Fecha y hora de expiración del token (generalmente 24 horas desde creación)';
COMMENT ON COLUMN email_verification_token.usado IS 'TRUE = token ya utilizado, FALSE = disponible';

CREATE OR REPLACE VIEW vista_usuarios_completo AS
SELECT
    u.id_usuario,
    u.email,
    u.email_verificado,
    u.estado,
    u.tipo_usuario,
    u.fecha_registro,
    CASE
        WHEN u.tipo_usuario = 'CLIENTE' THEN c.nombre
        WHEN u.tipo_usuario = 'PROVEEDOR' THEN p.nombre_comercial
        WHEN u.tipo_usuario = 'ADMIN' THEN a.nombre_completo
    END AS nombre_completo,
    CASE
        WHEN u.tipo_usuario = 'CLIENTE' THEN c.telefono
        WHEN u.tipo_usuario = 'PROVEEDOR' THEN p.telefono_contacto
        WHEN u.tipo_usuario = 'ADMIN' THEN a.telefono
    END AS telefono
FROM usuario u
LEFT JOIN cliente c ON u.id_usuario = c.id_usuario
LEFT JOIN proveedor p ON u.id_usuario = p.id_usuario
LEFT JOIN admin a ON u.id_usuario = a.id_usuario;

CREATE OR REPLACE VIEW vista_tokens_activos AS
SELECT
    u.id_usuario,
    u.email,
    tr.id_token AS refresh_token_id,
    tr.fecha_expiracion AS refresh_expiracion,
    trp.id_token AS reset_token_id,
    trp.fecha_expiracion AS reset_expiracion,
    evt.id_token AS verification_token_id,
    evt.fecha_expiracion AS verification_expiracion
FROM usuario u
LEFT JOIN token_refresh tr ON u.id_usuario = tr.id_usuario AND tr.revocado = FALSE AND tr.fecha_expiracion > CURRENT_TIMESTAMP
LEFT JOIN token_reset_password trp ON u.id_usuario = trp.id_usuario AND trp.usado = FALSE AND trp.fecha_expiracion > CURRENT_TIMESTAMP
LEFT JOIN email_verification_token evt ON u.id_usuario = evt.id_usuario AND evt.usado = FALSE AND evt.fecha_expiracion > CURRENT_TIMESTAMP;

CREATE OR REPLACE VIEW vista_intentos_fallidos_recientes AS
SELECT
    u.id_usuario,
    u.email,
    COUNT(*) AS intentos_fallidos_count,
    MAX(il.fecha_hora) AS ultimo_intento,
    STRING_AGG(DISTINCT il.direccion_ip, ', ') AS ips_utilizadas
FROM usuario u
JOIN intento_login il ON u.id_usuario = il.id_usuario
WHERE il.exitoso = FALSE
    AND il.fecha_hora > CURRENT_TIMESTAMP - INTERVAL '1 hour'
GROUP BY u.id_usuario, u.email
HAVING COUNT(*) >= 5;

CREATE OR REPLACE VIEW vista_admins_activos AS
SELECT
    a.id_usuario,
    a.nombre_completo,
    a.codigo_empleado,
    a.telefono,
    a.fecha_asignacion,
    a.activo,
    u.email,
    u.estado
FROM admin a
JOIN usuario u ON a.id_usuario = u.id_usuario
WHERE a.activo = TRUE
ORDER BY a.fecha_asignacion DESC;

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

ALTER TABLE usuario ENABLE ROW LEVEL SECURITY;
ALTER TABLE cliente ENABLE ROW LEVEL SECURITY;
ALTER TABLE proveedor ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin ENABLE ROW LEVEL SECURITY;
ALTER TABLE intento_login ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_refresh ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_reset_password ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_verification_token ENABLE ROW LEVEL SECURITY;

ALTER TABLE usuario FORCE ROW LEVEL SECURITY;
ALTER TABLE cliente FORCE ROW LEVEL SECURITY;
ALTER TABLE proveedor FORCE ROW LEVEL SECURITY;
ALTER TABLE admin FORCE ROW LEVEL SECURITY;

CREATE POLICY "usuarios_pueden_ver_su_propio_perfil"
ON usuario
FOR SELECT
USING (
    id_usuario = auth.uid()
    OR
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "usuarios_pueden_actualizar_su_propio_perfil"
ON usuario
FOR UPDATE
USING (
    id_usuario = auth.uid()
)
WITH CHECK (
    id_usuario = auth.uid()
    AND email = email
    AND tipo_usuario = tipo_usuario
    AND fecha_registro = fecha_registro
);

CREATE POLICY "admin_puede_ver_todos_usuarios"
ON usuario
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_insertar_usuarios"
ON usuario
FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_eliminar_usuarios"
ON usuario
FOR DELETE
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "service_account_puede_actualizar_seguridad_usuario"
ON usuario
FOR UPDATE
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

CREATE POLICY "clientes_pueden_ver_su_propia_info"
ON cliente
FOR SELECT
USING (
    id_usuario = auth.uid()
    OR
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);

CREATE POLICY "clientes_pueden_actualizar_su_propia_info"
ON cliente
FOR UPDATE
USING (
    id_usuario = auth.uid()
)
WITH CHECK (
    id_usuario = id_usuario
);

CREATE POLICY "admin_puede_ver_todos_clientes"
ON cliente
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_backend_puede_insertar_clientes"
ON cliente
FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND (
            auth.users.raw_user_meta_data->>'role' = 'admin'
            OR auth.users.raw_user_meta_data->>'role' = 'service_account'
        )
    )
);

CREATE POLICY "proveedores_pueden_ver_su_propia_info"
ON proveedor
FOR SELECT
USING (
    id_usuario = auth.uid()
    OR
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);

CREATE POLICY "proveedores_pueden_actualizar_su_propia_info"
ON proveedor
FOR UPDATE
USING (
    id_usuario = auth.uid()
)
WITH CHECK (
    id_usuario = id_usuario
    AND id_categoria = id_categoria
);

CREATE POLICY "admin_puede_ver_todos_proveedores"
ON proveedor
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_verificar_proveedores"
ON proveedor
FOR UPDATE
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
)
WITH CHECK (
    TRUE
);

CREATE POLICY "admin_puede_ver_todos_admins"
ON admin
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_insertar_admins"
ON admin
FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_actualizar_admins"
ON admin
FOR UPDATE
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_superadmin_puede_eliminar_admins"
ON admin
FOR DELETE
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "service_account_admin_full_access"
ON admin
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

CREATE POLICY "usuarios_pueden_ver_sus_propios_tokens"
ON token_refresh
FOR SELECT
USING (
    id_usuario = auth.uid()
);

CREATE POLICY "sistema_puede_insertar_tokens"
ON token_refresh
FOR INSERT
WITH CHECK (
    TRUE
);

CREATE POLICY "usuarios_pueden_revocar_sus_tokens"
ON token_refresh
FOR UPDATE
USING (
    id_usuario = auth.uid()
)
WITH CHECK (
    id_usuario = id_usuario
    AND revocado = TRUE
);

CREATE POLICY "sistema_puede_eliminar_tokens_expirados"
ON token_refresh
FOR DELETE
USING (
    fecha_expiracion < NOW()
    OR revocado = TRUE
);

CREATE POLICY "usuarios_pueden_ver_sus_tokens_reset"
ON token_reset_password
FOR SELECT
USING (
    id_usuario = auth.uid()
);

CREATE POLICY "sistema_puede_crear_tokens_reset"
ON token_reset_password
FOR INSERT
WITH CHECK (
    TRUE
);

CREATE POLICY "usuarios_pueden_usar_su_token_reset"
ON token_reset_password
FOR UPDATE
USING (
    id_usuario = auth.uid()
    AND usado = FALSE
    AND fecha_expiracion > NOW()
)
WITH CHECK (
    id_usuario = id_usuario
    AND usado = TRUE
);

CREATE POLICY "usuarios_pueden_ver_su_token_verificacion"
ON email_verification_token
FOR SELECT
USING (
    id_usuario = auth.uid()
);

CREATE POLICY "sistema_puede_crear_tokens_verificacion"
ON email_verification_token
FOR INSERT
WITH CHECK (
    TRUE
);

CREATE POLICY "usuarios_pueden_verificar_su_email"
ON email_verification_token
FOR UPDATE
USING (
    id_usuario = auth.uid()
    AND usado = FALSE
    AND fecha_expiracion > NOW()
)
WITH CHECK (
    id_usuario = id_usuario
    AND usado = TRUE
);

CREATE POLICY "usuarios_pueden_ver_sus_intentos_login"
ON intento_login
FOR SELECT
USING (
    id_usuario = auth.uid()
);

CREATE POLICY "admin_puede_ver_todos_intentos_login"
ON intento_login
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'security')
    )
);

CREATE POLICY "sistema_puede_registrar_intentos_login"
ON intento_login
FOR INSERT
WITH CHECK (
    TRUE
);

CREATE POLICY "sistema_puede_limpiar_logs_antiguos"
ON intento_login
FOR DELETE
USING (
    fecha_hora < NOW() - INTERVAL '90 days'
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

CREATE POLICY "service_account_usuario_full_access"
ON usuario
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

CREATE POLICY "service_account_cliente_full_access"
ON cliente
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

CREATE POLICY "service_account_proveedor_full_access"
ON proveedor
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

CREATE POLICY "service_account_admin_full_access"
ON admin
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

CREATE POLICY "service_account_intento_login_full_access"
ON intento_login
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

CREATE POLICY "service_account_token_refresh_full_access"
ON token_refresh
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

CREATE POLICY "service_account_token_reset_password_full_access"
ON token_reset_password
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

CREATE POLICY "service_account_email_verification_token_full_access"
ON email_verification_token
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

CREATE TABLE public.registro_auditoria (
    id_registro UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre_tabla VARCHAR(100) NOT NULL,
    id_registro_afectado UUID NOT NULL,
    operacion VARCHAR(10) NOT NULL,
    modificado_por UUID REFERENCES auth.users(id),
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valores_anteriores JSONB,
    valores_nuevos JSONB,
    direccion_ip INET,
    agente_usuario TEXT
);

ALTER TABLE public.registro_auditoria ENABLE ROW LEVEL SECURITY;

CREATE POLICY "solo_admin_puede_ver_registro_auditoria"
ON public.registro_auditoria
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE INDEX idx_registro_auditoria_tabla_registro ON public.registro_auditoria(nombre_tabla, id_registro_afectado);
CREATE INDEX idx_registro_auditoria_fecha_mod ON public.registro_auditoria(fecha_modificacion DESC);
CREATE INDEX idx_registro_auditoria_modificado_por ON public.registro_auditoria(modificado_por);

COMMENT ON TABLE public.registro_auditoria IS 'Registro de auditoría de cambios en datos sensibles';
COMMENT ON COLUMN public.registro_auditoria.id_registro IS 'Identificador único del registro de auditoría';
COMMENT ON COLUMN public.registro_auditoria.nombre_tabla IS 'Nombre de la tabla modificada';
COMMENT ON COLUMN public.registro_auditoria.id_registro_afectado IS 'ID del registro que fue modificado';
COMMENT ON COLUMN public.registro_auditoria.operacion IS 'Tipo de operación (INSERT, UPDATE, DELETE)';
COMMENT ON COLUMN public.registro_auditoria.modificado_por IS 'Usuario que realizó el cambio (UUID de auth.users)';
COMMENT ON COLUMN public.registro_auditoria.fecha_modificacion IS 'Fecha y hora de la modificación';
COMMENT ON COLUMN public.registro_auditoria.valores_anteriores IS 'Valores antes del cambio (JSONB)';
COMMENT ON COLUMN public.registro_auditoria.valores_nuevos IS 'Valores después del cambio (JSONB)';
COMMENT ON COLUMN public.registro_auditoria.direccion_ip IS 'Dirección IP desde la cual se realizó el cambio';
COMMENT ON COLUMN public.registro_auditoria.agente_usuario IS 'Información del user agent/navegador';

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


CREATE INDEX IF NOT EXISTS idx_proveedor_categoria ON proveedor(id_categoria);

CREATE INDEX IF NOT EXISTS idx_proveedor_categoria_estado ON proveedor(id_categoria, id_usuario);

CREATE INDEX IF NOT EXISTS idx_intento_login_ip_fecha ON intento_login(direccion_ip, fecha_hora DESC);

CREATE INDEX IF NOT EXISTS idx_token_refresh_usuario_estado ON token_refresh(id_usuario, revocado, fecha_expiracion);

CREATE INDEX IF NOT EXISTS idx_token_reset_usuario_estado ON token_reset_password(id_usuario, usado, fecha_expiracion);

CREATE INDEX IF NOT EXISTS idx_email_verification_usuario ON email_verification_token(id_usuario, usado, fecha_expiracion);

CREATE INDEX IF NOT EXISTS idx_admin_usuario_estado ON admin(id_usuario, activo);

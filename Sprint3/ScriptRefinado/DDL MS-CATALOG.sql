-- ============================================================================
--  MS-CATALOG-SERVICE
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
--  HU: CRUD DE CATEGORÍAS  /  CRUD DE SERVICIOS
--  Triggers updated_at de ambas tablas.
-- ────────────────────────────────────────────────────────────────────────────

CREATE TRIGGER trigger_categoria_servicio_updated_at
    BEFORE UPDATE ON categoria_servicio
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_servicio_updated_at
    BEFORE UPDATE ON servicio
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- ────────────────────────────────────────────────────────────────────────────
--  HU: CONSULTAR SERVICIOS DE UN PROVEEDOR
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION obtener_servicios_por_proveedor(
    p_id_proveedor UUID,
    p_solo_activos BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    id_servicio UUID,
    nombre_servicio VARCHAR,
    duracion_minutos INTEGER,
    precio DECIMAL,
    descripcion VARCHAR,
    capacidad_maxima INTEGER,
    activo BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.id_servicio,
        s.nombre_servicio,
        s.duracion_minutos,
        s.precio,
        s.descripcion,
        s.capacidad_maxima,
        s.activo
    FROM servicio s
    WHERE s.id_proveedor = p_id_proveedor
    AND (p_solo_activos = FALSE OR s.activo = TRUE)
    ORDER BY s.nombre_servicio ASC;
END;
$$ LANGUAGE plpgsql;


-- ────────────────────────────────────────────────────────────────────────────
--  HU: ACTIVAR / DESACTIVAR SERVICIO (soft delete)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION desactivar_servicio(
    p_id_servicio UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE servicio
    SET activo = FALSE
    WHERE id_servicio = p_id_servicio AND activo = TRUE;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION activar_servicio(
    p_id_servicio UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE servicio
    SET activo = TRUE
    WHERE id_servicio = p_id_servicio AND activo = FALSE;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;


-- ────────────────────────────────────────────────────────────────────────────
--  Validación de existencia del proveedor (FK lógica a MS-AUTH vía Feign)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION validar_proveedor_existe(
    p_id_proveedor UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    -- La validación real se delega a la capa de servicio (Feign Client).
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


-- ────────────────────────────────────────────────────────────────────────────
--  Funciones auxiliares de seguridad (RLS) de CATALOG
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

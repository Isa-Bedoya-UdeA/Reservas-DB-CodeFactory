
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE categoria_servicio (
    id_categoria UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre_categoria VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(500) NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_categoria_servicio_nombre ON categoria_servicio(nombre_categoria);

CREATE INDEX idx_categoria_servicio_activa ON categoria_servicio(activa) WHERE activa = TRUE;

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_categoria_servicio_updated_at
    BEFORE UPDATE ON categoria_servicio
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE categoria_servicio IS 'Catálogo maestro de categorías de servicios disponibles en la plataforma';
COMMENT ON COLUMN categoria_servicio.id_categoria IS 'Identificador único de la categoría (UUID)';
COMMENT ON COLUMN categoria_servicio.nombre_categoria IS 'Nombre descriptivo de la categoría (ej: "Belleza y Spa", "Salud")';
COMMENT ON COLUMN categoria_servicio.descripcion IS 'Descripción detallada de la categoría y servicios que incluye';
COMMENT ON COLUMN categoria_servicio.activa IS 'Indica si la categoría está disponible para selección (TRUE = activa)';

CREATE TABLE servicio (
    id_servicio UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_proveedor UUID NOT NULL,
    nombre_servicio VARCHAR(100) NOT NULL,
    duracion_minutos INTEGER NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    descripcion VARCHAR(500) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    capacidad_maxima INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_servicio_duracion_positiva 
        CHECK (duracion_minutos > 0),

    CONSTRAINT chk_servicio_precio_positivo 
        CHECK (precio >= 0),

    CONSTRAINT chk_servicio_capacidad_positiva 
        CHECK (capacidad_maxima >= 0)
);

CREATE INDEX idx_servicio_proveedor ON servicio(id_proveedor);
CREATE INDEX idx_servicio_nombre ON servicio(nombre_servicio);
CREATE INDEX idx_servicio_activo ON servicio(activo) WHERE activo = TRUE;
CREATE INDEX idx_servicio_proveedor_activo ON servicio(id_proveedor, activo) WHERE activo = TRUE;

CREATE INDEX idx_servicio_proveedor_nombre ON servicio(id_proveedor, nombre_servicio);

CREATE INDEX idx_servicio_capacidad ON servicio(capacidad_maxima);

CREATE TRIGGER trigger_servicio_updated_at
    BEFORE UPDATE ON servicio
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE servicio IS 'Catálogo de servicios específicos ofrecidos por cada proveedor';
COMMENT ON COLUMN servicio.id_servicio IS 'Identificador único del servicio (UUID)';
COMMENT ON COLUMN servicio.id_proveedor IS 'Referencia lógica al proveedor que ofrece el servicio (MS-AUTH-SERVICE - validada vía Feign)';
COMMENT ON COLUMN servicio.nombre_servicio IS 'Nombre descriptivo del servicio (ej: "Corte de Cabello", "Consulta General")';
COMMENT ON COLUMN servicio.duracion_minutos IS 'Duración estimada del servicio en minutos (para agendamiento)';
COMMENT ON COLUMN servicio.precio IS 'Costo del servicio en pesos colombianos (COP)';
COMMENT ON COLUMN servicio.descripcion IS 'Descripción detallada del servicio, incluye lo que cubre';
COMMENT ON COLUMN servicio.activo IS 'Indica si el servicio está disponible para reserva (TRUE = activo)';
COMMENT ON COLUMN servicio.capacidad_maxima IS 'Número máximo de clientes que pueden atenderse simultáneamente (1 = individual, >1 = grupal)';

CREATE OR REPLACE VIEW vista_categorias_activas AS
SELECT
    id_categoria,
    nombre_categoria,
    descripcion,
    created_at
FROM categoria_servicio
WHERE activa = TRUE
ORDER BY nombre_categoria ASC;

CREATE OR REPLACE VIEW vista_servicios_activos AS
SELECT
    id_servicio,
    id_proveedor,
    nombre_servicio,
    duracion_minutos,
    precio,
    descripcion,
    capacidad_maxima,
    created_at
FROM servicio
WHERE activo = TRUE
ORDER BY nombre_servicio ASC;

CREATE OR REPLACE VIEW vista_estadisticas_servicios_proveedor AS
SELECT
    id_proveedor,
    COUNT(*) AS total_servicios,
    COUNT(*) FILTER (WHERE activo = TRUE) AS servicios_activos,
    COUNT(*) FILTER (WHERE activo = FALSE) AS servicios_inactivos,
    AVG(precio) AS precio_promedio,
    MIN(precio) AS precio_minimo,
    MAX(precio) AS precio_maximo,
    AVG(duracion_minutos) AS duracion_promedio
FROM servicio
GROUP BY id_proveedor;

CREATE OR REPLACE VIEW vista_servicios_grupales AS
SELECT
    id_servicio,
    id_proveedor,
    nombre_servicio,
    capacidad_maxima,
    precio,
    activo
FROM servicio
WHERE capacidad_maxima > 1
ORDER BY capacidad_maxima DESC;

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

CREATE OR REPLACE FUNCTION validar_proveedor_existe(
    p_id_proveedor UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

ALTER TABLE categoria_servicio ENABLE ROW LEVEL SECURITY;
ALTER TABLE servicio ENABLE ROW LEVEL SECURITY;

ALTER TABLE categoria_servicio FORCE ROW LEVEL SECURITY;
ALTER TABLE servicio FORCE ROW LEVEL SECURITY;

CREATE POLICY "categorias_activas_publicas"
ON categoria_servicio
FOR SELECT
USING (activa = TRUE);

CREATE POLICY "admin_puede_ver_todas_categorias"
ON categoria_servicio
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_insertar_categorias"
ON categoria_servicio
FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_actualizar_categorias"
ON categoria_servicio
FOR UPDATE
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_eliminar_categorias"
ON categoria_servicio
FOR DELETE
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "servicios_activos_publicos"
ON servicio
FOR SELECT
USING (activo = TRUE);

CREATE POLICY "proveedores_pueden_ver_sus_servicios"
ON servicio
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

CREATE POLICY "proveedores_pueden_crear_sus_servicios"
ON servicio
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

CREATE POLICY "proveedores_pueden_actualizar_sus_servicios"
ON servicio
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

CREATE POLICY "proveedores_pueden_desactivar_sus_servicios"
ON servicio
FOR UPDATE
USING (
    id_proveedor = auth.uid()
)
WITH CHECK (
    id_proveedor = id_proveedor
    AND activo = FALSE
);

CREATE POLICY "admin_puede_ver_todos_servicios"
ON servicio
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_eliminar_servicios"
ON servicio
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

CREATE POLICY "service_account_categoria_full_access"
ON categoria_servicio
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

CREATE POLICY "service_account_servicio_full_access"
ON servicio
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

CREATE INDEX IF NOT EXISTS idx_servicio_precio_rango ON servicio(precio);

CREATE INDEX IF NOT EXISTS idx_servicio_duracion ON servicio(duracion_minutos);

CREATE INDEX IF NOT EXISTS idx_servicio_proveedor_activo_precio ON servicio(id_proveedor, activo, precio);

INSERT INTO categoria_servicio (nombre_categoria, descripcion, activa) VALUES
('Belleza y Spa', 'Servicios de belleza, cuidado personal, spa y bienestar', TRUE),
('Salud', 'Servicios médicos, odontológicos, terapéuticos y de salud', TRUE),
('Deportes y Fitness', 'Gimnasios, entrenadores personales, clases deportivas', TRUE),
('Educación', 'Clases particulares, tutorías, cursos y capacitaciones', TRUE),
('Hogar', 'Servicios de limpieza, mantenimiento, reparaciones del hogar', TRUE),
('Tecnología', 'Soporte técnico, desarrollo de software, consultoría IT', TRUE),
('Eventos', 'Organización de eventos, fotografía, catering, música', TRUE),
('Mascotas', 'Veterinaria, peluquería canina, paseo de mascotas', TRUE),
('Transporte', 'Servicios de transporte, mudanzas, delivery', TRUE),
('Profesionales', 'Consultoría legal, contable, financiera y otros servicios profesionales', TRUE)
ON CONFLICT (nombre_categoria) DO NOTHING;

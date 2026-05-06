MS-CATALOG-SERVICE
--Tablas: categoria_servicio, servicio
--Q1. Crear Categoría de Servicio (INSERT)
--Solo un administrador puede ejecutar esta operación (controlado por RLS). El nombre es UNIQUE.
SQL:
INSERT INTO categoria_servicio (
    nombre_categoria,
    descripcion,
    activa
) VALUES (
    'Nutrición y Dietética',
    'Consultas con nutricionistas, planes alimenticios y seguimiento nutricional',
    TRUE
)
RETURNING id_categoria, nombre_categoria, created_at;

--Q2. Listar Categorías Activas (SELECT)
--Retorna todas las categorías disponibles para mostrar al usuario final o poblar un selector en el frontend.
SQL:
SELECT
    id_categoria,
    nombre_categoria,
    descripcion,
    created_at
FROM categoria_servicio
WHERE activa = TRUE
ORDER BY nombre_categoria ASC;
 
-- Alternativa usando la vista ya definida en el DDL:
-- SELECT * FROM vista_categorias_activas;

--Q3. Actualizar Categoría (UPDATE)
--Permite modificar el nombre, descripción o estado activo de una categoría. El trigger updated_at se dispara automáticamente.
SQL:
UPDATE categoria_servicio
SET
    nombre_categoria = 'Nutrición, Dietética y Bienestar',
    descripcion      = 'Consultas con nutricionistas certificados y seguimiento personalizado',
    activa           = TRUE
WHERE id_categoria = 'uuid-de-la-categoria'
RETURNING id_categoria, nombre_categoria, activa, updated_at;

--Q4. Desactivar Categoría (Soft Delete)
--En lugar de eliminar físicamente, se marca activa = FALSE. Preserva la integridad referencial con proveedores ya asociados.
SQL:
UPDATE categoria_servicio
SET activa = FALSE
WHERE id_categoria = 'uuid-de-la-categoria'
RETURNING id_categoria, nombre_categoria, activa, updated_at;
 
-- Verificación posterior:
SELECT id_categoria, nombre_categoria, activa
FROM  categoria_servicio
WHERE id_categoria = 'uuid-de-la-categoria';

--Q5. Crear Servicio (INSERT)
--El proveedor registra un nuevo servicio. El id_proveedor es FK lógica a MS-AUTH y debe validarse con Feign Client antes de insertar.
SQL:
INSERT INTO servicio (
    id_proveedor,
    nombre_servicio,
    duracion_minutos,
    precio,
    descripcion,
    activo,
    capacidad_maxima
) VALUES (
    'uuid-del-proveedor',
    'Masaje Relajante 60 min',
    60,
    120000.00,        -- COP
    'Masaje corporal completo con aceites esenciales, ideal para liberar tensiones',
    TRUE,
    1                 -- atención individual
)
RETURNING id_servicio, nombre_servicio, precio, created_at;

--Q6. Listar Servicios de un Proveedor (SELECT)
--Retorna todos los servicios activos de un proveedor específico. Usado por el panel del proveedor y la búsqueda del cliente.
SQL:
SELECT
    id_servicio,
    nombre_servicio,
    duracion_minutos,
    precio,
    descripcion,
    capacidad_maxima,
    created_at
FROM servicio
WHERE id_proveedor = 'uuid-del-proveedor'
  AND activo       = TRUE
ORDER BY nombre_servicio ASC;
 
-- Alternativa usando la función del DDL:
-- SELECT * FROM obtener_servicios_por_proveedor('uuid-del-proveedor', TRUE);

--Q7. Actualizar Servicio (UPDATE)
--Permite al proveedor actualizar precio, duración, descripción u otros campos de su servicio.
SQL:
UPDATE servicio
SET
    nombre_servicio  = 'Masaje Relajante Premium 60 min',
    precio           = 135000.00,
    descripcion      = 'Masaje corporal completo con aceites esenciales premium y aromaterapia',
    duracion_minutos = 70
WHERE id_servicio  = 'uuid-del-servicio'
  AND id_proveedor = 'uuid-del-proveedor'   -- seguridad: solo el dueño puede modificar
RETURNING id_servicio, nombre_servicio, precio, duracion_minutos, updated_at;

--Q8. Desactivar Servicio (Soft Delete)
--Marca el servicio como inactivo sin eliminarlo. Preserva el historial de reservas ya asociadas a ese servicio.
SQL:
-- Opción A: UPDATE directo
UPDATE servicio
SET activo = FALSE
WHERE id_servicio  = 'uuid-del-servicio'
  AND id_proveedor = 'uuid-del-proveedor'
RETURNING id_servicio, nombre_servicio, activo, updated_at;
 
-- Opción B: Usando la función del DDL
SELECT desactivar_servicio('uuid-del-servicio');
 
-- Reactivar si es necesario:
SELECT activar_servicio('uuid-del-servicio');

--Q9. Estadísticas de Servicios por Proveedor (Reporte)
--Reporte agregado del catálogo de un proveedor: total de servicios, activos/inactivos, precio promedio, mínimo y máximo.
SQL:
SELECT
    id_proveedor,
    total_servicios,
    servicios_activos,
    servicios_inactivos,
    ROUND(precio_promedio, 0)  AS precio_promedio_cop,
    precio_minimo,
    precio_maximo,
    ROUND(duracion_promedio, 0) AS duracion_promedio_min
FROM vista_estadisticas_servicios_proveedor
WHERE id_proveedor = 'uuid-del-proveedor';
 
-- Para todos los proveedores (vista global — solo ADMIN):
SELECT * FROM vista_estadisticas_servicios_proveedor
ORDER BY total_servicios DESC;

MS-AUTH-SERVICE
--Tablas: usuario, cliente, proveedor, intento_login, token_refresh
--Q1. Registro de Cliente
--Inserta el usuario base y el perfil de cliente en una transacción. El password_hash debe llegar ya cifrado desde la capa de servicio (bcrypt/argon2).
SQL:
-- PASO 1: Insertar usuario base
INSERT INTO usuario (
    email,
    password_hash,
    email_verificado,
    estado,
    tipo_usuario
) VALUES (
    'juan.perez@email.com',
    '$2a$12$hash_bcrypt_aqui',   -- hash generado por el servicio
    FALSE,
    'ACTIVO',
    'CLIENTE'
);
 
-- PASO 2: Insertar perfil de cliente (usa el mismo UUID)
INSERT INTO cliente (
    id_usuario,
    nombre,
    telefono
)
SELECT
    id_usuario,
    'Juan Pérez',
    '+57 311 234 5678'
FROM usuario
WHERE email = 'juan.perez@email.com';
 
-- PASO 3: Crear token de verificación de email
INSERT INTO email_verification_token (
    id_usuario,
    token,
    fecha_expiracion
)
SELECT
    id_usuario,
    encode(gen_random_bytes(64), 'hex'),   -- token seguro aleatorio
    CURRENT_TIMESTAMP + INTERVAL '24 hours'
FROM usuario
WHERE email = 'juan.perez@email.com';

--Q2. Registro de Proveedor
--Inserta el usuario base y el perfil del proveedor. El id_categoria es una FK lógica hacia MS-CATALOG y debe validarse vía Feign Client antes de ejecutar este INSERT.
SQL:
-- PASO 1: Insertar usuario base
INSERT INTO usuario (
    email,
    password_hash,
    email_verificado,
    estado,
    tipo_usuario
) VALUES (
    'spa.zen@proveedores.com',
    '$2a$12$hash_bcrypt_aqui',
    FALSE,
    'ACTIVO',
    'PROVEEDOR'
);
 
-- PASO 2: Insertar perfil de proveedor
INSERT INTO proveedor (
    id_usuario,
    nombre_comercial,
    id_categoria,
    direccion,
    telefono_contacto
)
SELECT
    id_usuario,
    'Spa Zen Medellín',
    'uuid-de-categoria-belleza',   -- validado previamente vía Feign
    'Calle 10 # 43-55, El Poblado, Medellín',
    '+57 604 321 0000'
FROM usuario
WHERE email = 'spa.zen@proveedores.com';
 
-- PASO 3: Token de verificación de email
INSERT INTO email_verification_token (
    id_usuario,
    token,
    fecha_expiracion
)
SELECT
    id_usuario,
    encode(gen_random_bytes(64), 'hex'),
    CURRENT_TIMESTAMP + INTERVAL '24 hours'
FROM usuario
WHERE email = 'spa.zen@proveedores.com';

--Q3. Login — Validación de Credenciales
--Obtiene los datos necesarios para que la capa de servicio valide el password_hash (con bcrypt.verify). Si la validación es exitosa, se registra el intento y se crea el token de refresh.
SQL:
-- PASO 1: Obtener datos del usuario para validación
SELECT
    u.id_usuario,
    u.email,
    u.password_hash,
    u.email_verificado,
    u.estado,
    u.tipo_usuario,
    u.intentos_fallidos,
    u.bloqueado_hasta,
    CASE
        WHEN u.tipo_usuario = 'CLIENTE'   THEN c.nombre
        WHEN u.tipo_usuario = 'PROVEEDOR' THEN p.nombre_comercial
        WHEN u.tipo_usuario = 'ADMIN'     THEN a.nombre_completo
    END AS nombre_display
FROM usuario u
LEFT JOIN cliente  c ON u.id_usuario = c.id_usuario
LEFT JOIN proveedor p ON u.id_usuario = p.id_usuario
LEFT JOIN admin    a ON u.id_usuario = a.id_usuario
WHERE u.email = 'juan.perez@email.com';
 
-- PASO 2: Registrar intento de login (exitoso o fallido)
INSERT INTO intento_login (
    id_usuario,
    exitoso,
    direccion_ip,
    info_dispositivo,
    mensaje_error
) VALUES (
    'uuid-del-usuario',
    TRUE,              -- FALSE si las credenciales fueron incorrectas
    '190.85.100.45',
    'Mozilla/5.0 Chrome/124 ...',
    NULL               -- mensaje de error si exitoso = FALSE
);
 
-- PASO 3: Si login exitoso → crear token de refresh
INSERT INTO token_refresh (
    id_usuario,
    token,
    fecha_expiracion,
    info_dispositivo,
    direccion_ip
) VALUES (
    'uuid-del-usuario',
    encode(gen_random_bytes(64), 'hex'),
    CURRENT_TIMESTAMP + INTERVAL '7 days',
    'Mozilla/5.0 Chrome/124 ...',
    '190.85.100.45'
);


--Q4. Consulta de Seguridad — Usuarios con Intentos Fallidos Recientes
--Detecta usuarios con 5 o más intentos fallidos en la última hora, útil para trigger de bloqueo automático.
SQL:
SELECT
    u.id_usuario,
    u.email,
    u.estado,
    u.intentos_fallidos,
    u.bloqueado_hasta,
    COUNT(il.id_intento)         AS intentos_ultima_hora,
    MAX(il.fecha_hora)           AS ultimo_intento_fallido,
    STRING_AGG(DISTINCT il.direccion_ip, ', ')  AS ips_origen
FROM usuario u
JOIN intento_login il
    ON u.id_usuario = il.id_usuario
   AND il.exitoso   = FALSE
   AND il.fecha_hora > CURRENT_TIMESTAMP - INTERVAL '1 hour'
GROUP BY
    u.id_usuario, u.email, u.estado,
    u.intentos_fallidos, u.bloqueado_hasta
HAVING COUNT(il.id_intento) >= 5
ORDER BY intentos_ultima_hora DESC;

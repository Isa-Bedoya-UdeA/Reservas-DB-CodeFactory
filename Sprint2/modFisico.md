# Modelo Físico - Plataforma de Reservas de Servicios

**Arquitectura de Microservicios** | **UUID como identificador único** | **PostgreSQL + Supabase**

---

## MS-AUTH-SERVICE

Gestión centralizada de autenticación, usuarios y autorización.

### USUARIO

| Columna | Tipo | Constraint |
| ------- | ---- | ---------- |
| id_usuario | UUID | **PK**, DEFAULT gen_random_uuid() |
| email | VARCHAR(100) | **UNIQUE**, NOT NULL |
| password_hash | VARCHAR(255) | NOT NULL |
| email_verificado | BOOLEAN | NOT NULL, DEFAULT FALSE |
| intentos_fallidos | INTEGER | NOT NULL, DEFAULT 0 |
| bloqueado_hasta | TIMESTAMPTZ | NULL |
| fecha_registro | TIMESTAMPTZ | NOT NULL, DEFAULT CURRENT_TIMESTAMP |
| estado | VARCHAR(20) | **CHECK** (ACTIVO\|INACTIVO\|SUSPENDIDO\|BLOQUEADO), DEFAULT ACTIVO |
| tipo_usuario | VARCHAR(20) | **CHECK** (CLIENTE\|PROVEEDOR\|ADMIN) |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Índices:** idx_usuario_email, idx_usuario_estado_tipo  
**Dimensión:** ~12 columnas | ~1KB/registro

---

### CLIENTE

| Columna | Tipo | Constraint |
| ------- | ---- | --------- |
| id_usuario | UUID | **PK, FK** → usuario(id_usuario), CASCADE |
| nombre | VARCHAR(100) | NOT NULL |
| telefono | VARCHAR(20) | NULL |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Índices:** idx_cliente_nombre  
**Dimensión:** 5 columnas | ~500B/registro | Hereda de USUARIO (1:1)

---

### PROVEEDOR

| Columna | Tipo | Constraint |
| ------- | ---- | --------- |
| id_usuario | UUID | **PK, FK** → usuario(id_usuario), CASCADE |
| nombre_comercial | VARCHAR(150) | NOT NULL |
| id_categoria | UUID | NOT NULL (FK lógica a MS-CATALOG) |
| direccion | VARCHAR(200) | NULL |
| telefono_contacto | VARCHAR(20) | NULL |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Índices:** idx_proveedor_categoria, idx_proveedor_nombre  
**Dimensión:** 7 columnas | ~700B/registro | Hereda de USUARIO (1:1)

---

### ADMIN

| Columna | Tipo | Constraint |
| ------- | ---- | --------- |
| id_usuario | UUID | **PK, FK** → usuario(id_usuario), CASCADE |
| nombre_completo | VARCHAR(150) | NOT NULL |
| codigo_empleado | VARCHAR(50) | NULL |
| telefono | VARCHAR(20) | NULL |
| fecha_asignacion | TIMESTAMPTZ | NOT NULL, DEFAULT CURRENT_TIMESTAMP |
| activo | BOOLEAN | NOT NULL, DEFAULT TRUE |
| creado_por | UUID | **FK** → admin(id_usuario), SET NULL |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Índices:** idx_admin_nombre, idx_admin_codigo, idx_admin_activo  
**Dimensión:** 9 columnas | ~900B/registro | Hereda de USUARIO (1:1) | Autorreferencia

---

### INTENTO_LOGIN

| Columna | Tipo | Constraint |
| ------- | ---- | --------- |
| id_intento | UUID | **PK**, DEFAULT gen_random_uuid() |
| id_usuario | UUID | NOT NULL, **FK** → usuario(id_usuario), CASCADE |
| fecha_hora | TIMESTAMPTZ | NOT NULL, DEFAULT CURRENT_TIMESTAMP |
| exitoso | BOOLEAN | NOT NULL |
| direccion_ip | VARCHAR(45) | NOT NULL |
| info_dispositivo | VARCHAR(255) | NULL |
| mensaje_error | VARCHAR(200) | NULL |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Índices:** idx_intento_login_usuario, idx_intento_login_fecha, idx_intento_login_exitoso, idx_intento_login_ip  
**Dimensión:** 8 columnas | ~600B/registro | Auditoría (sin límite de crecimiento)

---

### TOKEN_REFRESH

| Columna | Tipo | Constraint |
| ------- | ---- | --------- |
| id_token | UUID | **PK**, DEFAULT gen_random_uuid() |
| id_usuario | UUID | NOT NULL, **FK** → usuario(id_usuario), CASCADE |
| token | VARCHAR(500) | NOT NULL, **UNIQUE** |
| fecha_creacion | TIMESTAMPTZ | NOT NULL, DEFAULT CURRENT_TIMESTAMP |
| fecha_expiracion | TIMESTAMPTZ | NOT NULL |
| revocado | BOOLEAN | NOT NULL, DEFAULT FALSE |
| fecha_revocacion | TIMESTAMPTZ | NULL |
| info_dispositivo | VARCHAR(255) | NULL |
| direccion_ip | VARCHAR(45) | NOT NULL |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Constraints:** CHECK fecha_expiracion > fecha_creacion | CHECK fecha_revocacion IS NULL OR fecha_revocacion >= fecha_creacion  
**Índices:** idx_token_refresh_usuario, idx_token_refresh_token, idx_token_refresh_expiracion, idx_token_refresh_revocado  
**Dimensión:** 10 columnas | ~1KB/registro

---

### TOKEN_RESET_PASSWORD

| Columna | Tipo | Constraint |
| ------- | ---- | --------- |
| id_token | UUID | **PK**, DEFAULT gen_random_uuid() |
| id_usuario | UUID | NOT NULL, **FK** → usuario(id_usuario), CASCADE |
| token | VARCHAR(255) | NOT NULL, **UNIQUE** |
| fecha_creacion | TIMESTAMPTZ | NOT NULL, DEFAULT CURRENT_TIMESTAMP |
| fecha_expiracion | TIMESTAMPTZ | NOT NULL |
| usado | BOOLEAN | NOT NULL, DEFAULT FALSE |
| fecha_uso | TIMESTAMPTZ | NULL |
| direccion_ip_solicitud | VARCHAR(45) | NOT NULL |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Constraints:** CHECK fecha_expiracion > fecha_creacion | CHECK fecha_uso IS NULL OR fecha_uso >= fecha_creacion  
**Índices:** idx_token_reset_password_usuario, idx_token_reset_password_token, idx_token_reset_password_expiracion  
**Dimensión:** 9 columnas | ~900B/registro

---

### EMAIL_VERIFICATION_TOKEN

| Columna | Tipo | Constraint |
| ------- | ---- | --------- |
| id_token | UUID | **PK**, DEFAULT gen_random_uuid() |
| id_usuario | UUID | NOT NULL, **UNIQUE**, **FK** → usuario(id_usuario), CASCADE |
| token | VARCHAR(500) | NOT NULL, **UNIQUE** |
| fecha_creacion | TIMESTAMPTZ | NOT NULL, DEFAULT CURRENT_TIMESTAMP |
| fecha_expiracion | TIMESTAMPTZ | NOT NULL |
| usado | BOOLEAN | NOT NULL, DEFAULT FALSE |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Constraints:** CHECK fecha_expiracion > fecha_creacion | CHECK fecha_expiracion <= fecha_creacion + INTERVAL '48 hours'  
**Índices:** idx_email_verification_token_usuario, idx_email_verification_token_token  
**Dimensión:** 8 columnas | ~800B/registro

---

## MS-CATALOG-SERVICE

Catálogo de categorías de servicios y servicios disponibles.

### CATEGORIA_SERVICIO

| Columna | Tipo | Constraint |
| ------- | ---- | ---------- |
| id_categoria | UUID | **PK**, DEFAULT gen_random_uuid() |
| nombre_categoria | VARCHAR(100) | NOT NULL, **UNIQUE** |
| descripcion | VARCHAR(500) | NULL |
| activa | BOOLEAN | NOT NULL, DEFAULT TRUE |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Índices:** idx_categoria_servicio_nombre, idx_categoria_servicio_activa  
**Dimensión:** 6 columnas | ~400B/registro | Datos maestros (crecimiento controlado)

---

### SERVICIO

| Columna | Tipo | Constraint |
| ------- | ---- | ---------- |
| id_servicio | UUID | **PK**, DEFAULT gen_random_uuid() |
| id_proveedor | UUID | NOT NULL (FK lógica a MS-AUTH proveedor) |
| nombre_servicio | VARCHAR(100) | NOT NULL |
| duracion_minutos | INTEGER | NOT NULL, **CHECK** > 0 |
| precio | DECIMAL(10,2) | NOT NULL, **CHECK** >= 0 |
| descripcion | VARCHAR(500) | NULL |
| activo | BOOLEAN | NOT NULL, DEFAULT TRUE |
| capacidad_maxima | INTEGER | NOT NULL, DEFAULT 1, **CHECK** >= 0 |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Índices:** idx_servicio_proveedor, idx_servicio_nombre, idx_servicio_activo, idx_servicio_proveedor_activo, idx_servicio_capacidad  
**Dimensión:** 10 columnas | ~900B/registro

---

## MS-SCHEDULE-SERVICE

Gestión de empleados, horarios laborales y bloqueos de tiempo.

### EMPLEADO

| Columna | Tipo | Constraint |
| ------- | ---- | ---------- |
| id_empleado | UUID | **PK**, DEFAULT gen_random_uuid() |
| id_proveedor | UUID | NOT NULL (FK lógica a MS-AUTH proveedor) |
| nombre_completo | VARCHAR(150) | NOT NULL |
| telefono | VARCHAR(20) | NULL |
| activo | BOOLEAN | NOT NULL, DEFAULT TRUE |
| fecha_contratacion | TIMESTAMPTZ | NULL |
| notas | VARCHAR(500) | NULL |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Índices:** idx_empleado_proveedor, idx_empleado_nombre, idx_empleado_proveedor_activo  
**Dimensión:** 9 columnas | ~700B/registro

---

### EMPLEADO_SERVICIO

| Columna | Tipo | Constraint |
| ------- | ---- | ---------- |
| id_empleado_servicio | UUID | **PK**, DEFAULT gen_random_uuid() |
| id_empleado | UUID | NOT NULL, **FK** → empleado(id_empleado), CASCADE |
| id_servicio | UUID | NOT NULL (FK lógica a MS-CATALOG) |
| activo | BOOLEAN | NOT NULL, DEFAULT TRUE |
| fecha_asignacion | TIMESTAMPTZ | NOT NULL, DEFAULT CURRENT_TIMESTAMP |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Índices:** idx_empleado_servicio_empleado, idx_empleado_servicio_servicio, idx_empleado_servicio_activo  
**Dimensión:** 7 columnas | ~600B/registro | Relación M:N

---

### HORARIO_LABORAL

| Columna | Tipo | Constraint |
| ------- | ---- | --------- |
| id_horario | UUID | **PK**, DEFAULT gen_random_uuid() |
| id_empleado | UUID | NOT NULL, **FK** → empleado(id_empleado), CASCADE |
| dia_semana | VARCHAR(10) | NOT NULL, **CHECK** (LUNES\|MARTES\|MIERCOLES\|JUEVES\|VIERNES\|SABADO\|DOMINGO) |
| hora_inicio | TIME | NOT NULL |
| hora_fin | TIME | NOT NULL |
| activo | BOOLEAN | NOT NULL, DEFAULT TRUE |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Constraints:** CHECK hora_fin > hora_inicio  
**Índices:** idx_horario_laboral_empleado, idx_horario_laboral_dia_semana, idx_horario_laboral_empleado_dia_activo  
**Dimensión:** 8 columnas | ~500B/registro | Horarios recurrentes (semanal)

---

### BLOQUEO_HORARIO

| Columna | Tipo | Constraint |
| ------- | ---- | --------- |
| id_bloqueo | UUID | **PK**, DEFAULT gen_random_uuid() |
| id_empleado | UUID | NOT NULL, **FK** → empleado(id_empleado), CASCADE |
| id_reserva | UUID | NULL (FK lógica a MS-RESERVATION) |
| fecha | DATE | NOT NULL |
| hora_inicio | TIME | NOT NULL |
| hora_fin | TIME | NOT NULL |
| tipo_bloqueo | VARCHAR(20) | NOT NULL, **CHECK** (RESERVA\|VACACIONES\|PERMISO\|ADMINISTRATIVO), DEFAULT RESERVA |
| activo | BOOLEAN | NOT NULL, DEFAULT TRUE |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Constraints:** CHECK hora_fin > hora_inicio  
**Índices:** idx_bloqueo_horario_empleado_fecha, idx_bloqueo_horario_fecha, idx_bloqueo_horario_empleado_fecha_activo, idx_bloqueo_horario_reserva  
**Dimensión:** 10 columnas | ~800B/registro | Bloqueos por fecha específica

---

## MS-RESERVATION-SERVICE

Gestión de reservas y citas.

### RESERVA

| Columna | Tipo | Constraint |
| ------- | ---- | ---------- |
| id_reserva | UUID | **PK**, DEFAULT gen_random_uuid() |
| id_cliente | UUID | NOT NULL (FK lógica a MS-AUTH cliente) |
| id_servicio | UUID | NOT NULL (FK lógica a MS-CATALOG servicio) |
| id_empleado | UUID | NOT NULL (FK lógica a MS-SCHEDULE empleado) |
| id_proveedor | UUID | NOT NULL (FK lógica a MS-AUTH proveedor) |
| fecha_hora_inicio | TIMESTAMPTZ | NOT NULL |
| fecha_hora_fin | TIMESTAMPTZ | NOT NULL |
| estado | VARCHAR(20) | NOT NULL, **CHECK** (PENDIENTE\|CONFIRMADA\|EN_PROGRESO\|COMPLETADA\|CANCELADA\|NO_SHOW), DEFAULT PENDIENTE |
| fecha_creacion | TIMESTAMPTZ | NOT NULL, DEFAULT CURRENT_TIMESTAMP |
| fecha_cancelacion | TIMESTAMPTZ | NULL |
| comentarios | VARCHAR(500) | NULL |
| created_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMPTZ | DEFAULT CURRENT_TIMESTAMP |

**Constraints:** CHECK fecha_hora_fin > fecha_hora_inicio | CHECK fecha_cancelacion IS NULL OR fecha_cancelacion >= fecha_creacion  
**Índices:** idx_reserva_cliente, idx_reserva_empleado, idx_reserva_proveedor, idx_reserva_servicio, idx_reserva_estado, idx_reserva_fecha_inicio, idx_reserva_cliente_estado, idx_reserva_empleado_fecha, idx_reserva_proveedor_estado, idx_reserva_validacion_horario  
**Dimensión:** 13 columnas | ~1.2KB/registro | Transaccional (crecimiento alto)

---

## Resumen de Dimensiones

| Microservicio | Tablas | Total Columnas | Carácter |
| ------------- | ------ | -------------- | -------- |
| MS-AUTH | 7 | 66 | Autenticación y perfiles |
| MS-CATALOG | 2 | 16 | Maestros |
| MS-SCHEDULE | 4 | 34 | Gestión de empleados y disponibilidad |
| MS-RESERVATION | 1 | 13 | Transaccional (alto volumen) |
| **Total** | **14** | **129** | **Sistema Integral** |

---

## Notas de Diseño

- **FK Lógicas:** Referencias entre microservicios validadas vía OpenFeign en backend (no FK físicas)
- **FK Físicas:** Solo dentro del mismo microservicio (cascada en deletes)
- **UUIDs:** Identificadores distribuidos para escalabilidad
- **Auditoría:** created_at, updated_at en todas las tablas
- **RLS:** Row Level Security habilitado en Supabase para control granular
- **Índices:** Optimizados para consultas frecuentes y validaciones

# Refinamiento del Análisis de Volumen de Datos

Microservicios: MS-AUTH · MS-CATALOG · MS-SCHEDULE · MS-RESERVATION  

---

## 1. Metodología de Cálculo

El análisis se realiza por cada entidad (tabla) siguiendo cuatro pasos. Todos los tamaños de tipo de dato y las proyecciones de tuplas fueron verificados contra los scripts DDL reales de cada microservicio.

**Paso 1 — Longitud estimada del registro (L):**

```
L = 4 × n_var  +  Σ size(campos_fijos)  +  size(mapa_bits)  +  23  +  Σ size(campos_var)
```

**Paso 2 — Factor de almacenamiento (F_R), registros por página:**

```
F_R = ⌊ (P − espacio_control) / (L + 4) ⌋  =  ⌊ (8192 − 100) / (L + 4) ⌋
```

**Paso 3 — Proyección de tuplas (T_R):**

```
T_R = carga inicial + crecimiento estimado a 5 años
```

**Paso 4 — Número de páginas (B_R) y volumen total:**

```
B_R = ⌈ T_R / F_R ⌉          Volumen = B_R × 8.192 bytes
```

**Convenciones de tamaño usadas:**

- Tipos fijos: UUID = 16 B · INTEGER = 4 B · BOOLEAN = 1 B · TIMESTAMPTZ = 8 B · DATE = 4 B · TIME = 4 B · DECIMAL(10,2) = 8 B · INET = 19 B.
- Tipos variables (VARCHAR(n)): se estiman como **n + 4 bytes** (contenido + cabecera de longitud).
- Tipos JSONB / TEXT: estimados en ≈200 B promedio por campo según el contenido esperado.
- Mapa de bits de nulos: 1 byte por cada 8 columnas que admiten NULL.

---

## 2. Resumen Global del Sistema

Consolidado del volumen proyectado a 5 años por microservicio:

| Microservicio | Tablas | T_R Total | B_R Total | Volumen |
|---|---|---|---|---|
| **MS-AUTH-SERVICE** | 9 | 97.820 | 8.344 | 65.19 MB |
| **MS-CATALOG-SERVICE** | 2 | 8.050 | 733 | 5.73 MB |
| **MS-SCHEDULE-SERVICE** | 4 | 252.000 | 4.339 | 33.90 MB |
| **MS-RESERVATION-SERVICE** | 1 | 300.000 | 27.273 | 213.07 MB |
| **TOTAL SISTEMA** | **16** | **657.870** | **40.689** | **317.88 MB** |

**Observaciones del refinamiento:**

- **MS-RESERVATION** concentra la mayor parte del volumen (≈213 MB) debido a la tabla transaccional `reserva`. Es la candidata prioritaria a particionado por rango de fecha.
- En **MS-SCHEDULE**, `bloqueo_horario` crece de forma proporcional a las reservas (una entrada por cita), siendo la segunda tabla más pesada del sistema.
- En **MS-AUTH**, las tablas de auditoría (`intento_login` y `registro_auditoria`) dominan el volumen; se recomienda una política de retención/purga para acotar su crecimiento.
- Las tablas maestras (`categoria_servicio`, `admin`) tienen volumen despreciable y no requieren optimización.

---

## 3. MS-AUTH-SERVICE

*Tablas analizadas: usuario · cliente · proveedor · admin · intento_login · token_refresh · token_reset_password · email_verification_token · registro_auditoria*

### Resumen del microservicio

| Tabla | T_R | L (B) | F_R | B_R | Volumen |
|---|---|---|---|---|---|
| `usuario` | 5.000 | 504 | 15 | 334 | 2.61 MB |
| `cliente` | 4.000 | 192 | 41 | 98 | 0.77 MB |
| `proveedor` | 800 | 466 | 17 | 48 | 0.38 MB |
| `admin` | 20 | 325 | 24 | 1 | 0.01 MB |
| `intento_login` | 50.000 | 597 | 13 | 3.847 | 30.05 MB |
| `token_refresh` | 10.000 | 913 | 8 | 1.250 | 9.77 MB |
| `token_reset_password` | 3.000 | 405 | 19 | 158 | 1.23 MB |
| `email_verification_token` | 5.000 | 596 | 13 | 385 | 3.01 MB |
| `registro_auditoria` | 20.000 | 837 | 9 | 2.223 | 17.37 MB |
| **TOTAL** | — | — | — | **8.344** | **65.19 MB** |

### Detalle de cálculo por tabla

#### Tabla: `usuario`

*Justificación de T_R: 5.000 usuarios totales (clientes + proveedores + admins) proyectados a 5 años.*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_usuario` | UUID | 16 | No | No |
| `email` | VARCHAR(100) | 104 | Sí | No |
| `password_hash` | VARCHAR(255) | 259 | Sí | No |
| `email_verificado` | BOOLEAN | 1 | No | No |
| `intentos_fallidos` | INTEGER | 4 | No | No |
| `bloqueado_hasta` | TIMESTAMPTZ | 8 | No | Sí |
| `fecha_registro` | TIMESTAMPTZ | 8 | No | No |
| `estado` | VARCHAR(20) | 24 | Sí | No |
| `tipo_usuario` | VARCHAR(20) | 24 | Sí | No |
| `created_at` | TIMESTAMPTZ | 8 | No | No |
| `updated_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 4 | 16 bytes |
| Campos fijos | Σ size(campos fijos) | 53 bytes |
| Mapa de bits | 1 NULL → ⌈1/8⌉ | 1 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 411 bytes |
| **L** | 16 + 53 + 1 + 23 + 411 | **504 bytes** |
| F_R | ⌊(8192−100)/(504+4)⌋ = ⌊8092/508⌋ | 15 |
| T_R (5 años) | Proyección de carga | 5.000 |
| B_R | ⌈5.000 / 15⌉ | 334 págs. |
| **Volumen** | 334 × 8.192 B | **2.61 MB** |

#### Tabla: `cliente`

*Justificación de T_R: Aproximadamente el 80% de los usuarios son clientes (4.000 de 5.000).*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_usuario` | UUID | 16 | No | No |
| `nombre` | VARCHAR(100) | 104 | Sí | No |
| `telefono` | VARCHAR(20) | 24 | Sí | Sí |
| `created_at` | TIMESTAMPTZ | 8 | No | No |
| `updated_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 2 | 8 bytes |
| Campos fijos | Σ size(campos fijos) | 32 bytes |
| Mapa de bits | 1 NULL → ⌈1/8⌉ | 1 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 128 bytes |
| **L** | 8 + 32 + 1 + 23 + 128 | **192 bytes** |
| F_R | ⌊(8192−100)/(192+4)⌋ = ⌊8092/196⌋ | 41 |
| T_R (5 años) | Proyección de carga | 4.000 |
| B_R | ⌈4.000 / 41⌉ | 98 págs. |
| **Volumen** | 98 × 8.192 B | **0.77 MB** |

#### Tabla: `proveedor`

*Justificación de T_R: Cerca del 16% de los usuarios son proveedores (800 negocios).*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_usuario` | UUID | 16 | No | No |
| `nombre_comercial` | VARCHAR(150) | 154 | Sí | No |
| `id_categoria` | UUID | 16 | No | No |
| `direccion` | VARCHAR(200) | 204 | Sí | Sí |
| `telefono_contacto` | VARCHAR(20) | 24 | Sí | Sí |
| `created_at` | TIMESTAMPTZ | 8 | No | No |
| `updated_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 3 | 12 bytes |
| Campos fijos | Σ size(campos fijos) | 48 bytes |
| Mapa de bits | 2 NULL → ⌈2/8⌉ | 1 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 382 bytes |
| **L** | 12 + 48 + 1 + 23 + 382 | **466 bytes** |
| F_R | ⌊(8192−100)/(466+4)⌋ = ⌊8092/470⌋ | 17 |
| T_R (5 años) | Proyección de carga | 800 |
| B_R | ⌈800 / 17⌉ | 48 págs. |
| **Volumen** | 48 × 8.192 B | **0.38 MB** |

#### Tabla: `admin`

*Justificación de T_R: Equipo administrativo pequeño y estable (≈20 personas).*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_usuario` | UUID | 16 | No | No |
| `nombre_completo` | VARCHAR(150) | 154 | Sí | No |
| `codigo_empleado` | VARCHAR(50) | 54 | Sí | Sí |
| `telefono` | VARCHAR(20) | 24 | Sí | Sí |
| `fecha_asignacion` | TIMESTAMPTZ | 8 | No | No |
| `activo` | BOOLEAN | 1 | No | No |
| `creado_por` | UUID | 16 | No | Sí |
| `created_at` | TIMESTAMPTZ | 8 | No | No |
| `updated_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 3 | 12 bytes |
| Campos fijos | Σ size(campos fijos) | 57 bytes |
| Mapa de bits | 3 NULL → ⌈3/8⌉ | 1 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 232 bytes |
| **L** | 12 + 57 + 1 + 23 + 232 | **325 bytes** |
| F_R | ⌊(8192−100)/(325+4)⌋ = ⌊8092/329⌋ | 24 |
| T_R (5 años) | Proyección de carga | 20 |
| B_R | ⌈20 / 24⌉ | 1 págs. |
| **Volumen** | 1 × 8.192 B | **0.01 MB** |

#### Tabla: `intento_login`

*Justificación de T_R: Alta rotación: registra cada intento (éxito/fallo). Se recomienda purga periódica (>90 días).*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_intento` | UUID | 16 | No | No |
| `id_usuario` | UUID | 16 | No | No |
| `fecha_hora` | TIMESTAMPTZ | 8 | No | No |
| `exitoso` | BOOLEAN | 1 | No | No |
| `direccion_ip` | VARCHAR(45) | 49 | Sí | No |
| `info_dispositivo` | VARCHAR(255) | 259 | Sí | Sí |
| `mensaje_error` | VARCHAR(200) | 204 | Sí | Sí |
| `created_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 3 | 12 bytes |
| Campos fijos | Σ size(campos fijos) | 49 bytes |
| Mapa de bits | 2 NULL → ⌈2/8⌉ | 1 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 512 bytes |
| **L** | 12 + 49 + 1 + 23 + 512 | **597 bytes** |
| F_R | ⌊(8192−100)/(597+4)⌋ = ⌊8092/601⌋ | 13 |
| T_R (5 años) | Proyección de carga | 50.000 |
| B_R | ⌈50.000 / 13⌉ | 3.847 págs. |
| **Volumen** | 3.847 × 8.192 B | **30.05 MB** |

#### Tabla: `token_refresh`

*Justificación de T_R: Múltiples sesiones activas por usuario; la función limpiar_tokens_expirados() controla el crecimiento.*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_token` | UUID | 16 | No | No |
| `id_usuario` | UUID | 16 | No | No |
| `token` | VARCHAR(500) | 504 | Sí | No |
| `fecha_creacion` | TIMESTAMPTZ | 8 | No | No |
| `fecha_expiracion` | TIMESTAMPTZ | 8 | No | No |
| `revocado` | BOOLEAN | 1 | No | No |
| `fecha_revocacion` | TIMESTAMPTZ | 8 | No | Sí |
| `info_dispositivo` | VARCHAR(255) | 259 | Sí | Sí |
| `direccion_ip` | VARCHAR(45) | 49 | Sí | No |
| `created_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 3 | 12 bytes |
| Campos fijos | Σ size(campos fijos) | 65 bytes |
| Mapa de bits | 2 NULL → ⌈2/8⌉ | 1 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 812 bytes |
| **L** | 12 + 65 + 1 + 23 + 812 | **913 bytes** |
| F_R | ⌊(8192−100)/(913+4)⌋ = ⌊8092/917⌋ | 8 |
| T_R (5 años) | Proyección de carga | 10.000 |
| B_R | ⌈10.000 / 8⌉ | 1.250 págs. |
| **Volumen** | 1.250 × 8.192 B | **9.77 MB** |

#### Tabla: `token_reset_password`

*Justificación de T_R: Solo se generan ante solicitudes de recuperación; uso esporádico.*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_token` | UUID | 16 | No | No |
| `id_usuario` | UUID | 16 | No | No |
| `token` | VARCHAR(255) | 259 | Sí | No |
| `fecha_creacion` | TIMESTAMPTZ | 8 | No | No |
| `fecha_expiracion` | TIMESTAMPTZ | 8 | No | No |
| `usado` | BOOLEAN | 1 | No | No |
| `fecha_uso` | TIMESTAMPTZ | 8 | No | Sí |
| `direccion_ip_solicitud` | VARCHAR(45) | 49 | Sí | No |
| `created_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 2 | 8 bytes |
| Campos fijos | Σ size(campos fijos) | 65 bytes |
| Mapa de bits | 1 NULL → ⌈1/8⌉ | 1 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 308 bytes |
| **L** | 8 + 65 + 1 + 23 + 308 | **405 bytes** |
| F_R | ⌊(8192−100)/(405+4)⌋ = ⌊8092/409⌋ | 19 |
| T_R (5 años) | Proyección de carga | 3.000 |
| B_R | ⌈3.000 / 19⌉ | 158 págs. |
| **Volumen** | 158 × 8.192 B | **1.23 MB** |

#### Tabla: `email_verification_token`

*Justificación de T_R: Un token por usuario registrado (relación 1:1 con usuario).*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_token` | UUID | 16 | No | No |
| `id_usuario` | UUID | 16 | No | No |
| `token` | VARCHAR(500) | 504 | Sí | No |
| `fecha_creacion` | TIMESTAMPTZ | 8 | No | No |
| `fecha_expiracion` | TIMESTAMPTZ | 8 | No | No |
| `usado` | BOOLEAN | 1 | No | No |
| `created_at` | TIMESTAMPTZ | 8 | No | No |
| `updated_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 1 | 4 bytes |
| Campos fijos | Σ size(campos fijos) | 65 bytes |
| Mapa de bits | 0 NULL → ⌈0/8⌉ | 0 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 504 bytes |
| **L** | 4 + 65 + 0 + 23 + 504 | **596 bytes** |
| F_R | ⌊(8192−100)/(596+4)⌋ = ⌊8092/600⌋ | 13 |
| T_R (5 años) | Proyección de carga | 5.000 |
| B_R | ⌈5.000 / 13⌉ | 385 págs. |
| **Volumen** | 385 × 8.192 B | **3.01 MB** |

#### Tabla: `registro_auditoria`

*Justificación de T_R: Crece con cada cambio en datos sensibles. JSONB estimado en ~200 B promedio por valor.*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_registro` | UUID | 16 | No | No |
| `nombre_tabla` | VARCHAR(100) | 104 | Sí | No |
| `id_registro_afectado` | UUID | 16 | No | No |
| `operacion` | VARCHAR(10) | 14 | Sí | No |
| `modificado_por` | UUID | 16 | No | Sí |
| `fecha_modificacion` | TIMESTAMPTZ | 8 | No | No |
| `valores_anteriores` | JSONB | 200 | Sí | Sí |
| `valores_nuevos` | JSONB | 200 | Sí | Sí |
| `direccion_ip` | INET | 19 | No | Sí |
| `agente_usuario` | TEXT | 200 | Sí | Sí |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 5 | 20 bytes |
| Campos fijos | Σ size(campos fijos) | 75 bytes |
| Mapa de bits | 5 NULL → ⌈5/8⌉ | 1 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 718 bytes |
| **L** | 20 + 75 + 1 + 23 + 718 | **837 bytes** |
| F_R | ⌊(8192−100)/(837+4)⌋ = ⌊8092/841⌋ | 9 |
| T_R (5 años) | Proyección de carga | 20.000 |
| B_R | ⌈20.000 / 9⌉ | 2.223 págs. |
| **Volumen** | 2.223 × 8.192 B | **17.37 MB** |

---

## 4. MS-CATALOG-SERVICE

*Tablas analizadas: categoria_servicio · servicio*

### Resumen del microservicio

| Tabla | T_R | L (B) | F_R | B_R | Volumen |
|---|---|---|---|---|---|
| `categoria_servicio` | 50 | 673 | 11 | 5 | 0.04 MB |
| `servicio` | 8.000 | 705 | 11 | 728 | 5.69 MB |
| **TOTAL** | — | — | — | **733** | **5.73 MB** |

### Detalle de cálculo por tabla

#### Tabla: `categoria_servicio`

*Justificación de T_R: Catálogo maestro casi estático; 10 categorías iniciales con margen de crecimiento.*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_categoria` | UUID | 16 | No | No |
| `nombre_categoria` | VARCHAR(100) | 104 | Sí | No |
| `descripcion` | VARCHAR(500) | 504 | Sí | Sí |
| `activa` | BOOLEAN | 1 | No | No |
| `created_at` | TIMESTAMPTZ | 8 | No | No |
| `updated_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 2 | 8 bytes |
| Campos fijos | Σ size(campos fijos) | 33 bytes |
| Mapa de bits | 1 NULL → ⌈1/8⌉ | 1 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 608 bytes |
| **L** | 8 + 33 + 1 + 23 + 608 | **673 bytes** |
| F_R | ⌊(8192−100)/(673+4)⌋ = ⌊8092/677⌋ | 11 |
| T_R (5 años) | Proyección de carga | 50 |
| B_R | ⌈50 / 11⌉ | 5 págs. |
| **Volumen** | 5 × 8.192 B | **0.04 MB** |

#### Tabla: `servicio`

*Justificación de T_R: ≈10 servicios promedio por proveedor (800 × 10 = 8.000).*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_servicio` | UUID | 16 | No | No |
| `id_proveedor` | UUID | 16 | No | No |
| `nombre_servicio` | VARCHAR(100) | 104 | Sí | No |
| `duracion_minutos` | INTEGER | 4 | No | No |
| `precio` | DECIMAL(10,2) | 8 | No | No |
| `descripcion` | VARCHAR(500) | 504 | Sí | Sí |
| `activo` | BOOLEAN | 1 | No | No |
| `capacidad_maxima` | INTEGER | 4 | No | No |
| `created_at` | TIMESTAMPTZ | 8 | No | No |
| `updated_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 2 | 8 bytes |
| Campos fijos | Σ size(campos fijos) | 65 bytes |
| Mapa de bits | 1 NULL → ⌈1/8⌉ | 1 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 608 bytes |
| **L** | 8 + 65 + 1 + 23 + 608 | **705 bytes** |
| F_R | ⌊(8192−100)/(705+4)⌋ = ⌊8092/709⌋ | 11 |
| T_R (5 años) | Proyección de carga | 8.000 |
| B_R | ⌈8.000 / 11⌉ | 728 págs. |
| **Volumen** | 728 × 8.192 B | **5.69 MB** |

---

## 5. MS-SCHEDULE-SERVICE

*Tablas analizadas: empleado · empleado_servicio · horario_laboral · bloqueo_horario*

### Resumen del microservicio

| Tabla | T_R | L (B) | F_R | B_R | Volumen |
|---|---|---|---|---|---|
| `empleado` | 4.000 | 775 | 10 | 400 | 3.12 MB |
| `empleado_servicio` | 20.000 | 96 | 80 | 250 | 1.95 MB |
| `horario_laboral` | 28.000 | 98 | 79 | 355 | 2.77 MB |
| `bloqueo_horario` | 200.000 | 129 | 60 | 3.334 | 26.05 MB |
| **TOTAL** | — | — | — | **4.339** | **33.90 MB** |

### Detalle de cálculo por tabla

#### Tabla: `empleado`

*Justificación de T_R: ≈5 empleados promedio por proveedor (800 × 5 = 4.000).*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_empleado` | UUID | 16 | No | No |
| `id_proveedor` | UUID | 16 | No | No |
| `nombre_completo` | VARCHAR(150) | 154 | Sí | No |
| `telefono` | VARCHAR(20) | 24 | Sí | Sí |
| `activo` | BOOLEAN | 1 | No | No |
| `fecha_contratacion` | TIMESTAMPTZ | 8 | No | Sí |
| `notas` | VARCHAR(500) | 504 | Sí | Sí |
| `created_at` | TIMESTAMPTZ | 8 | No | No |
| `updated_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 3 | 12 bytes |
| Campos fijos | Σ size(campos fijos) | 57 bytes |
| Mapa de bits | 3 NULL → ⌈3/8⌉ | 1 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 682 bytes |
| **L** | 12 + 57 + 1 + 23 + 682 | **775 bytes** |
| F_R | ⌊(8192−100)/(775+4)⌋ = ⌊8092/779⌋ | 10 |
| T_R (5 años) | Proyección de carga | 4.000 |
| B_R | ⌈4.000 / 10⌉ | 400 págs. |
| **Volumen** | 400 × 8.192 B | **3.12 MB** |

#### Tabla: `empleado_servicio`

*Justificación de T_R: Tabla puente N:M: ≈5 servicios por empleado (4.000 × 5 = 20.000). Registro muy compacto (sin campos variables).*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_empleado_servicio` | UUID | 16 | No | No |
| `id_empleado` | UUID | 16 | No | No |
| `id_servicio` | UUID | 16 | No | No |
| `activo` | BOOLEAN | 1 | No | No |
| `fecha_asignacion` | TIMESTAMPTZ | 8 | No | No |
| `created_at` | TIMESTAMPTZ | 8 | No | No |
| `updated_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 0 | 0 bytes |
| Campos fijos | Σ size(campos fijos) | 73 bytes |
| Mapa de bits | 0 NULL → ⌈0/8⌉ | 0 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 0 bytes |
| **L** | 0 + 73 + 0 + 23 + 0 | **96 bytes** |
| F_R | ⌊(8192−100)/(96+4)⌋ = ⌊8092/100⌋ | 80 |
| T_R (5 años) | Proyección de carga | 20.000 |
| B_R | ⌈20.000 / 80⌉ | 250 págs. |
| **Volumen** | 250 × 8.192 B | **1.95 MB** |

#### Tabla: `horario_laboral`

*Justificación de T_R: ≈7 registros por empleado (un bloque por día de la semana): 4.000 × 7 = 28.000.*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_horario` | UUID | 16 | No | No |
| `id_empleado` | UUID | 16 | No | No |
| `dia_semana` | VARCHAR(10) | 14 | Sí | No |
| `hora_inicio` | TIME | 4 | No | No |
| `hora_fin` | TIME | 4 | No | No |
| `activo` | BOOLEAN | 1 | No | No |
| `created_at` | TIMESTAMPTZ | 8 | No | No |
| `updated_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 1 | 4 bytes |
| Campos fijos | Σ size(campos fijos) | 57 bytes |
| Mapa de bits | 0 NULL → ⌈0/8⌉ | 0 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 14 bytes |
| **L** | 4 + 57 + 0 + 23 + 14 | **98 bytes** |
| F_R | ⌊(8192−100)/(98+4)⌋ = ⌊8092/102⌋ | 79 |
| T_R (5 años) | Proyección de carga | 28.000 |
| B_R | ⌈28.000 / 79⌉ | 355 págs. |
| **Volumen** | 355 × 8.192 B | **2.77 MB** |

#### Tabla: `bloqueo_horario`

*Justificación de T_R: Una entrada por cada reserva + bloqueos administrativos. Tabla de alto crecimiento; candidata a particionado por fecha.*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_bloqueo` | UUID | 16 | No | No |
| `id_empleado` | UUID | 16 | No | No |
| `id_reserva` | UUID | 16 | No | Sí |
| `fecha` | DATE | 4 | No | No |
| `hora_inicio` | TIME | 4 | No | No |
| `hora_fin` | TIME | 4 | No | No |
| `tipo_bloqueo` | VARCHAR(20) | 24 | Sí | No |
| `activo` | BOOLEAN | 1 | No | No |
| `created_at` | TIMESTAMPTZ | 8 | No | No |
| `updated_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 1 | 4 bytes |
| Campos fijos | Σ size(campos fijos) | 77 bytes |
| Mapa de bits | 1 NULL → ⌈1/8⌉ | 1 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 24 bytes |
| **L** | 4 + 77 + 1 + 23 + 24 | **129 bytes** |
| F_R | ⌊(8192−100)/(129+4)⌋ = ⌊8092/133⌋ | 60 |
| T_R (5 años) | Proyección de carga | 200.000 |
| B_R | ⌈200.000 / 60⌉ | 3.334 págs. |
| **Volumen** | 3.334 × 8.192 B | **26.05 MB** |

---

## 6. MS-RESERVATION-SERVICE

*Tablas analizadas: reserva*

### Resumen del microservicio

| Tabla | T_R | L (B) | F_R | B_R | Volumen |
|---|---|---|---|---|---|
| `reserva` | 300.000 | 688 | 11 | 27.273 | 213.07 MB |
| **TOTAL** | — | — | — | **27.273** | **213.07 MB** |

### Detalle de cálculo por tabla

#### Tabla: `reserva`

*Justificación de T_R: Tabla transaccional principal y de mayor volumen del sistema. Proyección: ≈300.000 reservas acumuladas en 5 años. Candidata prioritaria a particionado por rango de fecha.*

**Identificación de columnas:**

| Columna | Tipo | Bytes | Variable | Nullable |
|---|---|---|---|---|
| `id_reserva` | UUID | 16 | No | No |
| `id_cliente` | UUID | 16 | No | No |
| `id_servicio` | UUID | 16 | No | No |
| `id_empleado` | UUID | 16 | No | No |
| `id_proveedor` | UUID | 16 | No | No |
| `fecha_hora_inicio` | TIMESTAMPTZ | 8 | No | No |
| `fecha_hora_fin` | TIMESTAMPTZ | 8 | No | No |
| `estado` | VARCHAR(20) | 24 | Sí | No |
| `fecha_creacion` | TIMESTAMPTZ | 8 | No | No |
| `fecha_cancelacion` | TIMESTAMPTZ | 8 | No | Sí |
| `comentarios` | VARCHAR(500) | 504 | Sí | Sí |
| `created_at` | TIMESTAMPTZ | 8 | No | No |
| `updated_at` | TIMESTAMPTZ | 8 | No | No |

**Cálculos:**

| Paso | Fórmula / Detalle | Resultado |
|---|---|---|
| Punteros var. | 4 × 2 | 8 bytes |
| Campos fijos | Σ size(campos fijos) | 128 bytes |
| Mapa de bits | 2 NULL → ⌈2/8⌉ | 1 byte(s) |
| Overhead tupla | Constante PostgreSQL | 23 bytes |
| Σ campos var. | VARCHAR/TEXT/JSONB (n+4) | 528 bytes |
| **L** | 8 + 128 + 1 + 23 + 528 | **688 bytes** |
| F_R | ⌊(8192−100)/(688+4)⌋ = ⌊8092/692⌋ | 11 |
| T_R (5 años) | Proyección de carga | 300.000 |
| B_R | ⌈300.000 / 11⌉ | 27.273 págs. |
| **Volumen** | 27.273 × 8.192 B | **213.07 MB** |

---

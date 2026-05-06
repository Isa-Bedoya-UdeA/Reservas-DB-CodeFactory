# Volumen de datos por tabla aproximado

## MS-AUTH

### Tabla USUARIO

#### 1. Identificación de columnas

| Columna            | Tipo           | Tamaño (bytes) | Variable? | Puede ser NULL? |
|--------------------|----------------|---------------|-----------|-----------------|
| id_usuario         | UUID           | 16            | No        | No              |
| email              | VARCHAR(100)   | 104           | Sí        | No              |
| password_hash      | VARCHAR(255)   | 259           | Sí        | No              |
| email_verificado   | BOOLEAN        | 1             | No        | No              |
| intentos_fallidos  | INTEGER        | 4             | No        | No              |
| bloqueado_hasta    | TIMESTAMPTZ    | 8             | No        | Sí              |
| fecha_registro     | TIMESTAMPTZ    | 8             | No        | No              |
| estado             | VARCHAR(20)    | 24            | Sí        | No              |
| tipo_usuario       | VARCHAR(20)    | 24            | Sí        | No              |
| created_at         | TIMESTAMPTZ    | 8             | No        | No              |
| updated_at         | TIMESTAMPTZ    | 8             | No        | No              |

**Campos variables:** 4 (email, password_hash, estado, tipo_usuario)
**Campos que pueden ser NULL:** 1 (bloqueado_hasta)

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 4 + (16 + 1 + 4 + 8 + 8 + 8 + 8) + 1 + 23 + (104 + 259 + 24 + 24)
$$

Desglose:

- 4 × 4 = 16 (punteros a campos variables)
- Campos fijos: 16 (UUID) + 1 (BOOL) + 4 (INT) + 8 (TIMESTAMPTZ) × 4 = 32 + 8 = 40 (TIMESTAMPTZ) → total 16+1+4+8+8+8+8 = 53
- Mapa de bits: 1 byte (1 campo NULL)
- Overhead tupla: 23 bytes
- Campos variables: 104 (email) + 259 (password_hash) + 24 (estado) + 24 (tipo_usuario) = 411

Total:

$$
L = 16 + 53 + 1 + 23 + 411 = 504\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{504 + 4} \right\rfloor = \left\lfloor \frac{8092}{508} \right\rfloor = 15
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 5,000 usuarios en 5 años

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{5000}{15} \right\rceil = 334\ páginas
$$

$$
Volumen\ total = 334 \times 8192 = 2,735,  728\ bytes \approx 2.6\ MB
$$

### Tabla: CLIENTE

#### 1. Identificación de columnas

| Columna    | Tipo          | Tamaño (bytes) | Variable? | Puede ser NULL? |
|------------|---------------|----------------|-----------|-----------------|
| id_usuario | UUID          | 16             | No        | No              |
| nombre     | VARCHAR(100)  | 104            | Sí        | No              |
| telefono   | VARCHAR(20)   | 24             | Sí        | Sí              |
| created_at | TIMESTAMPTZ   | 8              | No        | No              |
| updated_at | TIMESTAMPTZ   | 8              | No        | No              |

**Campos variables:** 2 (nombre, telefono)
**Campos que pueden ser NULL:** 1 (telefono)

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 2 + (16 + 8 + 8) + 1 + 23 + (104 + 24)
$$

Desglose:

- 4 × 2 = 8 (punteros a campos variables)
- Campos fijos: 16 (UUID) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) = 32
- Mapa de bits: 1 byte (1 campo NULL)
- Overhead tupla: 23 bytes
- Campos variables: 104 (nombre) + 24 (telefono) = 128

Total:

$$
L = 8 + 32 + 1 + 23 + 128 = 192\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{192 + 4} \right\rfloor = \left\lfloor \frac{8092}{196} \right\rfloor = 41
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 4,000 clientes en 5 años (≈ 80% de los 5,000 usuarios serán clientes)

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{4000}{41} \right\rceil = 98\ páginas
$$

$$
Volumen\ total = 98 \times 8192 = 802{,}816\ bytes \approx 0.77\ MB
$$

---

### Tabla: PROVEEDOR

#### 1. Identificación de columnas

| Columna            | Tipo          | Tamaño (bytes) | Variable? | Puede ser NULL? |
|--------------------|---------------|----------------|-----------|-----------------|
| id_usuario         | UUID          | 16             | No        | No              |
| nombre_comercial   | VARCHAR(150)  | 154            | Sí        | No              |
| id_categoria       | UUID          | 16             | No        | No              |
| direccion          | VARCHAR(200)  | 204            | Sí        | Sí              |
| telefono_contacto  | VARCHAR(20)   | 24             | Sí        | Sí              |
| created_at         | TIMESTAMPTZ   | 8              | No        | No              |
| updated_at         | TIMESTAMPTZ   | 8              | No        | No              |

**Campos variables:** 3 (nombre_comercial, direccion, telefono_contacto)
**Campos que pueden ser NULL:** 2 (direccion, telefono_contacto)

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 3 + (16 + 16 + 8 + 8) + 1 + 23 + (154 + 204 + 24)
$$

Desglose:

- 4 × 3 = 12 (punteros a campos variables)
- Campos fijos: 16 (UUID) + 16 (UUID) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) = 48
- Mapa de bits: 1 byte (2 campos NULL, < 8 → 1 byte)
- Overhead tupla: 23 bytes
- Campos variables: 154 (nombre_comercial) + 204 (direccion) + 24 (telefono_contacto) = 382

Total:

$$
L = 12 + 48 + 1 + 23 + 382 = 466\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{466 + 4} \right\rfloor = \left\lfloor \frac{8092}{470} \right\rfloor = 17
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 1,000 proveedores en 5 años (≈ 20% de los usuarios)

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{1000}{17} \right\rceil = 59\ páginas
$$

$$
Volumen\ total = 59 \times 8192 = 483{,}328\ bytes \approx 0.46\ MB
$$

---

### Tabla: ADMIN

#### 1. Identificación de columnas

| Columna          | Tipo          | Tamaño (bytes) | Variable? | Puede ser NULL? |
|------------------|---------------|----------------|-----------|-----------------|
| id_usuario       | UUID          | 16             | No        | No              |
| nombre_completo  | VARCHAR(150)  | 154            | Sí        | No              |
| codigo_empleado  | VARCHAR(50)   | 54             | Sí        | Sí              |
| telefono         | VARCHAR(20)   | 24             | Sí        | Sí              |
| fecha_asignacion | TIMESTAMPTZ   | 8              | No        | No              |
| activo           | BOOLEAN       | 1              | No        | No              |
| creado_por       | UUID          | 16             | No        | Sí              |
| created_at       | TIMESTAMPTZ   | 8              | No        | No              |
| updated_at       | TIMESTAMPTZ   | 8              | No        | No              |

**Campos variables:** 3 (nombre_completo, codigo_empleado, telefono)
**Campos que pueden ser NULL:** 3 (codigo_empleado, telefono, creado_por)

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 3 + (16 + 8 + 1 + 16 + 8 + 8) + 1 + 23 + (154 + 54 + 24)
$$

Desglose:

- 4 × 3 = 12 (punteros a campos variables)
- Campos fijos: 16 (UUID id_usuario) + 8 (TIMESTAMPTZ fecha_asignacion) + 1 (BOOLEAN) + 16 (UUID creado_por) + 8 (created_at) + 8 (updated_at) = 57
- Mapa de bits: 1 byte (3 campos NULL, < 8 → 1 byte)
- Overhead tupla: 23 bytes
- Campos variables: 154 (nombre_completo) + 54 (codigo_empleado) + 24 (telefono) = 232

Total:

$$
L = 12 + 57 + 1 + 23 + 232 = 325\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{325 + 4} \right\rfloor = \left\lfloor \frac{8092}{329} \right\rfloor = 24
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 20 administradores en 5 años

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{20}{24} \right\rceil = 1\ página
$$

$$
Volumen\ total = 1 \times 8192 = 8{,}192\ bytes \approx 0.008\ MB
$$

---

### Tabla: INTENTO_LOGIN

#### 1. Identificación de columnas

| Columna          | Tipo          | Tamaño (bytes) | Variable? | Puede ser NULL? |
|------------------|---------------|----------------|-----------|-----------------|
| id_intento       | UUID          | 16             | No        | No              |
| id_usuario       | UUID          | 16             | No        | No              |
| fecha_hora       | TIMESTAMPTZ   | 8              | No        | No              |
| exitoso          | BOOLEAN       | 1              | No        | No              |
| direccion_ip     | VARCHAR(45)   | 49             | Sí        | No              |
| info_dispositivo | VARCHAR(255)  | 259            | Sí        | Sí              |
| mensaje_error    | VARCHAR(200)  | 204            | Sí        | Sí              |
| created_at       | TIMESTAMPTZ   | 8              | No        | No              |

**Campos variables:** 3 (direccion_ip, info_dispositivo, mensaje_error)
**Campos que pueden ser NULL:** 2 (info_dispositivo, mensaje_error)

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 3 + (16 + 16 + 8 + 1 + 8) + 1 + 23 + (49 + 259 + 204)
$$

Desglose:

- 4 × 3 = 12 (punteros a campos variables)
- Campos fijos: 16 (UUID) + 16 (UUID) + 8 (TIMESTAMPTZ) + 1 (BOOLEAN) + 8 (TIMESTAMPTZ) = 49
- Mapa de bits: 1 byte (2 campos NULL, < 8 → 1 byte)
- Overhead tupla: 23 bytes
- Campos variables: 49 (direccion_ip) + 259 (info_dispositivo) + 204 (mensaje_error) = 512

Total:

$$
L = 12 + 49 + 1 + 23 + 512 = 597\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{597 + 4} \right\rfloor = \left\lfloor \frac{8092}{601} \right\rfloor = 13
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 150,000 registros en 5 años (≈ 3 intentos/día × 5,000 usuarios × 365 días, con purga periódica de registros antiguos)

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{150{,}000}{13} \right\rceil = 11{,}539\ páginas
$$

$$
Volumen\ total = 11{,}539 \times 8192 = 94{,}511{,}488\ bytes \approx 90.1\ MB
$$

---

### Tabla: TOKEN_REFRESH

#### 1. Identificación de columnas

| Columna           | Tipo          | Tamaño (bytes) | Variable? | Puede ser NULL? |
|-------------------|---------------|----------------|-----------|-----------------|
| id_token          | UUID          | 16             | No        | No              |
| id_usuario        | UUID          | 16             | No        | No              |
| token             | VARCHAR(500)  | 504            | Sí        | No              |
| fecha_creacion    | TIMESTAMPTZ   | 8              | No        | No              |
| fecha_expiracion  | TIMESTAMPTZ   | 8              | No        | No              |
| revocado          | BOOLEAN       | 1              | No        | No              |
| fecha_revocacion  | TIMESTAMPTZ   | 8              | No        | Sí              |
| info_dispositivo  | VARCHAR(255)  | 259            | Sí        | Sí              |
| direccion_ip      | VARCHAR(45)   | 49             | Sí        | No              |
| created_at        | TIMESTAMPTZ   | 8              | No        | No              |

**Campos variables:** 3 (token, info_dispositivo, direccion_ip)
**Campos que pueden ser NULL:** 2 (fecha_revocacion, info_dispositivo)

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 3 + (16 + 16 + 8 + 8 + 1 + 8 + 8) + 1 + 23 + (504 + 259 + 49)
$$

Desglose:

- 4 × 3 = 12 (punteros a campos variables)
- Campos fijos: 16 (UUID) + 16 (UUID) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) + 1 (BOOLEAN) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) = 65
- Mapa de bits: 1 byte (2 campos NULL, < 8 → 1 byte)
- Overhead tupla: 23 bytes
- Campos variables: 504 (token) + 259 (info_dispositivo) + 49 (direccion_ip) = 812

Total:

$$
L = 12 + 65 + 1 + 23 + 812 = 913\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{913 + 4} \right\rfloor = \left\lfloor \frac{8092}{917} \right\rfloor = 8
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 25,000 tokens en 5 años (≈ 5 tokens activos por usuario × 5,000 usuarios, con purga de expirados)

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{25{,}000}{8} \right\rceil = 3{,}125\ páginas
$$

$$
Volumen\ total = 3{,}125 \times 8192 = 25{,}600{,}000\ bytes \approx 24.4\ MB
$$

---

### Tabla: TOKEN_RESET_PASSWORD

#### 1. Identificación de columnas

| Columna                | Tipo          | Tamaño (bytes) | Variable? | Puede ser NULL? |
|------------------------|---------------|----------------|-----------|-----------------|
| id_token               | UUID          | 16             | No        | No              |
| id_usuario             | UUID          | 16             | No        | No              |
| token                  | VARCHAR(255)  | 259            | Sí        | No              |
| fecha_creacion         | TIMESTAMPTZ   | 8              | No        | No              |
| fecha_expiracion       | TIMESTAMPTZ   | 8              | No        | No              |
| usado                  | BOOLEAN       | 1              | No        | No              |
| fecha_uso              | TIMESTAMPTZ   | 8              | No        | Sí              |
| direccion_ip_solicitud | VARCHAR(45)   | 49             | Sí        | No              |
| created_at             | TIMESTAMPTZ   | 8              | No        | No              |

**Campos variables:** 2 (token, direccion_ip_solicitud)
**Campos que pueden ser NULL:** 1 (fecha_uso)

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 2 + (16 + 16 + 8 + 8 + 1 + 8 + 8) + 1 + 23 + (259 + 49)
$$

Desglose:

- 4 × 2 = 8 (punteros a campos variables)
- Campos fijos: 16 (UUID) + 16 (UUID) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) + 1 (BOOLEAN) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) = 65
- Mapa de bits: 1 byte (1 campo NULL)
- Overhead tupla: 23 bytes
- Campos variables: 259 (token) + 49 (direccion_ip_solicitud) = 308

Total:

$$
L = 8 + 65 + 1 + 23 + 308 = 405\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{405 + 4} \right\rfloor = \left\lfloor \frac{8092}{409} \right\rfloor = 19
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 10,000 tokens en 5 años (≈ 2 solicitudes de reset por usuario en 5 años × 5,000 usuarios)

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{10{,}000}{19} \right\rceil = 527\ páginas
$$

$$
Volumen\ total = 527 \times 8192 = 4{,}317{,}184\ bytes \approx 4.1\ MB
$$

---

### Tabla: EMAIL_VERIFICATION_TOKEN

#### 1. Identificación de columnas

| Columna          | Tipo          | Tamaño (bytes) | Variable? | Puede ser NULL? |
|------------------|---------------|----------------|-----------|-----------------|
| id_token         | UUID          | 16             | No        | No              |
| id_usuario       | UUID          | 16             | No        | No              |
| token            | VARCHAR(500)  | 504            | Sí        | No              |
| fecha_creacion   | TIMESTAMPTZ   | 8              | No        | No              |
| fecha_expiracion | TIMESTAMPTZ   | 8              | No        | No              |
| usado            | BOOLEAN       | 1              | No        | No              |
| created_at       | TIMESTAMPTZ   | 8              | No        | No              |
| updated_at       | TIMESTAMPTZ   | 8              | No        | No              |

**Campos variables:** 1 (token)
**Campos que pueden ser NULL:** 0

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 1 + (16 + 16 + 8 + 8 + 1 + 8 + 8) + 0 + 23 + (504)
$$

Desglose:

- 4 × 1 = 4 (punteros a campos variables)
- Campos fijos: 16 (UUID) + 16 (UUID) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) + 1 (BOOLEAN) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) = 65
- Mapa de bits: 0 bytes (ningún campo NULL)
- Overhead tupla: 23 bytes
- Campos variables: 504 (token)

Total:

$$
L = 4 + 65 + 0 + 23 + 504 = 596\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{596 + 4} \right\rfloor = \left\lfloor \frac{8092}{600} \right\rfloor = 13
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 5,000 tokens en 5 años (1 token por usuario al momento del registro; se reutiliza el registro si el usuario solicita reenvío)

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{5{,}000}{13} \right\rceil = 385\ páginas
$$

$$
Volumen\ total = 385 \times 8192 = 3{,}153{,}920\ bytes \approx 3.0\ MB
$$

---

## MS-CATALOG

### Tabla: CATEGORIA_SERVICIO

#### 1. Identificación de columnas

| Columna           | Tipo          | Tamaño (bytes) | Variable? | Puede ser NULL? |
|-------------------|---------------|----------------|-----------|-----------------|
| id_categoria      | UUID          | 16             | No        | No              |
| nombre_categoria  | VARCHAR(100)  | 104            | Sí        | No              |
| descripcion       | VARCHAR(500)  | 504            | Sí        | Sí              |
| activa            | BOOLEAN       | 1              | No        | No              |
| created_at        | TIMESTAMPTZ   | 8              | No        | No              |
| updated_at        | TIMESTAMPTZ   | 8              | No        | No              |

**Campos variables:** 2 (nombre_categoria, descripcion)
**Campos que pueden ser NULL:** 1 (descripcion)

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 2 + (16 + 1 + 8 + 8) + 1 + 23 + (104 + 504)
$$

Desglose:

- 4 × 2 = 8 (punteros a campos variables)
- Campos fijos: 16 (UUID) + 1 (BOOLEAN) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) = 33
- Mapa de bits: 1 byte (1 campo NULL)
- Overhead tupla: 23 bytes
- Campos variables: 104 (nombre_categoria) + 504 (descripcion) = 608

Total:

$$
L = 8 + 33 + 1 + 23 + 608 = 673\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{673 + 4} \right\rfloor = \left\lfloor \frac{8092}{677} \right\rfloor = 11
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 50 categorías en 5 años (catálogo estático administrado por el equipo; crece muy lentamente)

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{50}{11} \right\rceil = 5\ páginas
$$

$$
Volumen\ total = 5 \times 8192 = 40{,}960\ bytes \approx 0.04\ MB
$$

---

### Tabla: SERVICIO

#### 1. Identificación de columnas

| Columna           | Tipo           | Tamaño (bytes) | Variable? | Puede ser NULL? |
|-------------------|----------------|----------------|-----------|-----------------|
| id_servicio       | UUID           | 16             | No        | No              |
| id_proveedor      | UUID           | 16             | No        | No              |
| nombre_servicio   | VARCHAR(100)   | 104            | Sí        | No              |
| duracion_minutos  | INTEGER        | 4              | No        | No              |
| precio            | DECIMAL(10,2)  | 8              | No        | No              |
| descripcion       | VARCHAR(500)   | 504            | Sí        | Sí              |
| activo            | BOOLEAN        | 1              | No        | No              |
| capacidad_maxima  | INTEGER        | 4              | No        | No              |
| created_at        | TIMESTAMPTZ    | 8              | No        | No              |
| updated_at        | TIMESTAMPTZ    | 8              | No        | No              |

**Campos variables:** 2 (nombre_servicio, descripcion)
**Campos que pueden ser NULL:** 1 (descripcion)

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 2 + (16 + 16 + 4 + 8 + 1 + 4 + 8 + 8) + 1 + 23 + (104 + 504)
$$

Desglose:

- 4 × 2 = 8 (punteros a campos variables)
- Campos fijos: 16 (UUID) + 16 (UUID) + 4 (INT) + 8 (DECIMAL) + 1 (BOOLEAN) + 4 (INT) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) = 65
- Mapa de bits: 1 byte (1 campo NULL)
- Overhead tupla: 23 bytes
- Campos variables: 104 (nombre_servicio) + 504 (descripcion) = 608

Total:

$$
L = 8 + 65 + 1 + 23 + 608 = 705\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{705 + 4} \right\rfloor = \left\lfloor \frac{8092}{709} \right\rfloor = 11
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 5,000 servicios en 5 años (≈ 5 servicios por proveedor × 1,000 proveedores)

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{5{,}000}{11} \right\rceil = 455\ páginas
$$

$$
Volumen\ total = 455 \times 8192 = 3{,}727{,}360\ bytes \approx 3.56\ MB
$$

---

## MS-SCHEDULE

### Tabla: EMPLEADO

#### 1. Identificación de columnas

| Columna             | Tipo          | Tamaño (bytes) | Variable? | Puede ser NULL? |
|---------------------|---------------|----------------|-----------|-----------------|
| id_empleado         | UUID          | 16             | No        | No              |
| id_proveedor        | UUID          | 16             | No        | No              |
| nombre_completo     | VARCHAR(150)  | 154            | Sí        | No              |
| telefono            | VARCHAR(20)   | 24             | Sí        | Sí              |
| activo              | BOOLEAN       | 1              | No        | No              |
| fecha_contratacion  | TIMESTAMPTZ   | 8              | No        | Sí              |
| notas               | VARCHAR(500)  | 504            | Sí        | Sí              |
| created_at          | TIMESTAMPTZ   | 8              | No        | No              |
| updated_at          | TIMESTAMPTZ   | 8              | No        | No              |

**Campos variables:** 3 (nombre_completo, telefono, notas)
**Campos que pueden ser NULL:** 3 (telefono, fecha_contratacion, notas)

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 3 + (16 + 16 + 1 + 8 + 8 + 8) + 1 + 23 + (154 + 24 + 504)
$$

Desglose:

- 4 × 3 = 12 (punteros a campos variables)
- Campos fijos: 16 (UUID) + 16 (UUID) + 1 (BOOLEAN) + 8 (TIMESTAMPTZ fecha_contratacion) + 8 (TIMESTAMPTZ created_at) + 8 (TIMESTAMPTZ updated_at) = 57
- Mapa de bits: 1 byte (3 campos NULL, < 8 → 1 byte)
- Overhead tupla: 23 bytes
- Campos variables: 154 (nombre_completo) + 24 (telefono) + 504 (notas) = 682

Total:

$$
L = 12 + 57 + 1 + 23 + 682 = 775\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{775 + 4} \right\rfloor = \left\lfloor \frac{8092}{779} \right\rfloor = 10
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 3,000 empleados en 5 años (≈ 3 empleados por proveedor × 1,000 proveedores)

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{3{,}000}{10} \right\rceil = 300\ páginas
$$

$$
Volumen\ total = 300 \times 8192 = 2{,}457{,}600\ bytes \approx 2.34\ MB
$$

---

### Tabla: EMPLEADO_SERVICIO

#### 1. Identificación de columnas

| Columna               | Tipo          | Tamaño (bytes) | Variable? | Puede ser NULL? |
|-----------------------|---------------|----------------|-----------|-----------------|
| id_empleado_servicio  | UUID          | 16             | No        | No              |
| id_empleado           | UUID          | 16             | No        | No              |
| id_servicio           | UUID          | 16             | No        | No              |
| activo                | BOOLEAN       | 1              | No        | No              |
| fecha_asignacion      | TIMESTAMPTZ   | 8              | No        | No              |
| created_at            | TIMESTAMPTZ   | 8              | No        | No              |
| updated_at            | TIMESTAMPTZ   | 8              | No        | No              |

**Campos variables:** 0
**Campos que pueden ser NULL:** 0

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 0 + (16 + 16 + 16 + 1 + 8 + 8 + 8) + 0 + 23
$$

Desglose:

- 4 × 0 = 0 (sin campos variables)
- Campos fijos: 16 (UUID) + 16 (UUID) + 16 (UUID) + 1 (BOOLEAN) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) = 73
- Mapa de bits: 0 bytes (ningún campo NULL)
- Overhead tupla: 23 bytes

Total:

$$
L = 0 + 73 + 0 + 23 = 96\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{96 + 4} \right\rfloor = \left\lfloor \frac{8092}{100} \right\rfloor = 80
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 9,000 asignaciones en 5 años (≈ 3 servicios por empleado × 3,000 empleados)

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{9{,}000}{80} \right\rceil = 113\ páginas
$$

$$
Volumen\ total = 113 \times 8192 = 925{,}696\ bytes \approx 0.88\ MB
$$

---

### Tabla: HORARIO_LABORAL

#### 1. Identificación de columnas

| Columna      | Tipo          | Tamaño (bytes) | Variable? | Puede ser NULL? |
|--------------|---------------|----------------|-----------|-----------------|
| id_horario   | UUID          | 16             | No        | No              |
| id_empleado  | UUID          | 16             | No        | No              |
| dia_semana   | VARCHAR(10)   | 14             | Sí        | No              |
| hora_inicio  | TIME          | 8              | No        | No              |
| hora_fin     | TIME          | 8              | No        | No              |
| activo       | BOOLEAN       | 1              | No        | No              |
| created_at   | TIMESTAMPTZ   | 8              | No        | No              |
| updated_at   | TIMESTAMPTZ   | 8              | No        | No              |

**Campos variables:** 1 (dia_semana)
**Campos que pueden ser NULL:** 0

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 1 + (16 + 16 + 8 + 8 + 1 + 8 + 8) + 0 + 23 + (14)
$$

Desglose:

- 4 × 1 = 4 (punteros a campos variables)
- Campos fijos: 16 (UUID) + 16 (UUID) + 8 (TIME) + 8 (TIME) + 1 (BOOLEAN) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) = 65
- Mapa de bits: 0 bytes (ningún campo NULL)
- Overhead tupla: 23 bytes
- Campos variables: 14 (dia_semana → máximo "MIERCOLES" = 9 chars + 4 overhead + 1 len = 14)

Total:

$$
L = 4 + 65 + 0 + 23 + 14 = 106\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{106 + 4} \right\rfloor = \left\lfloor \frac{8092}{110} \right\rfloor = 73
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 15,000 horarios en 5 años (≈ 5 días laborales × 3,000 empleados)

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{15{,}000}{73} \right\rceil = 206\ páginas
$$

$$
Volumen\ total = 206 \times 8192 = 1{,}687{,}552\ bytes \approx 1.61\ MB
$$

---

### Tabla: BLOQUEO_HORARIO

#### 1. Identificación de columnas

| Columna      | Tipo          | Tamaño (bytes) | Variable? | Puede ser NULL? |
|--------------|---------------|----------------|-----------|-----------------|
| id_bloqueo   | UUID          | 16             | No        | No              |
| id_empleado  | UUID          | 16             | No        | No              |
| id_reserva   | UUID          | 16             | No        | Sí              |
| fecha        | DATE          | 4              | No        | No              |
| hora_inicio  | TIME          | 8              | No        | No              |
| hora_fin     | TIME          | 8              | No        | No              |
| tipo_bloqueo | VARCHAR(20)   | 24             | Sí        | No              |
| activo       | BOOLEAN       | 1              | No        | No              |
| created_at   | TIMESTAMPTZ   | 8              | No        | No              |
| updated_at   | TIMESTAMPTZ   | 8              | No        | No              |

**Campos variables:** 1 (tipo_bloqueo)
**Campos que pueden ser NULL:** 1 (id_reserva)

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 1 + (16 + 16 + 16 + 4 + 8 + 8 + 1 + 8 + 8) + 1 + 23 + (24)
$$

Desglose:

- 4 × 1 = 4 (punteros a campos variables)
- Campos fijos: 16 (UUID) + 16 (UUID) + 16 (UUID) + 4 (DATE) + 8 (TIME) + 8 (TIME) + 1 (BOOLEAN) + 8 (TIMESTAMPTZ) + 8 (TIMESTAMPTZ) = 85
- Mapa de bits: 1 byte (1 campo NULL)
- Overhead tupla: 23 bytes
- Campos variables: 24 (tipo_bloqueo)

Total:

$$
L = 4 + 85 + 1 + 23 + 24 = 137\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{137 + 4} \right\rfloor = \left\lfloor \frac{8092}{141} \right\rfloor = 57
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 1,800,000 bloqueos en 5 años (≈ 3,000 empleados × 8 citas/día × 250 días hábiles/año × 3 años de operación plena, más bloqueos administrativos)

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{1{,}800{,}000}{57} \right\rceil = 31{,}579\ páginas
$$

$$
Volumen\ total = 31{,}579 \times 8192 = 258{,}759{,}168\ bytes \approx 246.8\ MB
$$

---

## MS-RESERVATION

### Tabla: RESERVA

#### 1. Identificación de columnas

| Columna             | Tipo          | Tamaño (bytes) | Variable? | Puede ser NULL? |
|---------------------|---------------|----------------|-----------|-----------------|
| id_reserva          | UUID          | 16             | No        | No              |
| id_cliente          | UUID          | 16             | No        | No              |
| id_servicio         | UUID          | 16             | No        | No              |
| id_empleado         | UUID          | 16             | No        | No              |
| id_proveedor        | UUID          | 16             | No        | No              |
| fecha_hora_inicio   | TIMESTAMPTZ   | 8              | No        | No              |
| fecha_hora_fin      | TIMESTAMPTZ   | 8              | No        | No              |
| estado              | VARCHAR(20)   | 24             | Sí        | No              |
| fecha_creacion      | TIMESTAMPTZ   | 8              | No        | No              |
| fecha_cancelacion   | TIMESTAMPTZ   | 8              | No        | Sí              |
| comentarios         | VARCHAR(500)  | 504            | Sí        | Sí              |
| created_at          | TIMESTAMPTZ   | 8              | No        | No              |
| updated_at          | TIMESTAMPTZ   | 8              | No        | No              |

**Campos variables:** 2 (estado, comentarios)
**Campos que pueden ser NULL:** 2 (fecha_cancelacion, comentarios)

#### 2. Cálculo de longitud estimada del registro (L)

$$
L = 4 \times 2 + (16 + 16 + 16 + 16 + 16 + 8 + 8 + 8 + 8 + 8 + 8 + 8) + 1 + 23 + (24 + 504)
$$

Desglose:

- 4 × 2 = 8 (punteros a campos variables)
- Campos fijos: 16 × 5 (UUIDs) + 8 × 7 (TIMESTAMPTZ) = 80 + 56 = 136
- Mapa de bits: 1 byte (2 campos NULL, < 8 → 1 byte)
- Overhead tupla: 23 bytes
- Campos variables: 24 (estado) + 504 (comentarios) = 528

Total:

$$
L = 8 + 136 + 1 + 23 + 528 = 696\ bytes
$$

#### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{696 + 4} \right\rfloor = \left\lfloor \frac{8092}{700} \right\rfloor = 11
$$

#### 4. Proyección de tuplas ($T_R$)

Supongamos: 1,800,000 reservas en 5 años (≈ 3,000 empleados × 8 citas/día × 250 días hábiles/año × 3 años de operación plena)

#### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{1{,}800{,}000}{11} \right\rceil = 163{,}637\ páginas
$$

$$
Volumen\ total = 163{,}637 \times 8192 = 1{,}340{,}911{,}616\ bytes \approx 1{,}279\ MB \approx 1.25\ GB
$$

# Volumen de datos por tabla aproximado

## Plantilla para cálculo de volumen de datos

### Paso 1: Calcular la longitud estimada del registro (L)

**Fórmula:**
$$
L = 4 \times (\#\ cam\_var) + \sum size(campos\_fijos) + size(mapa\_bits) + \sum t
$$

Donde:

- $\#\ cam\_var$: Número de campos de longitud variable (VARCHAR, TEXT, etc.)
- $\sum size(campos\_fijos)$: Suma de tamaños de campos de longitud fija (UUID, INT, BOOL, TIMESTAMP, etc.)
- $size(mapa\_bits)$: 1 bit por cada campo que puede ser NULL (aprox. redondear a 1 byte cada 8 campos)
- $\sum t$: Overhead de tupla (cabecera, punteros, etc. - en PostgreSQL suele ser 23 bytes)

### Paso 2: Calcular el factor de almacenamiento ($F_R$)

**Fórmula:**

$$
F_R = \left\lfloor \frac{P - espacio\_control}{L + 4} \right\rfloor
$$
Donde:

- $P$: Tamaño de página (por defecto 8KB = 8192 bytes en PostgreSQL)
- $espacio\_control$: Espacio reservado para control (aprox. 100 bytes por página)
- $L$: Longitud estimada del registro

### Paso 3: Estimar el número total de tuplas ($T_R$)

Proyectar la cantidad de registros esperados (carga inicial + crecimiento a 5 años).

### Paso 4: Calcular el número de páginas y volumen total

**Fórmulas:**
$$
B_R = \left\lceil \frac{T_R}{F_R} \right\rceil
$$
$$
Volumen\ total = B_R \times P
$$

---

## Ejemplo: Tabla USUARIO (MS-AUTH)

### 1. Identificación de columnas

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

### 2. Cálculo de longitud estimada del registro (L)

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

### 3. Factor de almacenamiento ($F_R$)

$$
F_R = \left\lfloor \frac{8192 - 100}{504 + 4} \right\rfloor = \left\lfloor \frac{8092}{508} \right\rfloor = 15
$$

### 4. Proyección de tuplas ($T_R$)

Supongamos: 5,000 usuarios en 5 años

### 5. Número de páginas y volumen total

$$
B_R = \left\lceil \frac{5000}{15} \right\rceil = 334\ páginas
$$
$$
Volumen\ total = 334 \times 8192 = 2,735,  728\ bytes \approx 2.6\ MB
$$

---

## MS-AUTH

## MS-CATALOG

## MS-SCHEDULE

## MS-RESERVATION

# Definición de Roles y Esquema de Seguridad

## Definición de Roles (RBAC)

| Rol | Descripción | Nivel de acceso |
| --- | ----------- | --------------- |
| anon | Usuario no autenticado | Acceso solo a datos públicos. |
| authenticated | Usuario base logueado | |
| admin | Administrador del sistema | Acceso total para gestión y soporte. |
| PROVEEDOR | Proveedor de servicios | |
| CLIENTE | Usuario final | |


## Matriz de Permisos por Entidad

La implementación técnica completa se encuentra en los DDLs usando RLS de Supabase.

---

## MS-AUTH

### Tabla USUARIO

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| authenticated (propio) | ✔ | ✘ | ✔ | ✘ | Solo puede ver y editar su propio registro. No puede cambiar `email`, `tipo_usuario` ni `fecha_registro`. |
| admin | ✔ | ✔ | ✔ | ✔ | Acceso total por meta-data. |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend (bloqueos, intentos fallidos, etc.). |

#### Implementación Técnica

```sql
CREATE POLICY "usuarios_pueden_ver_su_propio_perfil"
ON usuario FOR SELECT
USING (
    id_usuario = auth.uid()
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "usuarios_pueden_actualizar_su_propio_perfil"
ON usuario FOR UPDATE
USING (id_usuario = auth.uid())
WITH CHECK (
    id_usuario = auth.uid()
    AND email = email
    AND tipo_usuario = tipo_usuario
    AND fecha_registro = fecha_registro
);

CREATE POLICY "solo_admin_puede_insertar_usuarios"
ON usuario FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_eliminar_usuarios"
ON usuario FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "service_account_puede_actualizar_seguridad_usuario"
ON usuario FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'service_account'
    )
);
```

---

### Tabla CLIENTE

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| authenticated (propio) | ✔ | ✘ | ✔ | ✘ | Solo puede ver y editar su propio perfil de cliente. |
| admin / soporte | ✔ | ✔ | ✘ | ✘ | Puede ver todos los clientes. Solo admin/service_account puede insertar. |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "clientes_pueden_ver_su_propia_info"
ON cliente FOR SELECT
USING (
    id_usuario = auth.uid()
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);

CREATE POLICY "clientes_pueden_actualizar_su_propia_info"
ON cliente FOR UPDATE
USING (id_usuario = auth.uid())
WITH CHECK (id_usuario = id_usuario);

CREATE POLICY "solo_backend_puede_insertar_clientes"
ON cliente FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND (
            auth.users.raw_user_meta_data->>'role' = 'admin'
            OR auth.users.raw_user_meta_data->>'role' = 'service_account'
        )
    )
);
```

---

### Tabla PROVEEDOR

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| authenticated (propio) | ✔ | ✘ | ✔ | ✘ | Solo puede ver y editar su propio perfil. No puede cambiar `id_categoria`. |
| admin / soporte | ✔ | ✘ | ✔ | ✘ | Puede ver y verificar/modificar todos los proveedores. |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "proveedores_pueden_ver_su_propia_info"
ON proveedor FOR SELECT
USING (
    id_usuario = auth.uid()
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);

CREATE POLICY "proveedores_pueden_actualizar_su_propia_info"
ON proveedor FOR UPDATE
USING (id_usuario = auth.uid())
WITH CHECK (id_usuario = id_usuario AND id_categoria = id_categoria);

CREATE POLICY "solo_admin_puede_verificar_proveedores"
ON proveedor FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);
```

---

### Tabla ADMIN

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| admin | ✔ | ✔ | ✔ | ✔ | Acceso total. Solo admins pueden crear/modificar/eliminar otros admins. |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "admin_puede_ver_todos_admins"
ON admin FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_insertar_admins"
ON admin FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_superadmin_puede_eliminar_admins"
ON admin FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);
```

---

### Tabla INTENTO_LOGIN

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| authenticated (propio) | ✔ | ✘ | ✘ | ✘ | Solo puede ver sus propios intentos de login. |
| admin / security | ✔ | ✘ | ✘ | ✘ | Puede ver todos los intentos de login. |
| sistema (anon) | ✘ | ✔ | ✘ | ✔ | El sistema puede registrar intentos y limpiar logs con más de 90 días. |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "usuarios_pueden_ver_sus_intentos_login"
ON intento_login FOR SELECT
USING (id_usuario = auth.uid());

CREATE POLICY "admin_puede_ver_todos_intentos_login"
ON intento_login FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'security')
    )
);

CREATE POLICY "sistema_puede_registrar_intentos_login"
ON intento_login FOR INSERT
WITH CHECK (TRUE);

CREATE POLICY "sistema_puede_limpiar_logs_antiguos"
ON intento_login FOR DELETE
USING (fecha_hora < NOW() - INTERVAL '90 days');
```

---

### Tabla TOKEN_REFRESH

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| authenticated (propio) | ✔ | ✘ | ✔ | ✘ | Solo puede ver sus tokens y revocarlos (solo puede marcar `revocado = TRUE`). |
| sistema (anon) | ✘ | ✔ | ✘ | ✔ | El sistema puede emitir tokens y eliminar los expirados/revocados. |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "usuarios_pueden_ver_sus_propios_tokens"
ON token_refresh FOR SELECT
USING (id_usuario = auth.uid());

CREATE POLICY "sistema_puede_insertar_tokens"
ON token_refresh FOR INSERT
WITH CHECK (TRUE);

CREATE POLICY "usuarios_pueden_revocar_sus_tokens"
ON token_refresh FOR UPDATE
USING (id_usuario = auth.uid())
WITH CHECK (id_usuario = id_usuario AND revocado = TRUE);

CREATE POLICY "sistema_puede_eliminar_tokens_expirados"
ON token_refresh FOR DELETE
USING (fecha_expiracion < NOW() OR revocado = TRUE);
```

---

### Tabla TOKEN_RESET_PASSWORD

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| authenticated (propio) | ✔ | ✘ | ✔ | ✘ | Solo puede ver sus tokens y marcarlos como usados (token vigente y no usado). |
| sistema (anon) | ✘ | ✔ | ✘ | ✘ | El sistema puede crear tokens de reset. |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "usuarios_pueden_ver_sus_tokens_reset"
ON token_reset_password FOR SELECT
USING (id_usuario = auth.uid());

CREATE POLICY "sistema_puede_crear_tokens_reset"
ON token_reset_password FOR INSERT
WITH CHECK (TRUE);

CREATE POLICY "usuarios_pueden_usar_su_token_reset"
ON token_reset_password FOR UPDATE
USING (
    id_usuario = auth.uid()
    AND usado = FALSE
    AND fecha_expiracion > NOW()
)
WITH CHECK (id_usuario = id_usuario AND usado = TRUE);
```

---

### Tabla EMAIL_VERIFICATION_TOKEN

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| authenticated (propio) | ✔ | ✘ | ✔ | ✘ | Solo puede ver su token y marcarlo como usado (token vigente y no usado). |
| sistema (anon) | ✘ | ✔ | ✘ | ✘ | El sistema puede crear tokens de verificación. |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "usuarios_pueden_ver_su_token_verificacion"
ON email_verification_token FOR SELECT
USING (id_usuario = auth.uid());

CREATE POLICY "sistema_puede_crear_tokens_verificacion"
ON email_verification_token FOR INSERT
WITH CHECK (TRUE);

CREATE POLICY "usuarios_pueden_verificar_su_email"
ON email_verification_token FOR UPDATE
USING (
    id_usuario = auth.uid()
    AND usado = FALSE
    AND fecha_expiracion > NOW()
)
WITH CHECK (id_usuario = id_usuario AND usado = TRUE);
```

---

### Tabla REGISTRO_AUDITORIA

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| admin | ✔ | ✘ | ✘ | ✘ | Solo los administradores pueden consultar el registro de auditoría. |
| sistema (trigger) | ✘ | ✔ | ✘ | ✘ | Los registros son insertados automáticamente por el trigger `auditar_cambios_sensibles`. |

#### Implementación Técnica

```sql
CREATE POLICY "solo_admin_puede_ver_registro_auditoria"
ON registro_auditoria FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);
```

---

## MS-CATALOG

### Tabla CATEGORIA_SERVICIO

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| anon / authenticated | ✔ | ✘ | ✘ | ✘ | Solo pueden ver categorías activas (`activa = TRUE`). |
| admin | ✔ | ✔ | ✔ | ✔ | Acceso total por meta-data. Puede ver todas las categorías (activas e inactivas). |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "categorias_activas_publicas"
ON categoria_servicio FOR SELECT
USING (activa = TRUE);

CREATE POLICY "admin_puede_ver_todas_categorias"
ON categoria_servicio FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_insertar_categorias"
ON categoria_servicio FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_actualizar_categorias"
ON categoria_servicio FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_eliminar_categorias"
ON categoria_servicio FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);
```

---

### Tabla SERVICIO

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| anon / authenticated | ✔ | ✘ | ✘ | ✘ | Solo pueden ver servicios activos (`activo = TRUE`). |
| PROVEEDOR (propio) | ✔ | ✔ | ✔ | ✘ | Puede ver todos sus servicios (activos e inactivos), crear nuevos y actualizarlos/desactivarlos. Solo puede insertar si `tipo_usuario = PROVEEDOR`. |
| admin / soporte | ✔ | ✘ | ✔ | ✔ | Puede ver todos los servicios y actualizar cualquiera. Solo admin puede eliminar. |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "servicios_activos_publicos"
ON servicio FOR SELECT
USING (activo = TRUE);

CREATE POLICY "proveedores_pueden_ver_sus_servicios"
ON servicio FOR SELECT
USING (
    id_proveedor = auth.uid()
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);

CREATE POLICY "proveedores_pueden_crear_sus_servicios"
ON servicio FOR INSERT
WITH CHECK (
    id_proveedor = auth.uid()
    AND EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'tipo_usuario' = 'PROVEEDOR'
    )
);

CREATE POLICY "proveedores_pueden_actualizar_sus_servicios"
ON servicio FOR UPDATE
USING (
    id_proveedor = auth.uid()
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "proveedores_pueden_desactivar_sus_servicios"
ON servicio FOR UPDATE
USING (id_proveedor = auth.uid())
WITH CHECK (id_proveedor = id_proveedor AND activo = FALSE);

CREATE POLICY "solo_admin_puede_eliminar_servicios"
ON servicio FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);
```

---

## MS-SCHEDULE

### Tabla EMPLEADO

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| PROVEEDOR (propio) | ✔ | ✔ | ✔ | ✘ | Puede ver, crear y actualizar sus propios empleados. Puede desactivarlos (`activo = FALSE`). |
| admin / soporte | ✔ | ✘ | ✔ | ✔ | Puede ver y actualizar todos los empleados. Solo admin puede eliminar. |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "proveedores_pueden_ver_sus_empleados"
ON empleado FOR SELECT
USING (
    id_proveedor = auth.uid()
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);

CREATE POLICY "proveedores_pueden_crear_sus_empleados"
ON empleado FOR INSERT
WITH CHECK (
    id_proveedor = auth.uid()
    AND EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'tipo_usuario' = 'PROVEEDOR'
    )
);

CREATE POLICY "proveedores_pueden_actualizar_sus_empleados"
ON empleado FOR UPDATE
USING (
    id_proveedor = auth.uid()
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "proveedores_pueden_desactivar_sus_empleados"
ON empleado FOR UPDATE
USING (id_proveedor = auth.uid())
WITH CHECK (id_proveedor = id_proveedor AND activo = FALSE);

CREATE POLICY "solo_admin_puede_eliminar_empleados"
ON empleado FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);
```

---

### Tabla EMPLEADO_SERVICIO

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| PROVEEDOR (propio) | ✔ | ✔ | ✔ | ✘ | Puede gestionar las asignaciones de servicios de sus propios empleados. Solo puede operar si `tipo_usuario = PROVEEDOR`. |
| admin / soporte | ✔ | ✘ | ✔ | ✘ | Puede ver y actualizar todas las asignaciones. |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "proveedores_pueden_ver_sus_empleado_servicios"
ON empleado_servicio FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM empleado e
        WHERE e.id_empleado = empleado_servicio.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);

CREATE POLICY "proveedores_pueden_crear_sus_empleado_servicios"
ON empleado_servicio FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM empleado e
        WHERE e.id_empleado = empleado_servicio.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    AND EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'tipo_usuario' = 'PROVEEDOR'
    )
);

CREATE POLICY "proveedores_pueden_actualizar_sus_empleado_servicios"
ON empleado_servicio FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM empleado e
        WHERE e.id_empleado = empleado_servicio.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);
```

---

### Tabla HORARIO_LABORAL

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| PROVEEDOR (propio) | ✔ | ✔ | ✔ | ✘ | Puede gestionar los horarios laborales de sus propios empleados. Solo puede operar si `tipo_usuario = PROVEEDOR`. |
| admin / soporte | ✔ | ✘ | ✔ | ✘ | Puede ver y actualizar todos los horarios. |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "proveedores_pueden_ver_sus_horarios_laborales"
ON horario_laboral FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM empleado e
        WHERE e.id_empleado = horario_laboral.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);

CREATE POLICY "proveedores_pueden_crear_sus_horarios_laborales"
ON horario_laboral FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM empleado e
        WHERE e.id_empleado = horario_laboral.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    AND EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'tipo_usuario' = 'PROVEEDOR'
    )
);

CREATE POLICY "proveedores_pueden_actualizar_sus_horarios_laborales"
ON horario_laboral FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM empleado e
        WHERE e.id_empleado = horario_laboral.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);
```

---

### Tabla BLOQUEO_HORARIO

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| PROVEEDOR (propio) | ✔ | ✘ | ✔ | ✘ | Puede ver y actualizar los bloqueos de sus propios empleados. |
| admin / soporte | ✔ | ✘ | ✔ | ✘ | Puede ver y actualizar todos los bloqueos. |
| sistema (anon) | ✘ | ✔ | ✘ | ✘ | El sistema puede crear bloqueos (reservas, vacaciones, permisos, etc.). |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "proveedores_pueden_ver_sus_bloqueos_horarios"
ON bloqueo_horario FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM empleado e
        WHERE e.id_empleado = bloqueo_horario.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);

CREATE POLICY "sistema_puede_crear_bloqueos_horarios"
ON bloqueo_horario FOR INSERT
WITH CHECK (TRUE);

CREATE POLICY "proveedores_pueden_actualizar_sus_bloqueos_horarios"
ON bloqueo_horario FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM empleado e
        WHERE e.id_empleado = bloqueo_horario.id_empleado
        AND e.id_proveedor = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);
```

---

## MS-RESERVATION

### Tabla RESERVA

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| CLIENTE (propio) | ✔ | ✔ | ✔ | ✘ | Puede ver sus propias reservas, crear nuevas (si `tipo_usuario = CLIENTE`) y cancelarlas (solo puede actualizar `estado` a `CANCELADA` o `NO_SHOW`). |
| PROVEEDOR (propio) | ✔ | ✘ | ✔ | ✘ | Puede ver y actualizar las reservas asociadas a su negocio. |
| admin / soporte | ✔ | ✘ | ✔ | ✔ | Puede ver y actualizar todas las reservas. Solo admin puede eliminar. |
| service_account | ✔ | ✔ | ✔ | ✔ | Acceso total para operaciones de backend. |

#### Implementación Técnica

```sql
CREATE POLICY "clientes_pueden_ver_sus_reservas"
ON reserva FOR SELECT
USING (
    id_cliente = auth.uid()
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);

CREATE POLICY "proveedores_pueden_ver_sus_reservas"
ON reserva FOR SELECT
USING (
    id_proveedor = auth.uid()
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'soporte')
    )
);

CREATE POLICY "clientes_pueden_crear_sus_reservas"
ON reserva FOR INSERT
WITH CHECK (
    id_cliente = auth.uid()
    AND EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'tipo_usuario' = 'CLIENTE'
    )
);

CREATE POLICY "clientes_pueden_cancelar_sus_reservas"
ON reserva FOR UPDATE
USING (id_cliente = auth.uid())
WITH CHECK (
    id_cliente = id_cliente
    AND estado IN ('CANCELADA', 'NO_SHOW')
);

CREATE POLICY "proveedores_pueden_actualizar_sus_reservas"
ON reserva FOR UPDATE
USING (
    id_proveedor = auth.uid()
    OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "admin_puede_ver_todas_reservas"
ON reserva FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "solo_admin_puede_eliminar_reservas"
ON reserva FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

CREATE POLICY "service_account_reserva_full_access"
ON reserva FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id::UUID = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'service_account'
    )
);
```

---

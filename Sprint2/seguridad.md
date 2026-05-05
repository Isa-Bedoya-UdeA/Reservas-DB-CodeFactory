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

La implementación técnica completa se encuentra en los DDLs usando RLS de supabase.

### MS-AUTH

#### Tabla USUARIO

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| admin | ✔ | ✔ | ✔ | ✔ | Acceso total por meta-data. |

##### Implementación Técnica

```sql
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
...
```

### MS-CATALOG

#### Tabla CATEGORIA_SERVICIO

| Rol | SELECT | INSERT | UPDATE | DELETE | Lógica de la Política |
| --- | ------ | ------ | ------ | ------ | --------------------- |
| admin | ✔ | ✔ | ✔ | ✔ | Acceso total por meta-data. |
| PROVEEDOR | ✔ | ✘ | ✘ | ✘ | ... |

### MS-SCHEDULE

### MS-RESERVATION

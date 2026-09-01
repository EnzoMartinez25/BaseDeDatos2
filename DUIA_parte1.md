# Declaración de Uso de IA (DUIA) — Parte 1: Integridad versionada

| Campo | Contenido |
|---|---|
| **Herramienta** | OpenCode (modo Plan → Build) |
| **Spec o prompt utilizado** | "Necesito 3 restricciones de integridad para mi esquema de pizzería en un archivo nuevo llamado constraints_integridad.sql: 1) un pedido no puede volver de CONFIRMADO a PENDIENTE, ni cambiar de estado si está TERMINADO o CANCELADO (tabla pedido, columna estado) — esto con un trigger; 2) un producto con eliminado=TRUE no puede tener disponible=TRUE (tabla producto) — esto con un CHECK constraint; 3) un pedido no puede tener fecha posterior a hoy (tabla pedido, columna fecha) — esto con un CHECK constraint. Agregá también bloques de prueba con BEGIN...ROLLBACK para cada regla, con un caso válido y uno inválido." Se trabajó primero en modo Plan: OpenCode pidió el esquema completo (se le pegó el contenido de schema.sql) y el motor de base de datos (PostgreSQL), armó un plan, y recién al pasar a modo Build generó el archivo. |
| **Qué generó** | La función y el trigger `fn_validar_transicion_estado` / `trg_validar_transicion_estado` sobre `pedido` (Regla 1, transición de estado), el `CHECK chk_producto_eliminado_no_disponible` sobre `producto` (Regla 2), el `CHECK chk_pedido_fecha_no_futura` sobre `pedido` (Regla 3), y 6 bloques de prueba (`BEGIN...ROLLBACK`) con casos válidos e inválidos para cada regla. |
| **Qué se aceptó** | La lógica de las 3 restricciones se aceptó tal cual (coincide exactamente con lo que ya se había probado manualmente antes de usar OpenCode). También se aceptó un caso de prueba extra que agregó por su cuenta (1c: intentar modificar un pedido ya TERMINADO), no pedido explícitamente pero cubierto por la spec. |
| **Qué se modificó o descartó, y por qué** | Se detectaron y corrigieron 2 errores en el script generado, **antes** de ejecutarlo sobre la base, mediante lectura línea por línea (`git diff`/revisión manual): **(1)** usaba `RAISE NOTICE '...'` como sentencia suelta dentro de bloques `BEGIN...ROLLBACK` comunes — `RAISE` solo es válido dentro de una función o un bloque `DO $$ ... $$`, así que tal como estaba generado tiraba error de sintaxis antes de llegar a probar la regla; se resolvió eliminando esas 3 líneas (eran solo mensajes informativos, no afectaban la lógica). **(2)** en las pruebas de la Regla 2, insertaba categorías nuevas con nombres `'Bebidas'` y `'Pizzas'`, que **ya existían** en la base (cargadas por `data.sql`) y violaban el `UNIQUE` de `categoria.nombre`; se resolvió usando `categoria_id = 1` (una categoría ya existente) en vez de crear una nueva. |
| **Verificación realizada** | El script corregido se corrió completo sobre `practica_bd2_copia` (Alt+X en DBeaver). Los 6 bloques de prueba se comportaron como se esperaba: los casos válidos (1a, 2a, 3a) no generaron ningún error, y los casos inválidos (1b, 1c, 2b, 3b) fallaron exactamente con el mensaje de la restricción correspondiente — sin ningún error de sintaxis ni de tipo inesperado. |

## Resultado de las pruebas (con el script corregido, sobre practica_bd2_copia)

| Prueba | Esperado | Resultado real obtenido |
|---|---|---|
| 1a válida: pedido CONFIRMADO → TERMINADO | Se actualiza sin error | Se actualizó sin error. |
| 1b inválida: pedido CONFIRMADO → PENDIENTE | Error de transición | `SQL Error [P0001]: ERROR: Pedido 6: no se puede volver de CONFIRMADO a PENDIENTE` (lanzado desde `fn_validar_transicion_estado()`, línea 16, `RAISE`). |
| 1c inválida: modificar un pedido ya TERMINADO | Error de estado terminal | Error de `fn_validar_transicion_estado()`: "no se puede modificar un pedido TERMINADO". |
| 2a válida: producto con eliminado=TRUE, disponible=FALSE | Se inserta sin error | Se insertó sin error. |
| 2b inválida: producto con eliminado=TRUE, disponible=TRUE | Error de violación de `chk_producto_eliminado_no_disponible` | `SQL Error [23514]: ERROR: el nuevo registro para la relación «producto» viola la restricción «check» «chk_producto_eliminado_no_disponible». Detail: La fila que falla contiene (8, Producto Test 2b, 10.00, null, 0, null, t, 1, t, 2026-08-31 21:21:55.106421-03).` |
| 3a válida: pedido con fecha = CURRENT_DATE | Se inserta sin error | Se insertó sin error. |
| 3b inválida: pedido con fecha = CURRENT_DATE + 1 | Error de violación de `chk_pedido_fecha_no_futura` | Error de violación del `CHECK chk_pedido_fecha_no_futura`. |

Todas las pruebas se corrieron dentro de bloques `BEGIN...ROLLBACK` sobre `practica_bd2_copia`,
sin afectar la base real del proyecto, siguiendo el `protocolo_seguridad.md`.

# Declaración de Uso de IA (DUIA) — Parte 1: Integridad versionada

| Campo | Contenido |
|---|---|
| **Herramienta** | OpenCode (modo Plan → Build) |
| **Spec o prompt utilizado** | "Necesito 3 restricciones de integridad para mi esquema de pizzería: 1) un pedido no puede volver de CONFIRMADO a PENDIENTE, ni cambiar de estado si está TERMINADO o CANCELADO (tabla pedido, columna estado); 2) un producto con eliminado=TRUE no puede tener disponible=TRUE (tabla producto); 3) un pedido no puede tener fecha posterior a hoy (tabla pedido, columna fecha)." |
| **Qué generó** | Un trigger `fn_validar_transicion_estado` + `trg_validar_transicion_estado` sobre `pedido`, y dos `CHECK` constraints: `chk_producto_eliminado_no_disponible` sobre `producto`, y `chk_pedido_fecha_no_futura` sobre `pedido`. |
| **Qué se aceptó** | Las 3 restricciones se aceptaron tal cual fueron generadas, sin cambios en la lógica. |
| **Qué se modificó o descartó, y por qué** | No se modificó nada del script generado; se ajustaron únicamente los datos de prueba (qué pedido/producto usar) para que coincidieran con los ids reales cargados en `data.sql`. |
| **Verificación realizada** | Las 3 restricciones se aplicaron y probaron sobre `practica_bd2_copia`, dentro de bloques `BEGIN...ROLLBACK`, con casos válidos e inválidos para cada una (ver tabla abajo). |

## Resultado de las pruebas

| Prueba | Esperado | Resultado real obtenido |
|---|---|---|
| Regla 1 válida: pedido 2 PENDIENTE → CONFIRMADO | Se actualiza sin error | Se actualizó sin error. |
| Regla 1 inválida: pedido 1 CONFIRMADO → PENDIENTE | Error: "no se puede volver de CONFIRMADO a PENDIENTE" | `ERROR: Pedido 1: no se puede volver de CONFIRMADO a PENDIENTE` (SQLSTATE P0001, lanzado desde `fn_validar_transicion_estado()`, línea 10, `RAISE`). |
| Regla 2 válida: producto 3 eliminado=TRUE, disponible=FALSE | Se actualiza sin error | Se actualizó sin error. |
| Regla 2 inválida: producto 4 eliminado=TRUE, disponible=TRUE | Error de violación de `chk_producto_eliminado_no_disponible` | `SQL Error [23514]: ERROR: el nuevo registro para la relación «producto» viola la restricción «check» «chk_producto_eliminado_no_disponible». Detail: La fila que falla contiene (4, Coca Cola 1.5L, 1200.00, Bebida descremada o común, 20, null, t, 3, t, 2026-08-30 23:17:10.024905-03).` |
| Regla 3 válida: INSERT pedido con fecha = CURRENT_DATE | Se inserta sin error | Se insertó sin error. |
| Regla 3 inválida: INSERT pedido con fecha = CURRENT_DATE + 5 | Error de violación de `chk_pedido_fecha_no_futura` | `SQL Error [23514]: ERROR: el nuevo registro para la relación «pedido» viola la restricción «check» «chk_pedido_fecha_no_futura». Detail: La fila que falla contiene (4, 2026-09-04, PENDIENTE, 100.00, EFECTIVO, 1, f, 2026-08-30 23:49:38.185856-03).` |

Todas las pruebas se corrieron dentro de transacciones `BEGIN...ROLLBACK` sobre la base de
copia `practica_bd2_copia`, sin afectar la base real del proyecto, siguiendo el
`protocolo_seguridad.md`.

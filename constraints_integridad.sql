-- =====================================================================
--  Restricciones de integridad - Pizzería
--  Generado con OpenCode (modo Plan -> Build), corregido tras lectura
--  crítica del script antes de aplicarlo (ver DUIA_parte1.md).
--
--  1. Trigger : un pedido no puede volver de CONFIRMADO a PENDIENTE,
--     ni cambiar de estado si está TERMINADO o CANCELADO.
--  2. CHECK   : un producto con eliminado = TRUE no puede tener
--     disponible = TRUE.
--  3. CHECK   : un pedido no puede tener fecha posterior a hoy.
--
--  Cada regla incluye bloques de prueba con BEGIN...ROLLBACK
--  (un caso válido y uno inválido).
-- =====================================================================


-- =====================================================================
--  Limpieza idempotente (para que el script sea re-ejecutable)
-- =====================================================================
DROP TRIGGER IF EXISTS trg_validar_transicion_estado ON pedido;

ALTER TABLE producto DROP CONSTRAINT IF EXISTS chk_producto_eliminado_no_disponible;
ALTER TABLE pedido   DROP CONSTRAINT IF EXISTS chk_pedido_fecha_no_futura;


-- =====================================================================
--  REGLA 1 : transiciones de estado del pedido
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_validar_transicion_estado()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- No hay cambio real: no se valida nada.
    IF NEW.estado = OLD.estado THEN
        RETURN NEW;
    END IF;

    -- Estados terminales: no se permite ningún cambio.
    IF OLD.estado IN ('TERMINADO', 'CANCELADO') THEN
        RAISE EXCEPTION 'Pedido %: no se puede modificar un pedido %',
                        OLD.id, OLD.estado;
    END IF;

    -- Un pedido CONFIRMADO no puede volver a PENDIENTE.
    IF OLD.estado = 'CONFIRMADO' AND NEW.estado = 'PENDIENTE' THEN
        RAISE EXCEPTION 'Pedido %: no se puede volver de CONFIRMADO a PENDIENTE',
                        OLD.id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_transicion_estado
    BEFORE UPDATE ON pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_transicion_estado();


-- =====================================================================
--  REGLA 2 : producto eliminado no puede estar disponible
-- =====================================================================
ALTER TABLE producto
    ADD CONSTRAINT chk_producto_eliminado_no_disponible
    CHECK ( NOT (eliminado = TRUE AND disponible = TRUE) );


-- =====================================================================
--  REGLA 3 : fecha del pedido no posterior a hoy
-- =====================================================================
ALTER TABLE pedido
    ADD CONSTRAINT chk_pedido_fecha_no_futura
    CHECK ( fecha <= CURRENT_DATE );


-- =====================================================================
--  PRUEBAS
--  NOTA (corrección tras lectura crítica del script generado):
--  - Se quitaron las líneas "RAISE NOTICE ..." sueltas: ese comando solo
--    es válido dentro de una función o un bloque DO $$ ... $$, no como
--    sentencia libre dentro de un BEGIN...ROLLBACK; tal como estaba
--    generado, tiraba error de sintaxis antes de llegar a probar nada.
--  - Se reemplazó el INSERT de categorías nuevas ('Bebidas', 'Pizzas')
--    por el uso de categoria_id = 1 (ya existente, cargada en data.sql),
--    porque esos nombres ya existen y categoria.nombre es UNIQUE:
--    insertarlos de nuevo violaba esa restricción antes de llegar a
--    probar la Regla 2.
-- =====================================================================

-- ---------------------------------------------------------------------
--  REGLA 1 : Trigger de transición de estado
-- ---------------------------------------------------------------------

-- 1a. Caso VÁLIDO: CONFIRMADO -> TERMINADO (debe funcionar)
BEGIN;

    INSERT INTO usuario (nombre, apellido, mail, contrasena)
    VALUES ('Juan', 'Perez', 'juan@test.com', 'clave123');

    INSERT INTO pedido (fecha, estado, total, forma_pago, usuario_id)
    SELECT CURRENT_DATE, 'PENDIENTE', 100.00, 'EFECTIVO', id
    FROM usuario
    WHERE mail = 'juan@test.com';

    UPDATE pedido SET estado = 'CONFIRMADO'
    WHERE usuario_id = (SELECT id FROM usuario WHERE mail = 'juan@test.com');

    -- Transición válida: CONFIRMADO -> TERMINADO
    UPDATE pedido SET estado = 'TERMINADO'
    WHERE usuario_id = (SELECT id FROM usuario WHERE mail = 'juan@test.com');

ROLLBACK;

-- 1b. Caso INVÁLIDO: CONFIRMADO -> PENDIENTE (debe fallar)
BEGIN;

    INSERT INTO usuario (nombre, apellido, mail, contrasena)
    VALUES ('Ana', 'Gomez', 'ana@test.com', 'clave123');

    INSERT INTO pedido (fecha, estado, total, forma_pago, usuario_id)
    SELECT CURRENT_DATE, 'PENDIENTE', 80.00, 'TARJETA', id
    FROM usuario
    WHERE mail = 'ana@test.com';

    UPDATE pedido SET estado = 'CONFIRMADO'
    WHERE usuario_id = (SELECT id FROM usuario WHERE mail = 'ana@test.com');

    -- Transición inválida: CONFIRMADO -> PENDIENTE
    UPDATE pedido SET estado = 'PENDIENTE'
    WHERE usuario_id = (SELECT id FROM usuario WHERE mail = 'ana@test.com');

ROLLBACK;

-- 1c. Caso INVÁLIDO: modificar un pedido TERMINADO (debe fallar)
BEGIN;

    INSERT INTO usuario (nombre, apellido, mail, contrasena)
    VALUES ('Luis', 'Diaz', 'luis@test.com', 'clave123');

    INSERT INTO pedido (fecha, estado, total, forma_pago, usuario_id)
    SELECT CURRENT_DATE, 'TERMINADO', 60.00, 'TRANSFERENCIA', id
    FROM usuario
    WHERE mail = 'luis@test.com';

    -- Transición inválida: TERMINADO debe quedarse igual
    UPDATE pedido SET estado = 'CONFIRMADO'
    WHERE usuario_id = (SELECT id FROM usuario WHERE mail = 'luis@test.com');

ROLLBACK;


-- ---------------------------------------------------------------------
--  REGLA 2 : CHECK de producto eliminado / disponible
--  (usa categoria_id = 1, ya cargada por data.sql, en vez de crear
--  una categoría nueva)
-- ---------------------------------------------------------------------

-- 2a. Caso VÁLIDO: eliminado = TRUE, disponible = FALSE (debe funcionar)
BEGIN;

    INSERT INTO producto (nombre, precio, descripcion, disponible, categoria_id, eliminado)
    VALUES ('Producto Test 2a', 3.50, NULL, FALSE, 1, TRUE);

ROLLBACK;

-- 2b. Caso INVÁLIDO: eliminado = TRUE, disponible = TRUE (debe fallar)
BEGIN;

    -- Transgresión: eliminado y disponible a la vez
    INSERT INTO producto (nombre, precio, descripcion, disponible, categoria_id, eliminado)
    VALUES ('Producto Test 2b', 10.00, NULL, TRUE, 1, TRUE);

ROLLBACK;


-- ---------------------------------------------------------------------
--  REGLA 3 : CHECK de fecha del pedido
-- ---------------------------------------------------------------------

-- 3a. Caso VÁLIDO: fecha = hoy (debe funcionar)
BEGIN;

    INSERT INTO usuario (nombre, apellido, mail, contrasena)
    VALUES ('Maria', 'Lopez', 'maria@test.com', 'clave123');

    INSERT INTO pedido (fecha, estado, total, forma_pago, usuario_id)
    SELECT CURRENT_DATE, 'PENDIENTE', 45.00, 'EFECTIVO', id
    FROM usuario
    WHERE mail = 'maria@test.com';

ROLLBACK;

-- 3b. Caso INVÁLIDO: fecha posterior a hoy (debe fallar)
BEGIN;

    INSERT INTO usuario (nombre, apellido, mail, contrasena)
    VALUES ('Pedro', 'Sanchez', 'pedro@test.com', 'clave123');

    -- Transgresión: fecha futura
    INSERT INTO pedido (fecha, estado, total, forma_pago, usuario_id)
    SELECT CURRENT_DATE + 1, 'PENDIENTE', 30.00, 'TARJETA', id
    FROM usuario
    WHERE mail = 'pedro@test.com';

ROLLBACK;

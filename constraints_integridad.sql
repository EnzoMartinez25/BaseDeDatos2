-- ============================================================
-- PARTE 1 — Restricciones de integridad versionada
-- Ejecutar SOLO sobre la copia de trabajo (practica_bd2_copia),
-- dentro de una transacción (BEGIN ... COMMIT/ROLLBACK), según
-- el protocolo_seguridad.md
-- ============================================================

-- ------------------------------------------------------------
-- Regla 1: Transición de estado de pedido válida
-- Spec: un pedido en estado CONFIRMADO o TERMINADO nunca puede
-- volver a PENDIENTE, y TERMINADO/CANCELADO son estados
-- terminales (no admiten ningún otro cambio de estado).
-- Tabla/columna: pedido.estado
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_transicion_estado()
RETURNS TRIGGER AS $$
BEGIN
    -- Los estados terminales no pueden cambiar a ningún otro estado
    IF OLD.estado IN ('TERMINADO', 'CANCELADO') AND NEW.estado <> OLD.estado THEN
        RAISE EXCEPTION 'Pedido %: % es un estado terminal, no admite cambios', OLD.id, OLD.estado;
    END IF;

    -- No se puede retroceder a PENDIENTE desde CONFIRMADO
    IF OLD.estado = 'CONFIRMADO' AND NEW.estado = 'PENDIENTE' THEN
        RAISE EXCEPTION 'Pedido %: no se puede volver de CONFIRMADO a PENDIENTE', OLD.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_transicion_estado
BEFORE UPDATE OF estado ON pedido
FOR EACH ROW EXECUTE FUNCTION fn_validar_transicion_estado();


-- ------------------------------------------------------------
-- Regla 2: Un producto dado de baja (eliminado) no puede
-- figurar como disponible.
-- Spec: no puede existir una fila de producto con
-- eliminado = TRUE y disponible = TRUE al mismo tiempo.
-- Tabla/columna: producto.eliminado, producto.disponible
-- ------------------------------------------------------------
ALTER TABLE producto
ADD CONSTRAINT chk_producto_eliminado_no_disponible
CHECK (NOT (eliminado = TRUE AND disponible = TRUE));


-- ------------------------------------------------------------
-- Regla 3: Rango de fecha coherente en pedidos.
-- Spec: un pedido no puede tener una fecha posterior al día
-- actual (no se pueden cargar pedidos "a futuro").
-- Tabla/columna: pedido.fecha
-- ------------------------------------------------------------
ALTER TABLE pedido
ADD CONSTRAINT chk_pedido_fecha_no_futura
CHECK (fecha <= CURRENT_DATE);


-- ============================================================
-- PRUEBAS — correr dentro de BEGIN; ... ROLLBACK; para no
-- ensuciar la copia de trabajo. Ejecutar cada bloque y anotar
-- el resultado real en la DUIA.
-- ============================================================

BEGIN;

-- Regla 1 — válido: PENDIENTE -> CONFIRMADO (debe funcionar)
UPDATE pedido SET estado = 'CONFIRMADO' WHERE id = 2; -- pedido 2 está PENDIENTE en data.sql

-- Regla 1 — inválido: CONFIRMADO -> PENDIENTE (debe fallar)
UPDATE pedido SET estado = 'PENDIENTE' WHERE id = 1; -- pedido 1 está CONFIRMADO en data.sql

ROLLBACK;


BEGIN;

-- Regla 2 — válido: dar de baja un producto y marcarlo no disponible (debe funcionar)
UPDATE producto SET eliminado = TRUE, disponible = FALSE WHERE id = 3;

-- Regla 2 — inválido: dar de baja un producto dejándolo disponible (debe fallar)
UPDATE producto SET eliminado = TRUE, disponible = TRUE WHERE id = 4;

ROLLBACK;


BEGIN;

-- Regla 3 — válido: pedido con fecha de hoy (debe funcionar)
INSERT INTO pedido (usuario_id, forma_pago, estado, total, fecha)
VALUES (1, 'EFECTIVO', 'PENDIENTE', 100.00, CURRENT_DATE);

-- Regla 3 — inválido: pedido con fecha futura (debe fallar)
INSERT INTO pedido (usuario_id, forma_pago, estado, total, fecha)
VALUES (1, 'EFECTIVO', 'PENDIENTE', 100.00, CURRENT_DATE + 5);

ROLLBACK;

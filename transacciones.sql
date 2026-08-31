SET search_path TO public;

-- 1. Atomicidad
SELECT count(*) AS pedidos_antes FROM pedido;
SELECT id, nombre, stock FROM producto WHERE id = 1;

DO $$
BEGIN
    CALL sp_crear_pedido(
        1, 
        'EFECTIVO', 
        '[{"producto_id": 1, "cantidad": 1}, {"producto_id": 999, "cantidad": 1}]'::jsonb
    );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Rollback: %', SQLERRM;
END $$;

DO $$
BEGIN
    CALL sp_crear_pedido(
        1, 
        'EFECTIVO', 
        '[{"producto_id": 1, "cantidad": 0}]'::jsonb
    );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Rollback: %', SQLERRM;
END $$;

SELECT count(*) AS pedidos_despues FROM pedido;
SELECT id, nombre, stock FROM producto WHERE id = 1;

-- 2. Transaccion manual
-- Commit
BEGIN;
    UPDATE producto SET stock = stock - 2 WHERE id = 1;
    WITH nuevo_pedido AS (
        INSERT INTO pedido (usuario_id, forma_pago, estado, total) 
        VALUES (1, 'EFECTIVO', 'CONFIRMADO', 3600.00)
        RETURNING id
    )
    INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
    SELECT id, 1, 2, 1800.00, 3600.00 FROM nuevo_pedido;
COMMIT;

SELECT id, stock FROM producto WHERE id = 1;
SELECT * FROM pedido ORDER BY id DESC LIMIT 1;

-- Rollback
BEGIN;
    UPDATE producto SET stock = 0 WHERE id = 2;
    UPDATE categoria SET eliminado = TRUE WHERE id = 3;
    SELECT id, stock FROM producto WHERE id = 2;
    SELECT id, eliminado FROM categoria WHERE id = 3;
ROLLBACK;

SELECT id, stock FROM producto WHERE id = 2;
SELECT id, eliminado FROM categoria WHERE id = 3;

-- 3. Aislamiento
UPDATE producto SET stock = 15 WHERE id = 2;
SELECT id, stock FROM producto WHERE id = 2;

-- 4. Bloqueos
UPDATE producto SET stock = 1 WHERE id = 1;
SELECT id, stock FROM producto WHERE id = 1;

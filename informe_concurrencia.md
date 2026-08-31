# Informe de Concurrencia — Proyecto Pizzería (Grupo C)

Se reproducen 3 de los 4 escenarios de la consigna, usando dos sesiones (psql o dos conexiones
en DBeaver) sobre `practica_bd2_copia`. Para cada uno: comandos exactos, explicación pedida
a la IA, verificación en el motor real, y conclusión.

**Cómo completar este archivo:** corran los comandos tal cual (Sesión A en una pestaña,
Sesión B en otra), reemplacen cada `[COMPLETAR]` por lo que efectivamente devolvió Postgres,
y borren estas instrucciones antes de entregar.

---

## Escenario 1 — Lectura no repetible

### Cómo se reprodujo

**Sesión A:**
```sql
BEGIN;
SELECT stock FROM producto WHERE id = 1;  -- 1) anotar el valor
-- esperar acá, sin hacer COMMIT, hasta que Sesión B confirme su UPDATE
SELECT stock FROM producto WHERE id = 1;  -- 2) repetir la misma consulta
COMMIT;
```

**Sesión B (se ejecuta mientras Sesión A está pausada entre el paso 1 y el 2):**
```sql
BEGIN;
UPDATE producto SET stock = stock - 3 WHERE id = 1;
COMMIT;
```

### Qué se observó
Primera lectura (Sesión A, antes del `UPDATE` de Sesión B): `stock = 10`.
Segunda lectura (misma transacción de Sesión A, después de que Sesión B confirmó su `UPDATE`):
`stock = 4`. La lectura cambió dentro de la misma transacción de Sesión A, sin que Sesión A
hiciera ningún `COMMIT` de por medio — eso es la lectura no repetible.

### Explicación de la IA
Con el nivel de aislamiento por defecto de PostgreSQL (`READ COMMITTED`), cada sentencia
`SELECT` dentro de una transacción ve los datos confirmados hasta ese momento — no una foto
fija de todo el inicio de la transacción. Por eso, si otra sesión modifica y confirma (`COMMIT`)
una fila entre dos lecturas de la misma transacción, la segunda lectura puede devolver un valor
distinto de la primera: eso es una lectura no repetible. El nivel `REPEATABLE READ` lo evita,
porque toma una única "foto" (snapshot) de la base al inicio de la transacción y todas las
lecturas dentro de esa transacción usan esa misma foto, sin importar qué confirmen otras
sesiones mientras tanto.

### Verificación en el motor
Repetir exactamente la misma secuencia, pero arrancando la Sesión A con:
```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT stock FROM producto WHERE id = 1;
-- esperar a que Sesión B haga su UPDATE + COMMIT
SELECT stock FROM producto WHERE id = 1;  -- ahora debería mostrar el MISMO valor que la primera
COMMIT;
```
Primera lectura bajo `REPEATABLE READ`: `stock = 4` (valor vigente en ese momento). Mientras esa
transacción seguía abierta, Sesión B ejecutó otro `UPDATE` (restando 2 más) y confirmó, dejando
el stock real en `2`. Segunda lectura, en la misma transacción de Sesión A: `stock = 4` — se
mantuvo igual, sin ver el cambio de Sesión B.

### Conclusión
La explicación de la IA se confirmó en el motor: bajo `READ COMMITTED` la lectura cambió
(10→4) dentro de la misma transacción, mientras que bajo `REPEATABLE READ` la lectura
permaneció congelada (4→4) a pesar de que Sesión B modificó y confirmó un cambio sobre la misma
fila. `REPEATABLE READ` es el nivel que resuelve esta anomalía.

---

## Escenario 2 — Lectura fantasma

### Cómo se reprodujo

**Sesión A:**
```sql
BEGIN;
SELECT COUNT(*) FROM producto WHERE categoria_id = 1;  -- 1) anotar el conteo (pizzas)
-- esperar acá, sin hacer COMMIT, hasta que Sesión B confirme el INSERT
SELECT COUNT(*) FROM producto WHERE categoria_id = 1;  -- 2) repetir el conteo
COMMIT;
```

**Sesión B (mientras A está pausada):**
```sql
BEGIN;
INSERT INTO producto (nombre, precio, stock, disponible, categoria_id)
VALUES ('Pizza Especial', 2500.00, 5, TRUE, 1);
COMMIT;
```

### Qué se observó
Primer conteo (Sesión A, antes del INSERT de Sesión B): **2** (Fugazzeta y Muzza Grande).
Segundo conteo (misma transacción de Sesión A, después de que Sesión B insertó y confirmó
"Pizza Especial"): **3**. El conteo cambió dentro de la misma transacción de Sesión A, sin que
Sesión A hiciera ningún `COMMIT` de por medio — eso es la lectura fantasma.

### Explicación de la IA
Una lectura fantasma ocurre cuando una consulta que filtra por una condición (`WHERE`) devuelve
un conjunto distinto de filas la segunda vez, porque otra transacción insertó (o eliminó) una
fila que ahora cumple esa condición. Con `READ COMMITTED`, cada `SELECT` ve los inserts ya
confirmados por otras sesiones, así que el segundo `COUNT` puede incluir la fila nueva. Con
`REPEATABLE READ`, PostgreSQL usa una técnica de instantánea de todo el estado de la base al
inicio de la transacción, por lo que —a diferencia de otros motores— también previene las
lecturas fantasma, no solo las no repetibles.

### Verificación en el motor
Repetir la secuencia completa, pero con Sesión A en `REPEATABLE READ`:
```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM producto WHERE categoria_id = 1;
-- esperar el INSERT + COMMIT de Sesión B
SELECT COUNT(*) FROM producto WHERE categoria_id = 1;  -- ¿cambió el conteo?
COMMIT;
```
Primer conteo bajo `REPEATABLE READ`: **3** (valor vigente en ese momento, incluyendo la Pizza
Especial ya confirmada antes). Mientras esa transacción seguía abierta, Sesión B insertó y
confirmó una segunda pizza nueva ("Pizza Cuatro Quesos"). Segundo conteo, en la misma
transacción de Sesión A: **3** — se mantuvo igual, sin ver la fila nueva de Sesión B.

### Conclusión
La explicación de la IA se confirmó en el motor: bajo `READ COMMITTED` el conteo cambió (2→3)
dentro de la misma transacción, mientras que bajo `REPEATABLE READ` el conteo permaneció
congelado (3→3) a pesar de que Sesión B insertó y confirmó una fila nueva que cumplía la
condición del `WHERE`. `REPEATABLE READ` es el nivel de aislamiento que resuelve esta anomalía
en PostgreSQL.

---

## Escenario 3 — Espera por bloqueo

### Cómo se reprodujo

**Sesión A:**
```sql
BEGIN;
SELECT * FROM producto WHERE id = 1 FOR UPDATE;
-- NO hacer COMMIT todavía: dejar la transacción abierta
```

**Sesión B (en otra pestaña, mientras A sigue abierta):**
```sql
BEGIN;
SELECT * FROM producto WHERE id = 1 FOR UPDATE;  -- esta consulta debería quedarse "colgada"
```

**Volver a Sesión A y recién ahí:**
```sql
COMMIT;
```

### Qué se observó
Al ejecutar `SELECT * FROM producto WHERE id = 1 FOR UPDATE;` en Sesión B mientras Sesión A
tenía la misma fila bloqueada (sin haber hecho `COMMIT` ni `ROLLBACK`), la consulta de Sesión B
quedó esperando sin devolver resultado (más de 27 segundos, sin ningún timeout automático).
Apenas se ejecutó `COMMIT;` en Sesión A, Sesión B se destrabó de inmediato y devolvió la fila
del producto 1.

### Explicación de la IA
`FOR UPDATE` toma un bloqueo exclusivo de fila (row-level lock) sobre las filas devueltas por
el `SELECT`, que se mantiene hasta que la transacción termina (`COMMIT` o `ROLLBACK`). Si otra
sesión intenta tomar el mismo bloqueo sobre la misma fila, PostgreSQL no la rechaza ni le
devuelve un valor "viejo": la deja esperando (bloqueada) hasta que la primera transacción libere
el bloqueo. Es el mecanismo que evita que dos transacciones concurrentes lean-y-modifiquen la
misma fila "a ciegas", sin que ninguna sepa lo que hizo la otra (evita el problema de
actualización perdida).

### Verificación en el motor
Se confirmó exactamente el comportamiento esperado: Sesión B permaneció bloqueada mientras
Sesión A mantuvo la transacción abierta, y se destrabó en el mismo instante en que Sesión A
ejecutó `COMMIT`. No hubo ningún error ni timeout — Postgres esperó indefinidamente hasta que
el bloqueo se liberó.

### Conclusión
La explicación de la IA se confirmó en el motor real: `FOR UPDATE` no es un nivel de
aislamiento, sino un mecanismo de bloqueo de fila. Es el mecanismo que resuelve este escenario,
garantizando que dos transacciones no puedan modificar la misma fila al mismo tiempo sin que
una espere a que la otra termine.

---

## (Opcional) Escenario 4 — Interbloqueo real

**Sesión A:**
```sql
BEGIN;
UPDATE producto SET stock = stock - 1 WHERE id = 1;
-- pausar acá
UPDATE producto SET stock = stock - 1 WHERE id = 2;
COMMIT;
```

**Sesión B (mientras A está pausada entre sus dos UPDATE):**
```sql
BEGIN;
UPDATE producto SET stock = stock - 1 WHERE id = 2;
-- pausar acá
UPDATE producto SET stock = stock - 1 WHERE id = 1;  -- acá debería aparecer el error 40P01
COMMIT;
```

`[COMPLETAR si lo hacen: una de las dos sesiones debería recibir "deadlock detected" (40P01) y Postgres aborta esa transacción automáticamente]`

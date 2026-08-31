# Ejercicio de Lectura Crítica

## Script 1

```sql
-- Generado para: dar de baja las funciones de películas retiradas de cartel
UPDATE funcion
SET activa = FALSE;
```

**Qué haría realmente:** al no tener ninguna cláusula `WHERE`, este `UPDATE` afecta a
**todas las filas** de la tabla `funcion`, sin excepción. No solo desactiva las funciones de
películas retiradas de cartel: también desactiva las que siguen vigentes.

**Por qué no coincide con la consigna:** la consigna pide dar de baja *únicamente* las
funciones cuya película ya no está en cartel. Tal como está escrito, el script ignora esa
condición por completo — el "generado para" describe una intención que el código no implementa.

**Versión corregida** (agregando el filtro que falta; se asume una columna que indique si la
película sigue en cartel, por ejemplo `en_cartelera`):

```sql
UPDATE funcion
SET activa = FALSE
WHERE en_cartelera = FALSE;
```

---

## Script 2

```sql
-- Generado para: limpiar las categorías sin productos asociados
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

**Qué haría realmente:** esto depende de si `producto.categoria_id` admite valores `NULL`.
Si **al menos una fila** de `producto` tiene `categoria_id IS NULL`, el subquery
`(SELECT categoria_id FROM producto)` devuelve una lista que incluye `NULL`. La condición
`id NOT IN (lista con NULL)` se evalúa como `UNKNOWN` para **absolutamente todas las filas**
de `categoria` (comparar cualquier valor contra `NULL` con `<>` nunca da `TRUE`), así que el
`DELETE` no borra **ninguna fila** — sin error, en silencio. Es la clásica "trampa del NULL"
en `NOT IN`.

**Por qué no coincide con la consigna:** la consigna dice "limpiar las categorías sin productos
asociados", pero si hay algún `categoria_id` nulo en `producto`, el script se ejecuta sin error
y sin embargo no borra nada — el resultado observable (cero filas afectadas) no avisa que el
problema existe, lo cual es peor que un error explícito.

*(Nota: en nuestro propio esquema, `producto.categoria_id` está definido como `NOT NULL`, así
que en nuestra base este script en particular no dispara el problema — pero la consigna evalúa
el script en el esquema genérico de la cátedra, donde esa columna sí puede ser nula, y por eso
la corrección con `NOT EXISTS` es la práctica correcta independientemente del esquema.)*

**Versión corregida** (usando `NOT EXISTS`, que es NULL-safe y no sufre este problema):

```sql
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1
    FROM producto p
    WHERE p.categoria_id = c.id
);
```

`NOT EXISTS` evalúa fila por fila si existe al menos un producto asociado a esa categoría,
sin verse afectado por valores `NULL` en `categoria_id`.

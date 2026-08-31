# Protocolo de Seguridad — Proyecto Pizzería (Grupo C)

Este documento adapta el protocolo de tres pasos de la cátedra (copia, transacción, respaldo)
a nuestro entorno concreto de trabajo: PostgreSQL local, administrado con DBeaver / psql,
y esquema versionado en Git (`schema.sql`, `data.sql`, `objects.sql`, `queries.sql`, `transacciones.sql`).

Se aplica siempre que un agente de IA (OpenCode, Kiro, o cualquier asistente) proponga un script
que toque la base — sin excepción, incluso para cambios que parezcan triviales.

## 1. Copia — nunca se trabaja sobre la base "real" del proyecto

Antes de aplicar cualquier script generado por IA, se crea una base de trabajo descartable:

```bash
# Crear una copia de la base del proyecto para experimentar
createdb -T practica_bd2 practica_bd2_copia

# Conectarse a la copia (nunca a practica_bd2 directamente)
psql -d practica_bd2_copia
```

Si se usa DBeaver: se genera una nueva conexión apuntando a `practica_bd2_copia`, y todo el
trabajo de prueba (constraints nuevos, escenarios de concurrencia) se hace ahí. La base
`practica_bd2` original solo se actualiza una vez que el cambio ya fue validado en la copia.

## 2. Transacción — todo script de escritura se inspecciona antes de confirmar

Ningún `INSERT`, `UPDATE`, `DELETE` o constraint generado por IA se ejecuta "a secas". Primero
se corre dentro de una transacción abierta, se revisa el resultado, y recién después se decide:

```sql
BEGIN;

-- acá va el script generado (constraint, INSERT de prueba, etc.)

-- se inspecciona el resultado: filas afectadas, mensajes de error, valores actuales
SELECT ...;

-- si el resultado es el esperado:
COMMIT;
-- si no:
ROLLBACK;
```

Esto vale tanto para los constraints de integridad de la Parte 1 como para los `INSERT`
de prueba (válidos e inválidos).

## 3. Respaldo — antes de cualquier cambio estructural (DDL)

Antes de un `ALTER TABLE`, `CREATE TRIGGER`, o cualquier cambio de esquema, se genera un dump
de la copia de trabajo, independiente del `ROLLBACK`:

```bash
pg_dump practica_bd2_copia > respaldos/practica_bd2_copia_$(date +%Y%m%d_%H%M).sql
```

Los respaldos se guardan en la carpeta `respaldos/` del repositorio (no versionada en Git si
pesan mucho — se agrega a `.gitignore`, pero se conservan localmente durante todo el TP).

## Regla de fondo

Se delega la escritura del script a la IA, nunca la decisión de aplicarlo. Todo script generado
por OpenCode o Kiro se lee línea por línea (`git diff`) antes de aplicarse, se prueba sobre la
copia dentro de una transacción, y se documenta en la DUIA correspondiente.

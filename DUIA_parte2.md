# Declaración de Uso de IA (DUIA) — Parte 2: Laboratorio de concurrencia

| Campo | Contenido |
|---|---|
| **Herramienta** | Claude (explicación de las anomalías de concurrencia) |
| **Spec o prompt utilizado** | "Explicame qué anomalía de concurrencia ocurre en este escenario (lectura no repetible / lectura fantasma / espera por bloqueo) sobre las tablas `producto` y `pedido` de nuestro esquema, y qué nivel de aislamiento o mecanismo de bloqueo lo evita." |
| **Qué generó** | Las explicaciones de cada escenario incluidas en `informe_concurrencia.md`, y los comandos SQL exactos para reproducir cada anomalía con dos sesiones. |
| **Qué se aceptó** | Las explicaciones conceptuales de READ COMMITTED / REPEATABLE READ / FOR UPDATE, tal como están en el informe. |
| **Qué se modificó o descartó, y por qué** | No se modificó nada de la spec original; se usó el producto id=1 (Fugazzeta) para los Escenarios 1 y 3, y la categoría id=1 (Pizzas) para el Escenario 2, tal como estaban en `data.sql`. |
| **Verificación realizada** | Cada escenario se corrió efectivamente con dos sesiones psql/DBeaver sobre `practica_bd2_copia`, comparando el resultado bajo `READ COMMITTED` (default) contra `REPEATABLE READ`, según el detalle en `informe_concurrencia.md`. |

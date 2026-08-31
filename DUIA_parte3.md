# Declaración de Uso de IA (DUIA) — Parte 3: Lectura crítica

| Campo | Contenido |
|---|---|
| **Herramienta** | Claude |
| **Spec o prompt utilizado** | "Analizá qué haría realmente cada uno de estos dos scripts SQL tal como están escritos, por qué no cumple lo que dice que hace, y dame la versión corregida." |
| **Qué generó** | El análisis completo en `ejercicio_lectura_critica.md`: el efecto real de cada script (UPDATE sin WHERE en Script 1; trampa de NULL con NOT IN en Script 2), y la corrección de ambos. |
| **Qué se aceptó** | El análisis y las correcciones, tal como están. |
| **Qué se modificó o descartó, y por qué** | `[COMPLETAR si el equipo ajustó algo, por ejemplo el nombre de columna asumido en Script 1]` |
| **Verificación realizada** | Análisis estático de ambos scripts (no requiere ejecución contra el motor, ya que el objetivo es identificar el efecto antes de correrlos). `[COMPLETAR si además los probaron contra la copia de trabajo]` |

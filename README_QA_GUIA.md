# Guía de Uso - Xstore QA Suite v2.3 (Windows Vista Aero Glass Edition)

Herramienta portable de **automatización de transacciones POS con macros** diseñada para ejecutarse **directamente dentro del sistema operativo de la caja POS de Oracle Xstore**.

---

## 💎 Novedades v2.3: Enfoque en Automatización Amigable y Estilo Windows Vista Aero

- **Nuevo Estilo Windows Vista Aero Glass**:
  - Paleta de colores renovada en cristal azul hielo (`#D9EBF7`), encabezado Aero Glass de zafiro profundo (`#123859`), reflejos cian vítreos y tipografía optimizada en `Segoe UI`.
  - Tarjetas visualmente organizadas, botones táctiles amplios con bordes suaves y barras de progreso en aguamarina cristalino.
- **Enfoque 100% en Automatización de Transacciones (Menos Carga, Más Productividad)**:
  - Se eliminó la intimidante terminología de estrés para dar paso a un asistente intuitivo para operadores y QA.
  - **Modos de Ejecución Rápidos**:
    - **1 Transacción Rápida**: Ejecuta una venta completa con un solo clic sin tener que digitar códigos ni menús a mano.
    - **Lote de Transacciones**: Define cuántas ventas consecutivas deseas procesar (ej. 5, 10) con una pausa natural (1.0s).
    - **Modo Continuo (∞)**: Disponible para cuando se requiera automatización prolongada sin complicaciones.
- **Editor Directo de Macros**:
  - En la pestaña **📂 Biblioteca**, ahora puedes pulsar **📝 Editar Macro en Bloc de Notas** para ajustar códigos, artículos o pausas de forma instantánea.
- **Auditoría Clara de Transacciones**:
  - Cada sesión genera un reporte CSV limpio en `Reports/Registro_Transacciones_*.csv` con tiempos por ticket, estado y duraciones.

---

## 📋 Flujo de Trabajo en la Caja POS

### Paso 1: Abrir la Suite en la Caja
1. Copia `Xstore_QA_Automation_Suite_v2.3.exe` al terminal POS.
2. Ejecuta la suite. Si las carpetas `Macros/` y `Reports/` no existen, se crearán de inmediato automáticamente.
3. La ventana permanecerá visible sobre Xstore para una fácil operación táctil.

---

### Paso 2: Vincular la Ventana de Xstore POS
1. En la pestaña **🚀 Automatizar**, haz clic en el botón **🎯 Vincular**.
2. Haz clic dentro de la ventana de **Xstore POS** en los siguientes 4 segundos. El título quedará fijado para enfocarlo automáticamente antes de cada transacción.

---

### Paso 3: Ejecutar una Transacción Automatizada
1. Selecciona la macro deseada del menú desplegable (ej. `Macro_Xstore_Local.txt` o la que hayas grabado).
2. Elige el modo: **1 Transacción** (ejecución única) o **Lote** (ej. 5 repeticiones).
3. Presiona **▶️ EJECUTAR TRANSACCIÓN**.
4. La suite enfocará Xstore y reproducirá la secuencia con precisión milimétrica.

---

### Controles de Emergencia y Pausa
- **Ctrl + P**: Pausa interactiva para revisar el ticket en pantalla o reponer papel. Presiona **Ctrl + P** nuevamente para reanudar.
- **Ctrl + M**: Detención inmediata (Kill Switch). Las teclas de función F1-F12 de Xstore quedan 100% libres.

---

### Paso 4: Grabar Nuevas Transacciones
1. Dirígete a la pestaña **🔴 Grabar Macro**.
2. Asigna un nombre a tu transacción (ej. `Venta_1Item_Efectivo`).
3. Presiona **🔴 Iniciar Grabación** y realiza la operación normalmente en la caja Xstore.
4. Presiona **💾 Guardar en Biblioteca**. La nueva macro se seleccionará automáticamente en la pestaña **🚀 Automatizar**, lista para ejecutarse cuantas veces quieras.

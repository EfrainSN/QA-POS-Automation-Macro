# Guia de Operacion - QA POS Automation Macro v2.5

Herramienta portable de automatizacion de transacciones para terminales de punto de venta (POS) basada en macros nativas de baja latencia con editor interactivo de pasos y gestor de actualizaciones.

---

## 1. Descripcion General

QA POS Automation Macro es una aplicacion disenada para automatizar secuencias repetitivas en cajas POS mediante emulacion directa de eventos de teclado en hardware y sistema operativo local.

Principales capacidades tecnicas:
- Latencia menor a 5 ms por instruccion mediante llamadas directas a la API de entrada de Windows.
- Prevencion de perdida de paquetes de teclado comun en soluciones de streaming remoto.
- Interfaz grafica Windows Vista Aero Glass optimizada para paneles tactiles resistivos y capacitivos de terminales POS.
- Editor visual interactivo de pasos para modificar, sustituir y reordenar SKUs sin necesidad de editar archivos de texto.
- Gestor integrado de actualizaciones para monitorear nuevas versiones y mejoras publicadas en GitHub Releases.
- Control seguro de foco y suspension de hilos con atajos globales no bloqueantes para teclas funcionales F1 a F12.

---

## 2. Modos de Ejecucion

1. **Modo 1 Transaccion (Unitario):**
   Ejecuta una unica transaccion o secuencia de venta y detiene el flujo inmediatamente al concluir. Ideal para pruebas funcionales paso a paso o automatizacion de operaciones individuales sin intervencion manual.

2. **Modo Lote (Batch):**
   Ejecuta un numero configurable de transacciones consecutivas con pausas inter-ciclo parametrizables (valor estandar: 1000 ms).

3. **Modo Continuo:**
   Mantiene el ciclo de transacciones activo de manera indefinida hasta recibir la senal de parada del operador o combinacion de emergencia.

---

## 3. Instrucciones de Uso en Caja POS

### Paso 1: Despliegue
1. Copie el archivo ejecutable (`QA_POS_Automation_Macro_v2.5.exe` o `QA_POS_Automation_Macro_v2.5_x86.exe`) en cualquier directorio del terminal.
2. Inicie la aplicacion con permisos de usuario estandar o administrador segun las politicas de la caja POS.
3. La aplicacion inicializara automaticamente los directorios `Macros/` y `Reports/` si no existen.

### Paso 2: Vinculacion Inteligente de Foco
1. Al arrancar la aplicacion, el sistema busca automaticamente ventanas activas que coincidan con terminales POS ("Xstore", "POS", "Oracle Retail", "Point of Service") y las pre-vincula en el campo de texto.
2. Al presionar el boton "Vincular":
   - Si la terminal POS ya esta abierta en el sistema, se vincula y enfoca de inmediato con confirmacion sonora.
   - Si no se detecta automaticamente, la ventana pasa a modo translucido y muestra un aviso flotante. Haga clic sobre cualquier parte de la ventana de su caja POS para vincularla (presione Escape si desea cancelar).

### Paso 3: Ejecucion de Transacciones
1. Seleccione la macro deseada del menu desplegable.
2. Seleccione el modo de ejecucion (1 Transaccion o Lote).
3. Presione "EJECUTAR TRANSACCION".

### Paso 4: Grabacion de Nuevas Macros con Temporizador y Fondo Translucido
1. Ingrese a la pestana "Grabar Macro", asigne un nombre a la transaccion y presione "Iniciar Grabacion".
2. **Fondo Translucido:** La interfaz adopta instantaneamente un fondo de cristal translucido Aero Glass para permitirle ver la pantalla del POS que se encuentra debajo.
3. **Temporizador de 3 Segundos:** Se activa una cuenta regresiva de 3 segundos (3... 2... 1...) acompanada de avisos sonoros progresivos y un aviso flotante en pantalla, otorgando el tiempo exacto para ubicarse en la caja POS.
4. Al culminar los 3 segundos, suena un tono agudo confirmatorio y el sistema comienza a registrar todas las pulsaciones de teclado y pausas en tiempo real mientras el fondo permanece translucido.
5. Presione "Guardar en Biblioteca" para persistir la macro o "Cancelar" para descartarla, restaurando de inmediato la opacidad normal de la ventana.

---

## 4. Uso del Editor Interactivo de Pasos

Para modificar una macro existente, cambiar codigos de articulo (SKUs), reordenar la secuencia de cobro o ajustar pausas temporales:

1. **Acceder al Editor:**
   Haga clic en la pestana **"Editor de Pasos"** o, desde la pestana "Biblioteca", pulse **"Editar en Editor de Pasos"**.
2. **Cargar la Macro:**
   Seleccione la macro deseada en el desplegable superior y presione **"Cargar Macro"** (se carga automaticamente al seleccionarla).
3. **Modificar un SKU o Instruccion:**
   - Haga clic en el paso que desea modificar en la lista.
   - En la tarjeta "Modificar Paso Seleccionado", el tipo y valor actual se cargaran automaticamente.
   - Modifique el valor (por ejemplo, escriba el nuevo codigo SKU o codigo de barras).
   - Presione el boton **"Actualizar Paso"**. La lista reflejara el cambio de inmediato.
4. **Reordenar Pasos:**
   - Seleccione el paso y presione **"Subir"** o **"Bajar"** para mover la posicion de la instruccion dentro del flujo.
5. **Duplicar o Eliminar:**
   - Use **"Duplicar"** para clonar un escaneo de producto con su enter correspondiente.
   - Use **"Eliminar"** para descartar un paso innecesario.
6. **Insertar Nuevos Pasos:**
   - Seleccione el tipo (`Texto / SKU`, `Tecla Especial`, `Pausa (ms)`), escriba el valor y presione **"Insertar Nuevo Paso"**. Se agregara justo debajo del paso actualmente seleccionado.
7. **Guardar los Cambios:**
   - **GUARDAR CAMBIOS (Sobrescribir):** Guarda las modificaciones directamente sobre el archivo actual.
   - **GUARDAR COMO... (Nueva Variante):** Solicita un nuevo nombre (por ejemplo, `Transaccion_2_Articulos.txt`) para preservar la macro original y crear una variante.

---

## 5. Comprobacion de Actualizaciones y Nuevos Releases

La herramienta incorpora un monitor nativo para mantenerse al tanto de nuevas versiones y mejoras:

1. **Desde la Cabecera:**
   Presione el boton **"Actualizaciones"** en la parte superior derecha de la ventana desde cualquier pantalla para ir directo al panel de control de versiones.
2. **Desde la Pestana "Actualizaciones":**
   - Presione **"Buscar Actualizaciones"** para conectarse con la API de GitHub y consultar la ultima version publicada.
   - El panel mostrara el estado del software (`Al dia` o `Nueva Version Disponible`).
   - El visor de **Registro de Cambios (Changelog)** cargara las notas tecnicas y novedades introducidas en la ultima version.
3. **Descarga de Actualizaciones:**
   - Si existe una version nueva, el boton **"Descargar Paquete ZIP Portable de la Ultima Version"** se habilitara para descargar directamente el paquete actualizado.
   - Tambien puede pulsar **"Abrir GitHub Releases"** para explorar el historial completo de versiones en el navegador.
4. **Operacion Offline:**
   - En terminales sin conexion externa a Internet, la verificacion finaliza en modo seguro sin congelar la aplicacion.

---

## 6. Controles de Seguridad

- **Ctrl + P:** Alterna el estado de pausa de la macro en curso sin reiniciar contadores ni descartar reportes.
- **Ctrl + M:** Finalizacion inmediata del hilo de reproduccion (Kill Switch de emergencia).

---

## 7. Auditoria y Registros

Cada sesion genera un archivo CSV estructurado dentro del directorio `Reports/` bajo la nomenclatura `Registro_Transacciones_YYYYMMDD_HHMMSS_NombreMacro.csv`, con los siguientes campos por linea:

- `Transaccion`: Numero ordinal del ciclo.
- `Fecha_Inicio`: Marca de tiempo ISO (YYYY-MM-DD HH:MM:SS) de inicio del ciclo.
- `Fecha_Fin`: Marca de tiempo ISO de finalizacion.
- `Duracion_Seg`: Duracion neta en segundos con precision decimal.
- `Duracion_Ms`: Duracion neta en milisegundos.
- `Estado`: Indicador de estado (`COMPLETADO` o `INTERRUMPIDO`).
- `Macro`: Nombre del archivo de macro reproducido.

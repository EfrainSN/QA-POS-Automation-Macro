# Guia de Operacion - QA POS Automation Macro v2.3

Herramienta portable de automatizacion de transacciones para terminales de punto de venta (POS) basada en macros nativas de baja latencia.

---

## 1. Descripcion General

QA POS Automation Macro es una aplicacion diseñada para automatizar secuencias repetitivas en cajas POS mediante emulacion directa de eventos de teclado en hardware y sistema operativo local.

Principales capacidades tecnicas:
- Latencia menor a 5 ms por instruccion mediante llamadas directas a la API de entrada de Windows.
- Prevencion de perdida de paquetes de teclado comun en soluciones de streaming remoto.
- Interfaz grafica Windows Vista Aero Glass optimizada para paneles tactiles resistivos y capacitivos de terminales POS.
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
1. Copie el archivo ejecutable (`QA_POS_Automation_Macro_v2.3.exe` o `QA_POS_Automation_Macro_v2.3_x86.exe`) en cualquier directorio del terminal.
2. Inicie la aplicacion con permisos de usuario estandar o administrador segun las politicas de la caja POS.
3. La aplicacion inicializara automaticamente los directorios `Macros/` y `Reports/` si no existen.

### Paso 2: Vinculacion de Foco
1. En la pestana "Automatizar", presione el boton "Vincular".
2. Haga clic en la ventana de la aplicacion POS activa dentro de los siguientes 4 segundos. El titulo quedara registrado para garantizar que el foco de entrada se active antes de cada despacho de teclas.

### Paso 3: Ejecucion
1. Seleccione la macro deseada del menu desplegable.
2. Seleccione el modo de ejecucion (1 Transaccion o Lote).
3. Presione "EJECUTAR TRANSACCION".

---

## 4. Controles de Seguridad

- **Ctrl + P:** Alterna el estado de pausa de la macro en curso sin reiniciar contadores ni descartar reportes.
- **Ctrl + M:** Finalizacion inmediata del hilo de reproduccion (Kill Switch de emergencia).

---

## 5. Auditoria y Registros

Cada sesion genera un archivo CSV estructurado dentro del directorio `Reports/` bajo la nomenclatura `Registro_Transacciones_YYYYMMDD_HHMMSS_NombreMacro.csv`, con los siguientes campos por linea:

- `Transaccion`: Numero ordinal del ciclo.
- `Fecha_Inicio`: Marca de tiempo ISO (YYYY-MM-DD HH:MM:SS) de inicio del ciclo.
- `Fecha_Fin`: Marca de tiempo ISO de finalizacion.
- `Duracion_Seg`: Duracion neta en segundos con precision decimal.
- `Duracion_Ms`: Duracion neta en milisegundos.
- `Estado`: Indicador de estado (`COMPLETADO` o `INTERRUMPIDO`).
- `Macro`: Nombre del archivo de macro reproducido.

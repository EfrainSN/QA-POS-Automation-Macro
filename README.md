# QA POS Automation Macro

Suite portable de automatizacion deterministica de transacciones para terminales de punto de venta (POS / Oracle Retail Xstore) con sincronizacion por eventos de log, interfaz Windows Vista Aero Glass, Mini-HUD en vivo y Dashboard HTML Forense.

[![Release](https://img.shields.io/badge/Release-v2.8.0-0078D7.svg?style=flat-square)](https://github.com/EfrainSN/QA-POS-Automation-Macro/releases)
[![Platform](https://img.shields.io/badge/Platform-Windows%20POSReady%20%7C%2010%20%7C%2011-00a2ed.svg?style=flat-square)](https://github.com/EfrainSN/QA-POS-Automation-Macro)
[![Language](https://img.shields.io/badge/Language-AutoHotkey%20v2.0-334455.svg?style=flat-square)](https://www.autohotkey.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

---

## 1. Arquitectura del Sistema

QA POS Automation Macro es un motor de automatizacion disenado especificamente para entornos de cajas de venta minorista y terminales transaccionales (POS). A diferencia de las soluciones basadas en control remoto, streaming de video o reconocimiento optico, la aplicacion se ejecuta de forma nativa dentro de la sesion del sistema operativo del terminal, eliminando retardos de red y garantizando una dispersion temporal deterministica.

### 1.1 Subsistema Centinela POS y Auto-Recuperacion en Lotes (Self-Healing)

La suite incorpora un subsistema Centinela disenado para monitorizar el flujo operativo y los registros de eventos de la aplicacion POS en tiempo real (incluso cada 150 ms dentro de pausas largas):
- **Lectura No Bloqueante e Incremental:** Abre el archivo de registro o log transaccional en modo de lectura compartida (`r-d`), anclando el puntero al final del archivo (`Seek(0, 2)`) al iniciar el lote. De este modo, solo procesa las lineas generadas durante la ejecucion de la macro, garantizando cero impacto en el rendimiento de la CPU del terminal POS.
- **Deteccion Precisa de Eventos y Bloqueos:** Reconoce de manera inmediata ventanas modales, excepciones y bloqueos criticos del flujo transaccional:
  - Articulos o SKUs no registrados en catalogo (Item Not On File).
  - Reglas de validacion de importes o transacciones de cobro rechazadas.
  - Formularios de operacion con campos obligatorios vacios o incompletos.
  - Terminal o estacion de trabajo cerrada sin turno operativo habilitado.
  - Reglas de negocio internas rechazadas por la logica transaccional del sistema.
  - *(Nota: Los avisos de perifericos secundarios o impresora se pueden omitir deliberadamente para facilitar pruebas continuas en terminales de QA sin hardware fiscal conectado).*
- **Auto-Recuperacion en Lotes (Self-Healing):** Permite habilitar la opcion `Auto-Recuperar en Lote`, mediante la cual ante un popup de error en una corrida masiva, el motor captura la evidencia forense, cierra automaticamente el modal de error (`{Enter}` / `{Escape}`), re-ancla el puntero del log y continua con el siguiente ciclo sin abortar el lote completo.
- **Captura de Pantalla y Fragmento Forense Automatico:** En el instante exacto del fallo, el motor invoca la API nativa de Windows GDI+ para tomar una captura `.png` (`Reports/Screenshots/Error_Ciclo_<N>_<timestamp>.png`) y extrae el bloque exacto de `xstore.log` (`OPCHAIN_FLOW`) para incrustarlo en el **Dashboard HTML Forense**.

### 1.2 Subsistema de Captura Inteligente (UIA v2 + Etiquetado Xstore + Coordenadas Proporcionales)
 
La captura de secuencias se implementa mediante la API `InputHook` de bajo nivel combinada con ganchos reactivos de eventos de ratón (`~*LButton`, `~*RButton`), la librería **Microsoft UI Automation v2 (`UIA-v2`)** y lectura en vivo de `xstore.log`:
- **Identificacion Real de Botones en Java Swing (`XstoreAction`):** Cuando el operador hace clic en Xstore, el grabador inspecciona `xstore.log` para capturar la accion de negocio exacta (`[Action] <click> -> NombreBoton [CODIGO]`) y etiquetar automaticamente el paso:
  `UIA_Click, Name="...", Fallback=678, 902, WinSize=1920x1080, XstoreAction="Caja registradora [REGISTER_LOGIN]"`
- **Sincronizacion por Eventos del Log (`WaitPrompt`):** Durante la grabacion, detecta automaticamente que `[Prompt]` o `[Form]` mostro Xstore antes de cada accion y lo asocia a la pausa (`Sleep, 3400, WaitPrompt="LOGIN_USER_ID"`).
- **Coordenadas Proporcionales (`WinSize=WxH`):** Registra las dimensiones de la ventana del POS junto con cada clic y escala proporcionalmente las coordenadas `(X, Y)` si la macro se reproduce en una terminal con distinta resolucion de pantalla.
- **Mini-HUD Flotante en Vivo (`WS_EX_TRANSPARENT`):** Despliega una barra superior siempre visible sobre Xstore a pantalla completa que muestra en tiempo real el ciclo, el paso en curso y el boton o SKU procesado sin robar foco ni bloquear clics.
- **HUD OSD Regresivo de 3 Segundos:** Al iniciar la grabacion, el sistema despliega un banner flotante centrado de alto impacto visual (HUD estilo Aero Glass `#123859` con borde `#5AD1FF`, sin robar foco `NoActivate`) que realiza una cuenta regresiva 3... 2... 1... acompañada de avisos sonoros ascendentes, garantizando que el operador tenga tiempo para posicionarse en la terminal POS antes de capturar eventos.
- **Modo Translucido Aero Glass:** Durante la grabacion, la suite reduce su opacidad al 58% (`WinSetTransparent(150)`), permitiendo al operador observar la aplicacion POS debajo de la ventana. Al finalizar o cancelar, la opacidad nativa se restablece al 100%.
- **Modo Pass-Through:** No intercepta ni bloquea las pulsaciones ni clics dirigidos al proceso de la aplicacion POS durante la grabacion.
- **Calculo Dinamico de Deltas:** Mide la diferencia en milisegundos (`A_TickCount`) entre pulsaciones y clics sucesivos para generar sentencias `Sleep, <delta>` que reproducen fielmente los tiempos de respuesta requeridos por las bases de datos locales y servicios fiscales del POS.
 
### 1.3 Subsistema de Reproduccion Deterministica y Despacho de Eventos
 
El motor de reproduccion analiza secuencialmente el archivo de macro interpretando directivas enriquecidas:
- `Sleep, <ms>, WaitPrompt="<PROMPT>"` y `WaitPrompt, <PROMPT>, Timeout=<ms>`: Si la sincronizacion inteligente con log esta activa, monitorea `xstore.log` en tiempo real para avanzar tan pronto Xstore cargue el prompt esperado, o extender el tiempo de espera automaticamente si la base de datos o red tarda mas de lo habitual.
- `Send, <payload>`: Despacha caracteres y codigos virtuales mediante `SendEvent` con una configuracion fija de `SetKeyDelay(25, 25)`.
- `UIA_Click, ..., Fallback=X, Y, WinSize=WxH, XstoreAction="..."`: Localiza el elemento por UIA o aplica escalado proporcional de coordenadas `(X, Y)`. Si el paso incluye `XstoreAction`, verifica en `xstore.log` que el clic haya generado actividad en `OPCHAIN_FLOW` y reintenta automaticamente el clic si Java Swing omitio el primer pulso.
- `MouseClick, <Boton>, <X>, <Y>`: Posiciona instantáneamente el cursor del ratón y despacha clics seguros con escalado proporcional.
 
### 1.4 Gestion de Foco, Anclaje y Guardian de Ventana en Caliente
 
El sistema gestiona la sincronizacion con la terminal POS mediante inspeccion exhaustiva de ventanas Win32 (`SetTitleMatchMode(2)` y `SetTitleMatchMode("Slow")`):
1. **Auto-Deteccion y Anclaje Previo (Pre-Flight Check):** Al iniciar la ejecucion, valida la existencia de la ventana de Xstore. La restaura si esta minimizada, la trae al frente de forma forzada y confirma el foco estricto mediante `WinWaitActive()`. Si la ventana no existe, interrumpe el inicio con una alerta de seguridad para evitar disparar teclas al aire.
2. **Cuenta Regresiva de Despacho (3 Segundos con HUD):** Muestra un banner visual flotante en pantalla ("XSTORE ANCLADO Y VALIDADO") con cuenta regresiva de 3 segundos, permitiendo al operador confirmar visualmente que el POS esta listo y soltar el teclado y raton.
3. **Guardian de Foco en Caliente:** Durante el despacho de cada instruccion de la macro, el motor verifica que la ventana activa siga siendo la terminal de Xstore anclada. Si el usuario hace clic afuera accidentalmente o emerge una ventana emergente del sistema operativo, el motor pausa de forma automatica e inmediata la ejecucion para proteger la transaccion y no escribir en la aplicacion equivocada.
4. **Modo Interactivo Asistido:** Si la terminal utiliza un titulo no estandar, el sistema activa una guia flotante y modo translucido para capturar la ventana exacta al hacer clic sobre ella (cancelable mediante Escape).
 
---
 
## 2. Interfaz de Usuario y Estilo Windows Vista Aero Glass
 
La aplicacion implementa una interfaz grafica basada en los principios de diseno de Windows Vista Aero:
- **Paleta de Color:** Fondo de ventana en azul hielo escarchado (`#D9EBF7`), panel superior de encabezado en zafiro profundo (`#123859`) y acentos de borde en cian luminiscente (`#5AD1FF`).
- **Fondo Translucido Dinamico:** La ventana conmuta de forma transparente entre solida y cristal translucido durante la vinculacion y el proceso de grabacion de secuencias.
- **Controles Touch-Friendly:** Botones de dimensiones extendidas (minimo 40 px de altura) con espaciado amplio, aptos para ser operados con los dedos en pantallas tactiles industriales de punto de venta.
- **Telemetria de Estado en Tiempo Real:** Barra de progreso porcentual, cronometro acumulado de ejecucion, contador de transacciones procesadas y tasa de exito.

---

## 3. Modos de Operacion

### 3.1 Modo Unitario (1 Transaccion)
Disenado para automatizar una unica venta o cobro sin intervencion manual. Al terminar el despacho de la macro, el sistema devuelve inmediatamente el control al operador.

### 3.2 Modo Lote (Batch)
Permite ingresar una cantidad especifica de transacciones a procesar en secuencia (por ejemplo, 5, 10, 50 o 100), aplicando una pausa inter-ticket parametrizable (predeterminada en 1000 ms) para dar margen al guardado en base de datos y procesamiento de comprobantes fiscales.

### 3.3 Modo Continuo
Ejecuta la macro seleccionada en un bucle indefinido, disenado para pruebas de resistencia funcional y verificacion de estabilidad de colas locales.

---

## 4. Editor Visual Interactivo de Pasos

La suite integra un modulo nativo de edicion paso a paso accesible desde la pestana **"Editor de Pasos"** o directamente desde la biblioteca mediante **"Editar en Editor de Pasos"**:

- **Visualizacion Estructurada:** Muestra las lineas de la macro en una tabla Win32 interactiva identificando automaticamente el numero de paso, tipo (`Texto / SKU`, `Tecla Especial`, `Pausa (ms)`) y valor de la instruccion.
- **Modificacion Directa de SKUs:** Permite seleccionar cualquier paso de ingreso de articulo, cambiar el codigo SKU o texto por otro nuevo y aplicarlo con el boton `Actualizar Paso`.
- **Reordenamiento Dinamico:** Botones dedicados `Subir` y `Bajar` para mover pasos hacia arriba o hacia abajo en el flujo transaccional.
- **Duplicacion y Eliminacion:** Permite clonar lineas de escaneo repetidas o descartar pasos no requeridos con un solo clic.
- **Insercion de Nuevos Pasos:** Agrega articulos, pausas o teclas de funcion en cualquier posicion del flujo de venta.
- **Persistencia Segura:** Opciones para `Guardar Cambios (Sobrescribir)` directamente sobre el archivo original o `Guardar Como... (Nueva Variante)` para generar escenarios alternativos sin alterar la macro base.
- **100% Nativo y Portable:** Implementado sobre componentes Win32 sin dependencias externas (sin navegadores embebidos ni WebView2), garantizando compatibilidad inmediata en terminales POS con Windows POSReady 7, Windows 10 IoT y Windows 11.

---

## 5. Gestor de Actualizaciones y Releases Integrado

A partir de la version 2.5.0, la aplicacion incluye un modulo de actualizacion y monitoreo de versiones de GitHub:

- **Pestana "Actualizaciones":** Presenta en tiempo real la version local instalada, la ultima version disponible publicada en el repositorio, la fecha de lanzamiento y el estado del software.
- **Acceso Rapido en Cabecera:** Boton directo de `Actualizaciones` en el encabezado Aero Glass superior que senala el estado de la version (`Al dia` o `Nueva Version!`) accesible desde cualquier pestana.
- **Boton en Biblioteca:** Opcion directa `Buscar Actualizaciones` dentro de la gestion de macros.
- **Visor de Registro de Cambios (Changelog):** Panel de texto dedicado donde el usuario puede leer las notas tecnicas, mejoras y correcciones de la ultima release sin salir de la herramienta.
- **Descarga Inmediata:** Boton directo para descargar el paquete ZIP portable oficial o abrir la pagina de releases en GitHub.
- **Tolerancia a Fallos y Modo Offline:** Utiliza el componente nativo de Windows `Msxml2.ServerXMLHTTP.6.0` con limites de tiempo (timeouts de 3 segundos), garantizando que las cajas de cobro que operen sin acceso a Internet o bajo firewalls estrictos no sufran bloqueos de interfaz ni retrasos.

---

## 6. Controles de Seguridad y Parada de Emergencia

El software incorpora manejadores de interrupcion de hilos en caliente para salvaguardar la integridad de la operacion en caja:

- **Centinela POS (Watchdog de Logs):** Vigilancia permanente por sondeo de log con parada automatica ante fallos de caja o reglas de negocio violadas.
- **Ctrl + P (Pausa / Reanudacion):** Suspende temporalmente el envio de teclas sin alterar el contador de ciclos ni cancelar el reporte de auditoria. Al reanudar, vuelve a enfocar la ventana del POS y retoma exactamente en la linea siguiente.
- **Ctrl + M (Kill Switch de Emergencia):** Cancela de inmediato el hilo de ejecucion, libera los hooks de teclado y consolida el reporte CSV con las transacciones completadas hasta el momento.
- **Preservacion de Teclas de Funcion:** Los hotkeys globales estan limitados exclusivamente a combinaciones con tecla Control, dejando completamente libres las teclas `F1` a `F12` utilizadas por los sistemas POS.

---

## 7. Especificacion del Registro de Auditoria (CSV)

Cada sesion genera de manera automatica un archivo de auditoria en el directorio `Reports/` bajo el formato de nombres `Registro_Transacciones_YYYYMMDD_HHMMSS_NombreMacro.csv`.

### Estructura de Columnas:

| Campo | Tipo | Descripcion |
| :--- | :--- | :--- |
| `Transaccion` | Entero | Indice correlativo de la transaccion ejecutada |
| `Fecha_Inicio` | String (ISO) | Marca de tiempo de inicio (YYYY-MM-DD HH:MM:SS) |
| `Fecha_Fin` | String (ISO) | Marca de tiempo de culminacion (YYYY-MM-DD HH:MM:SS) |
| `Duracion_Seg` | Decimal | Duracion total del ciclo expresada en segundos |
| `Duracion_Ms` | Entero | Duracion exacta en milisegundos |
| `Estado` | Enum | Resultado de la transaccion (`COMPLETADO`, `INTERRUMPIDO` o `FALLO_CENTINELA (<Detalle>)`) |
| `Macro` | String | Nombre del archivo de macro reproducido |

---

## 8. Procedimiento de Compilacion

El proyecto se compila directamente en ejecutables nativos portables que no requieren instalacion de librerias, runtimes o dependencias en el terminal POS.

### Requisitos:
- AutoHotkey v2.0+ instalado.
- Compilador oficial `Ahk2Exe.exe`.

### Compilacion Automatizada:
Ejecute el script `build.bat` en la raiz del proyecto:
```cmd
build.bat
```

Este script detecta la version declarada en el codigo fuente y genera automaticamente:
- `QA_POS_Automation_Macro_v2.8.exe` (Binario de 64 bits para Windows 10/11)
- `QA_POS_Automation_Macro_v2.8_x86.exe` (Binario de 32 bits para Windows POSReady y hardware legacy)
- `QA_POS_Automation_Macro_v2.8_Portable.zip` (Paquete portable completo listo para distribucion)

---

## 9. Estructura Modular del Repositorio (v2.8+)

```text
QA-POS-Automation-Macro/
├── QA_POS_Automation_Macro.ahk   # Punto de entrada principal (~60 lineas, #Includes)
├── build.bat                     # Empaqueta todos los modulos en un solo .exe autonomo
├── config.ini                    # Configuracion persistente local
├── Lib/
│   └── UIA.ahk                   # Libreria Microsoft UI Automation v2
├── src/
│   ├── Core/
│   │   ├── Globals.ahk           # Estado global, constantes y referencias UI
│   │   ├── ConfigManager.ahk     # Gestion de directorios y persistencia config.ini
│   │   └── Updater.ahk           # Gestor de actualizaciones via GitHub Releases API
│   ├── POS/
│   │   ├── PosWindowManager.ahk  # Deteccion, anclaje y filtrado de ventana Xstore POS
│   │   ├── XstoreSentinel.ahk    # Subsistema Centinela y capturas GDI+ (.png)
│   │   └── XstoreLogSync.ahk     # Sincronizacion WaitPrompt y captura de [Action]
│   ├── Engine/
│   │   ├── MacroRecorder.ahk     # Grabador en directo + Deteccion Copiar/Pegar (Portapapeles)
│   │   ├── MacroPlayer.ahk       # Reproductor deterministico, {Text} literal y Self-Healing
│   │   └── Hotkeys.ahk           # Atajos globales (Ctrl+P, Ctrl+M) y hooks de captura
│   ├── Reports/
│   │   └── ForensicDashboard.ahk # Telemetria en vivo, CSV y Dashboard HTML Forense
│   └── UI/
│       ├── FloatingHUD.ahk       # Mini-HUD en vivo, Countdown OSD y Mira visual
│       ├── StepEditor.ahk        # Editor interactivo de pasos y optimizador masivo
│       └── MainWindow.ahk        # Construccion de ventana Aero Glass y eventos
├── Macros/                       # Directorio de almacenamiento de macros (.txt)
└── Reports/                      # Directorio de reportes CSV y Dashboard HTML
    └── Screenshots/              # Capturas automaticas ante fallos (.png)
```

---

## 10. Licencia

Distribuido bajo la Licencia MIT. Consulte el archivo `LICENSE` para mas informacion.

---

## 11. Reconocimiento de Asistencia de IA

Este proyecto fue conceptualizado, diseñado, desarrollado y probado bajo la dirección y autoría de **Efrain Cortez**, contando con el apoyo y asistencia técnica de modelos de **Inteligencia Artificial (IA)** para pair-programming, diseño de arquitectura de eventos de bajo nivel en Windows Win32, interfaz Aero Glass nativa, pruebas de concurrencia y documentación técnica.


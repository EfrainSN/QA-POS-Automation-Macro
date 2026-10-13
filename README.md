# QA POS Automation Macro

Suite portable de automatizacion de transacciones para terminales de punto de venta (POS) basada en emulacion de teclado de baja latencia con interfaz Windows Vista Aero Glass.

[![Release](https://img.shields.io/badge/Release-v2.5.0-0078D7.svg?style=flat-square)](https://github.com/EfrainSN/QA-POS-Automation-Macro/releases)
[![Platform](https://img.shields.io/badge/Platform-Windows%20POSReady%20%7C%2010%20%7C%2011-00a2ed.svg?style=flat-square)](https://github.com/EfrainSN/QA-POS-Automation-Macro)
[![Language](https://img.shields.io/badge/Language-AutoHotkey%20v2.0-334455.svg?style=flat-square)](https://www.autohotkey.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

---

## 1. Arquitectura del Sistema

QA POS Automation Macro es un motor de automatizacion disenado especificamente para entornos de cajas de venta minorista y terminales transaccionales (POS). A diferencia de las soluciones basadas en control remoto, streaming de video o reconocimiento optico, la aplicacion se ejecuta de forma nativa dentro de la sesion del sistema operativo del terminal, eliminando retardos de red y garantizando una dispersion temporal deterministica.

### 1.1 Subsistema de Captura y Temporizador de Grabacion
 
La captura de secuencias se implementa mediante la API `InputHook` de bajo nivel de Windows con parametros `V L0` (Visible, Longitud Ilimitada):
- **Temporizador Regresivo de 3 Segundos:** Al iniciar la grabacion, el sistema activa un conteo regresivo de 3 segundos con avisos sonoros ascendentes y un banner flotante en pantalla, otorgando el tiempo necesario para posicionarse en la terminal POS antes de capturar eventos.
- **Modo Translucido Aero Glass:** Durante la grabacion, la suite reduce su opacidad al 58% (`WinSetTransparent(150)`), permitiendo al operador observar la aplicacion POS debajo de la ventana. Al finalizar o cancelar, la opacidad nativa se restablece al 100%.
- **Modo Pass-Through:** No intercepta ni bloquea las pulsaciones dirigidas al proceso de la aplicacion POS durante la grabacion.
- **Normalizacion de Codigos Virtuales:** Traduce codigos de teclas fisicas (`VK_RETURN`, `VK_ESCAPE`, `VK_TAB`, `VK_BACK`, `VK_SPACE`, teclas de navegacion y teclas de funcion `VK_F1` a `VK_F12`) en secuencias semanticas formalizadas `{Key}` compatibles con el sintetizador de eventos.
- **Calculo Dinamico de Deltas:** Mide la diferencia en milisegundos (`A_TickCount`) entre pulsaciones sucesivas para generar sentencias `Sleep, <delta>` que reproducen fielmente los tiempos de respuesta requeridos por las bases de datos locales y servicios fiscales del POS.
 
### 1.2 Subsistema de Reproduccion y Despacho de Eventos
 
El motor de reproduccion analiza secuencialmente el archivo de macro interpretando dos directivas primarias:
- `Sleep, <ms>`: Aplica una espera fraccionada mediante un bucle de retardo divisible de 25 ms, permitiendo responder inmediatamente a peticiones de pausa o interrupcion de emergencia.
- `Send, <payload>`: Despacha caracteres y codigos virtuales mediante `SendEvent` con una configuracion fija de `SetKeyDelay(25, 25)` (25 ms de retardo entre pulsaciones y 25 ms de duracion de pulsacion), parametro calibrado para evitar omisiones de caracteres en hardware de teclado fiscal o escaneres emulados.
 
### 1.3 Gestion de Foco y Vinculacion Inteligente de Ventana
 
El sistema gestiona la sincronizacion con la terminal POS mediante inspeccion exhaustiva de ventanas Win32 (`SetTitleMatchMode(2)` y `SetTitleMatchMode("Slow")`):
1. **Auto-Deteccion en Inicio y Vinculacion Rapida:** Al arrancar o pulsar "Vincular", el sistema busca procesos abiertos que contengan "Xstore", "POS", "Oracle Retail" o "Point of Service", vinculando y activando la terminal de inmediato.
2. **Modo Interactivo Asistido:** Si la terminal utiliza un titulo no estandar, el sistema activa una guia flotante y modo translucido para capturar la ventana exacta al hacer clic sobre ella (cancelable mediante la tecla Escape).
3. **Mantenimiento del Foco en Reproduccion:** Antes de cada transaccion, el motor verifica la existencia de la ventana mediante `WinExist()`, invoca `WinActivate()` y valida la sincronizacion con `WinWaitActive()`, evitando la inyeccion de teclas fuera de la caja registradora.
 
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
| `Estado` | Enum | Resultado de la transaccion (`COMPLETADO` o `INTERRUMPIDO`) |
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
- `QA_POS_Automation_Macro_v2.5.exe` (Binario de 64 bits para Windows 10/11)
- `QA_POS_Automation_Macro_v2.5_x86.exe` (Binario de 32 bits para Windows POSReady y hardware legacy)

---

## 9. Estructura del Repositorio

```text
QA-POS-Automation-Macro/
├── QA_POS_Automation_Macro.ahk   # Codigo fuente principal (AutoHotkey v2)
├── build.bat                     # Script de compilacion automatica x64 y x86
├── COMPILATION_GUIDE.md          # Manual tecnico del proceso de compilacion
├── GUIA_OPERADOR_POS.md          # Guia de referencia para operadores de terminal
├── README.md                     # Documentacion tecnica del sistema
├── Macro_POS_Local.txt           # Macro base de demostracion
├── Macros/                       # Directorio de almacenamiento de macros (.txt)
│   └── Macro_POS_Local.txt
├── Reports/                      # Directorio de reportes de ejecucion (.csv)
├── .gitignore                    # Filtros de exclusion para control de versiones
└── LICENSE                       # Licencia de software MIT
```

---

## 10. Licencia

Distribuido bajo la Licencia MIT. Consulte el archivo `LICENSE` para mas informacion.

---

## 11. Reconocimiento de Asistencia de IA

Este proyecto fue conceptualizado, diseñado, desarrollado y probado bajo la dirección y autoría de **Efrain Cortez**, contando con el apoyo y asistencia técnica de modelos de **Inteligencia Artificial (IA)** para pair-programming, diseño de arquitectura de eventos de bajo nivel en Windows Win32, interfaz Aero Glass nativa, pruebas de concurrencia y documentación técnica.


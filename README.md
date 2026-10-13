# 🪟 Xstore QA Automation Suite

> **Suite portable de automatización de transacciones POS con macros para Oracle Xstore**  
> *Windows Vista Aero Glass Edition • Cero latencia nativa • Soporte 32-bit y 64-bit*

[![Release](https://img.shields.io/badge/Release-v2.3.0-0078D7.svg?style=flat-square)](https://github.com/EfrainSN/Xstore-QA-Automation-Suite/releases)
[![Platform](https://img.shields.io/badge/Platform-Windows%20POSReady%20%7C%2010%20%7C%2011-00a2ed.svg?style=flat-square)](https://github.com/EfrainSN/Xstore-QA-Automation-Suite)
[![AutoHotkey](https://img.shields.io/badge/Language-AutoHotkey%20v2.0-334455.svg?style=flat-square)](https://www.autohotkey.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

---

## 🌟 ¿Qué es Xstore QA Suite?

**Xstore QA Suite** es una herramienta especializada y 100% portable diseñada para automatizar transacciones en puntos de venta (**Oracle Xstore POS**). Permite grabar, afinar y reproducir secuencias completas de ventas, cobros con tarjeta, anulaciones y cierres directamente en la caja terminal, con latencia nula (< 5 ms) y sin depender de software de escritorio remoto.

---

## 💎 Novedades v2.3 (Aero Glass Edition)

- 🎨 **Estilo Windows Vista Aero Glass:** Paleta de colores en azul hielo escarchado (`#D9EBF7`), encabezado vítreo en zafiro (`#123859`), botones táctiles con brillo de cristal y barra de progreso aguamarina (`#00A2ED`).
- ⚡ **Enfoque en Automatización de Transacciones:** Menos complejidad técnica y mayor agilidad operativa.
  - **1 Transacción Rápida:** Ejecuta una venta completa con un solo clic.
  - **Lote de Transacciones:** Automatiza un número determinado de tickets (ej. 5, 10) con pausas configurables.
  - **Modo Continuo (∞):** Ejecución ininterrumpida con parada instantánea.
- 🔴 **Grabador de Macros No Intrusivo:** Captura pulsaciones y pausas en tiempo real sin bloquear el teclado del POS.
- 📝 **Editor Integrado:** Botón directo para editar secuencias en Bloc de Notas y ajustar códigos de barras o tiempos.
- 🛡️ **Seguridad y Foco:** Control con **Ctrl + P** (Pausa) y **Ctrl + M** (Kill Switch de emergencia), manteniendo libres las teclas `F1-F12`.
- 📊 **Auditoría Automática:** Generación de reportes CSV con tiempos por ticket y duraciones en milisegundos.

---

## 🚀 Inicio Rápido

1. Descarga el archivo ejecutable portable desde [Releases](https://github.com/EfrainSN/Xstore-QA-Automation-Suite/releases):
   - **64 bits:** `Xstore_QA_Automation_Suite_v2.3.exe`
   - **32 bits (POSReady / Legacy):** `Xstore_QA_Automation_Suite_v2.3_x86.exe`
   - **Paquete Portable:** `Xstore_QA_Suite_v2.3_Portable.zip`
2. Copia el archivo al terminal POS (vía USB, red o ISL Light).
3. Ejecuta el `.exe`. Las carpetas `Macros/` y `Reports/` se crean automáticamente.
4. En la pestaña **🚀 Automatizar**, vincula la ventana de Xstore y pulsa **▶️ EJECUTAR TRANSACCIÓN**.

---

## 🛠️ Compilación desde el Código Fuente

El proyecto incluye el script automatizado **`build.bat`**:

1. Asegúrate de tener instalado **AutoHotkey v2.0+** y **Ahk2Exe**.
2. Ejecuta `build.bat`:
   ```cmd
   build.bat
   ```
3. Se generarán automáticamente los ejecutables portables de 64 bits y 32 bits en la raíz del proyecto.

---

## 📁 Estructura del Proyecto

```text
├── Xstore_QA_Suite.ahk       # Código fuente principal (AutoHotkey v2)
├── build.bat                 # Script de compilación automática
├── COMPILATION_GUIDE.md      # Guía detallada de compilación
├── README_QA_GUIA.md         # Guía de usuario para operadores de caja
├── README.md                 # Documentación general del repositorio
├── Macro_Xstore_Local.txt    # Macro de ejemplo base
├── Macros/                   # Biblioteca local de macros (.txt)
└── Reports/                  # Registros generados en CSV
```

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo `LICENSE` para más detalles.

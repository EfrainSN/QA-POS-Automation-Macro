# Guía de Compilación - Xstore QA Suite (Enterprise POS Edition)

Esta guía explica cómo compilar el script `Xstore_QA_Suite.ahk` en un archivo ejecutable autónomo (`.exe`) para transferirlo y ejecutarlo de forma 100% portable en cajas POS.

---

## 📌 Política de Nombres y Versionado
Siempre que se realice una modificación, mejora o corrección en el código:
1. Se incrementa la versión en `Xstore_QA_Suite.ahk` (ejemplo: `v2.0` ➔ `v2.1` ➔ `v2.2`).
2. El archivo `.exe` generado llevará el número de versión en su nombre:
   - **64 bits**: `Xstore_QA_Automation_Suite_v2.1.exe`
   - **32 bits**: `Xstore_QA_Automation_Suite_v2.1_x86.exe`

---

## 🚀 Método 1: Compilación Automática en 1 Clic (Recomendado)

En la raíz del proyecto se encuentra el script automatizado **`build.bat`**:

1. Haz doble clic en **`build.bat`** (o ejecútalo desde la consola).
2. El script detectará la versión actual en `Xstore_QA_Suite.ahk`, invocará el compilador oficial y generará automáticamente:
   - `Xstore_QA_Automation_Suite_vX.X.exe` (x64)
   - `Xstore_QA_Automation_Suite_vX.X_x86.exe` (x86)

---

## 🛠️ Método 2: Compilación Manual por Línea de Comandos

Ubicación del compilador en este equipo:
`%LOCALAPPDATA%\Programs\AutoHotkey\Compiler\Ahk2Exe.exe`

#### Versión x64 (Recomendada para la mayoría de terminales POS):
```cmd
"%LOCALAPPDATA%\Programs\AutoHotkey\Compiler\Ahk2Exe.exe" /in "Xstore_QA_Suite.ahk" /out "Xstore_QA_Automation_Suite_v2.1.exe" /base "%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe"
```

#### Versión x86 (Para terminales POS de 32 bits o Windows POSReady):
```cmd
"%LOCALAPPDATA%\Programs\AutoHotkey\Compiler\Ahk2Exe.exe" /in "Xstore_QA_Suite.ahk" /out "Xstore_QA_Automation_Suite_v2.1_x86.exe" /base "%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey32.exe"
```

---

## 📦 Despliegue Portable en la Caja POS

1. Transfiere `Xstore_QA_Automation_Suite_v2.1.exe` (o el paquete `Xstore_QA_Suite_v2.1_Portable.zip`) al POS.
2. Ejecuta el `.exe`. La suite detectará y creará las carpetas `Macros/` y `Reports/` automáticamente si no existen.
3. No requiere instalación de dependencias en la terminal POS.


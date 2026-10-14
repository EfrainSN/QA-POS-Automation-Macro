# Guia de Compilacion - QA POS Automation Macro

Esta guia documenta el proceso tecnico para compilar el codigo fuente de `QA_POS_Automation_Macro.ahk` en binarios independientes y portables (.exe) compatibles con arquitecturas de 32 bits y 64 bits.

---

## 1. Requisitos del Entorno de Compilacion

- Sistema Operativo: Windows 7, POSReady 7, Windows 10, Windows 11 o Windows Server.
- Motor de Lenguaje: AutoHotkey v2.0 o superior.
- Compilador: `Ahk2Exe.exe` oficial de AutoHotkey.
- Binarios Base:
  - Base x64: `AutoHotkey64.exe` (v2.0+)
  - Base x86: `AutoHotkey32.exe` (v2.0+)

Ubicacion estandar del compilador:
`%LOCALAPPDATA%\Programs\AutoHotkey\Compiler\Ahk2Exe.exe`

---

## 2. Compilacion Automatizada con build.bat

El repositorio incluye el script `build.bat`, el cual detecta la version declarada en la cabecera del codigo fuente e invoca el compilador para generar ambas arquitecturas en una sola ejecucion:

```cmd
build.bat
```

Salidas generadas:
- `QA_POS_Automation_Macro_vX.X.exe` (64 bits para terminales POS modernas).
- `QA_POS_Automation_Macro_vX.X_x86.exe` (32 bits para sistemas legacy y Windows POSReady).

---

## 3. Compilacion Manual por Linea de Comandos

### Arquitectura 64 bits:
```cmd
"%LOCALAPPDATA%\Programs\AutoHotkey\Compiler\Ahk2Exe.exe" /in "QA_POS_Automation_Macro.ahk" /out "QA_POS_Automation_Macro_v2.6.exe" /base "%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe"
```

### Arquitectura 32 bits:
```cmd
"%LOCALAPPDATA%\Programs\AutoHotkey\Compiler\Ahk2Exe.exe" /in "QA_POS_Automation_Macro.ahk" /out "QA_POS_Automation_Macro_v2.6_x86.exe" /base "%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey32.exe"
```

---

## 4. Validacion del Binario Generado

1. Verifique que el binario compile sin advertencias de sintaxis.
2. Compruebe la ejecucion sin dependencias adicionales en una maquina virtual o caja de pruebas limpia.
3. El binario debe autogestionar la creacion de los directorios `Macros/` y `Reports/` en su primer inicio.

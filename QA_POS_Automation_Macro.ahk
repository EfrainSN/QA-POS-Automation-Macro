; ==============================================================================
; PROJECT: QA POS Automation Macro
; VERSION: 2.9.1 (PosLog.xml Ticket Extractor, VTOL Sentinel & Modal Keycode Fix)
; LANGUAGE: AutoHotkey v2.0+
; TARGET: Windows 10/11 / Windows POSReady / Windows Server (Terminales POS)
; PURPOSE: Punto de entrada principal con arquitectura modular en capas (src\).
;          Sincronizacion deterministica con xstore.log (WaitPrompt / Action),
;          extraccion dual de comprobantes (PosLog.xml + xstore.log),
;          Centinela para logs DEBUG SQL masivos con deteccion exacta de rechazo VTOL,
;          y Dashboard Forense de alta densidad con graficos SVG e impresion termica.
; ==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)
SetTitleMatchMode(2)
SetTitleMatchMode("Slow")
SetDefaultMouseSpeed(0)

; Asegurar privilegios de administrador para interactuar con terminales POS y Java Swing sin bloqueos de UIPI
if (!A_IsAdmin) {
    try {
        if (A_IsCompiled)
            Run('*RunAs "' . A_ScriptFullPath . '" /restart')
        else
            Run('*RunAs "' . A_AhkPath . '" /restart "' . A_ScriptFullPath . '"')
        ExitApp()
    }
}

; 1. Librerias Externas
#Include "Lib\UIA.ahk"

; 2. Capa de Nucleo y Configuracion (Core)
#Include "src\Core\Globals.ahk"
#Include "src\Core\ConfigManager.ahk"
#Include "src\Core\Updater.ahk"

; 3. Capa de Integracion con Terminal POS, Xstore Logs y PosLog.xml (POS)
#Include "src\POS\PosWindowManager.ahk"
#Include "src\POS\XstoreSentinel.ahk"
#Include "src\POS\XstoreLogSync.ahk"
#Include "src\POS\PosLogParser.ahk"

; 4. Capa de Motores de Grabacion y Ejecucion (Engine)
#Include "src\Engine\MacroRecorder.ahk"
#Include "src\Engine\MacroPlayer.ahk"

; 5. Capa de Reportes, Comprobantes y Auditoria Forense (Reports)
#Include "src\Reports\ForensicDashboard.ahk"

; 6. Capa de Interfaz Grafica y Editor de Pasos (UI)
#Include "src\UI\FloatingHUD.ahk"
#Include "src\UI\StepEditor.ahk"
#Include "src\UI\MainWindow.ahk"

; 7. Inicializacion y Arranque de la Suite
InitializeApplication()

; 8. Atajos Globales y Hooks de Captura en Vivo (Hotkeys)
#Include "src\Engine\Hotkeys.ahk"

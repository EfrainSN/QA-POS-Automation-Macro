; ==============================================================================
; PROJECT: Xstore QA Suite • Automatización de Macros
; VERSION: 2.3.0 (Windows Vista Aero Glass Edition)
; AUTHOR: Senior QA Automation Engineer
; LANGUAGE: AutoHotkey v2.0+
; TARGET: Windows 10/11 / Windows POSReady / Windows Server (Oracle Xstore POS)
; PURPOSE: Automatización amigable y de alta precisión de transacciones en caja POS.
;          Diseñada para ejecutar ventas, cobros y flujos completos con macros,
;          con interfaz fluida, estética Windows Vista Aero Glass y cero latencia.
; ==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

; ==============================================================================
; VARIABLES DE ESTADO GLOBAL
; ==============================================================================
global isRecording := false
global isPausedRec := false
global isPlaying := false
global isPausedPlay := false
global stopPlayback := false
global firstKeyRecorded := false
global lastTick := 0
global textBuffer := ""
global macroBuffer := []
global keyHook := ""

; Directorios (Rutas absolutas ancladas para portabilidad total en POS)
global macroFolder := A_ScriptDir . "\Macros"
global reportsFolder := A_ScriptDir . "\Reports"

; Telemetría y Estado de Automatización
global autoTotalCycles := 1
global autoCurrentCycle := 0
global autoSuccessCount := 0
global autoFailCount := 0
global autoStartTime := 0
global autoCycleStart := 0
global autoCurrentCSV := ""
global targetWinTitle := "Xstore"
global speedMultiplier := 1.0

; Mapeo de teclas de navegación y función {Key} para teclado de caja POS
global specialKeys := Map(
    "Enter", true, "Escape", true, "Tab", true, "Space", true, "Backspace", true,
    "Delete", true, "Insert", true, "Up", true, "Down", true, "Left", true, "Right", true,
    "Home", true, "End", true, "PgUp", true, "PgDn", true,
    "F1", true, "F2", true, "F3", true, "F4", true, "F5", true, "F6", true,
    "F7", true, "F8", true, "F9", true, "F10", true, "F11", true, "F12", true,
    "NumpadEnter", true
)

; ==============================================================================
; GESTIÓN DE DIRECTORIOS Y RECURSOS PORTABLES
; ==============================================================================
EnsureRequiredDirectories() {
    global macroFolder, reportsFolder
    createdAny := false

    if (!DirExist(macroFolder)) {
        try {
            DirCreate(macroFolder)
            createdAny := true
        } catch Error as err {
            MsgBox("Aviso: No se pudo crear la carpeta de macros:`n" . macroFolder . "`n`nDetalle: " . err.Message,
                "Xstore Macro Suite", "Icon!")
        }
    }

    if (!DirExist(reportsFolder)) {
        try {
            DirCreate(reportsFolder)
            createdAny := true
        } catch Error as err {
            MsgBox("Aviso: No se pudo crear la carpeta de reportes:`n" . reportsFolder . "`n`nDetalle: " . err.Message,
                "Xstore Macro Suite", "Icon!")
        }
    }

    ; Si existe macro de ejemplo en la raíz, copiarla a Macros si está vacía
    if (FileExist(A_ScriptDir . "\Macro_Xstore_Local.txt") && !FileExist(macroFolder . "\Macro_Xstore_Local.txt")) {
        try FileCopy(A_ScriptDir . "\Macro_Xstore_Local.txt", macroFolder . "\Macro_Xstore_Local.txt", 0)
    }

    return createdAny
}

EnsureRequiredDirectories()

; ==============================================================================
; INTERFAZ DE USUARIO: WINDOWS VISTA AERO GLASS EDITION
; ==============================================================================
mainGui := Gui("+AlwaysOnTop -MaximizeBox", "Oracle Xstore POS • Automatización de Macros v2.3")
mainGui.BackColor := "D9EBF7" ; Tono azul hielo cristalino característico de Windows Vista Aero
mainGui.SetFont("s9", "Segoe UI")

; --- ENCABEZADO AERO GLASS HEADER ---
hdrBg := mainGui.Add("Text", "x12 y10 w416 h48 +Border Background123859", "")
txtBrand := mainGui.Add("Text", "x24 y14 w392 h20 BackgroundTrans c5AD1FF", "🪟 XSTORE MACRO SUITE • AERO EDITION")
txtBrand.SetFont("s10 Bold", "Segoe UI")
txtStatus := mainGui.Add("Text", "x24 y34 w392 h18 BackgroundTrans cE2F3FF", "✨ Listo para automatizar transacciones en Xstore POS")

; --- PESTAÑAS PRINCIPALES ---
mainTabs := mainGui.Add("Tab3", "x12 y65 w416 h472", ["🚀 Automatizar", "🔴 Grabar Macro", "📂 Biblioteca"])

; ------------------------------------------------------------------------------
; PESTAÑA 1: 🚀 AUTOMATIZAR TRANSACCIONES
; ------------------------------------------------------------------------------
mainTabs.UseTab(1)

; 1. Vinculación con Xstore POS
mainGui.Add("GroupBox", "x24 y96 w392 h68", "1. Ventana de Xstore POS")
mainGui.Add("Text", "x36 y119 w85 h20 c153858", "Ventana POS:")
edtTargetWin := mainGui.Add("Edit", "x125 y116 w170 h24 BackgroundFFFFFF", targetWinTitle)
btnDetectWin := mainGui.Add("Button", "x302 y115 w102 h26", "🎯 Vincular")

; 2. Selección de Macro / Transacción
mainGui.Add("GroupBox", "x24 y170 w392 h76", "2. Transacción a Ejecutar")
mainGui.Add("Text", "x36 y193 w115 h20 c153858", "Macro Guardada:")
ddlMacros := mainGui.Add("DropDownList", "x152 y190 w176 Choose1", ["(Sin macros)"])
btnRefresh := mainGui.Add("Button", "x334 y189 w34 h26", "🔄")
btnOpenFolderMacro := mainGui.Add("Button", "x370 y189 w34 h26", "📂")
mainGui.Add("Text", "x36 y220 w368 h18 c416A8C", "💡 Elige la macro para automatizar tu venta o cobro sin digitar a mano.")

; 3. Modo de Ejecución de Transacciones
mainGui.Add("GroupBox", "x24 y252 w392 h118", "3. Modo de Automatización")
mainGui.Add("Text", "x36 y274 w95 h20 c153858", "Ejecutar:")
radModeSingle := mainGui.Add("Radio", "x135 y273 w110 h20 Checked", "1 Transacción")
radModeBatch := mainGui.Add("Radio", "x250 y273 w65 h20", "Lote:")
edtReps := mainGui.Add("Edit", "x318 y271 w50 h22 Number Center BackgroundFFFFFF Disabled", "5")
mainGui.Add("Text", "x372 y274 w35 h20 c416A8C", "veces")

chkInfinite := mainGui.Add("CheckBox", "x135 y298 w180 h20", "Modo Continuo sin fin (∞)")

mainGui.Add("Text", "x36 y330 w95 h20 c153858", "Velocidad:")
ddlSpeed := mainGui.Add("DropDownList", "x135 y327 w130 Choose2", [
    "0.8x (Seguro / Pausado)",
    "1.0x (Normal Recomendado)",
    "1.2x (Rápido POS)",
    "1.5x (Turbo Ágil)"
])
mainGui.Add("Text", "x274 y330 w130 h20 c416A8C", "Pausa: 1.0s / txn")
edtLoopDelay := mainGui.Add("Edit", "x0 y0 w0 h0 Hidden", "1000") ; Buffer oculto para delay

; 4. Monitor de Progreso Aero Glass
mainGui.Add("GroupBox", "x24 y376 w392 h84", "Estado de la Automatización")
progBar := mainGui.Add("Progress", "x36 y396 w368 h16 Range0-100 c00A2ED BackgroundC8E3F5", 0)
txtProgress := mainGui.Add("Text", "x36 y416 w368 h18 Center c153858", "Listo para iniciar • Esperando orden")
txtProgress.SetFont("Bold")

txtMetricsA := mainGui.Add("Text", "x36 y436 w180 h18 c153858", "⏱️ Tiempo: 00:00:00")
txtMetricsC := mainGui.Add("Text", "x224 y436 w180 h18 Right c0E7D42", "✅ Completadas: 0")

; Botonera Principal de Acción (Touch-Friendly)
btnPlay := mainGui.Add("Button", "x24 y466 w140 h45 Default", "▶️ EJECUTAR`nTRANSACCIÓN")
btnPausePlay := mainGui.Add("Button", "x170 y466 w120 h45 Disabled", "⏸️ PAUSAR`n(Ctrl+P)")
btnStop := mainGui.Add("Button", "x296 y466 w120 h45", "🛑 DETENER`n(Ctrl+M)")

; ------------------------------------------------------------------------------
; PESTAÑA 2: 🔴 GRABAR NUEVA MACRO
; ------------------------------------------------------------------------------
mainTabs.UseTab(2)

mainGui.Add("GroupBox", "x24 y96 w392 h170", "Nueva Secuencia de Transacción")
mainGui.Add("Text", "x36 y118 w368 h28 c416A8C",
    "Asigna un nombre descriptivo a tu macro, presiona Grabar y realiza la operación en Xstore. Las teclas y tiempos quedarán listos para reproducirse."
)
mainGui.Add("Text", "x36 y153 w110 h20 c153858", "Nombre de Macro:")
edtMacroName := mainGui.Add("Edit", "x150 y150 w242 h24 BackgroundFFFFFF", "Transaccion_" . FormatTime(, "yyyyMMdd_HHmmss"))

btnRecord := mainGui.Add("Button", "x36 y182 w170 h38", "🔴 Iniciar Grabación")
btnPauseRec := mainGui.Add("Button", "x222 y182 w170 h38 Disabled", "⏸️ Pausar")

btnSaveRec := mainGui.Add("Button", "x36 y224 w170 h36 Disabled", "💾 Guardar en Biblioteca")
btnCancelRec := mainGui.Add("Button", "x222 y224 w170 h36 Disabled", "❌ Cancelar")

mainGui.Add("GroupBox", "x24 y274 w392 h238", "Visor de Secuencia Capturada (En Vivo)")
edtBufferPreview := mainGui.Add("Edit", "x36 y297 w368 h205 ReadOnly BackgroundF8FBFE",
    "; Las pulsaciones y pausas de Xstore aparecerán aquí automáticamente...`r`n")

; ------------------------------------------------------------------------------
; PESTAÑA 3: 📂 BIBLIOTECA Y REGISTRO
; ------------------------------------------------------------------------------
mainTabs.UseTab(3)

mainGui.Add("GroupBox", "x24 y96 w392 h165", "Resumen de la Última Automatización")
txtRepInfo1 := mainGui.Add("Text", "x36 y120 w368 h20 c153858", "📄 Registro CSV: (Ninguno)")
txtRepInfo2 := mainGui.Add("Text", "x36 y145 w368 h20 c153858", "🔄 Total de Transacciones: 0")
txtRepInfo3 := mainGui.Add("Text", "x36 y170 w368 h20 c153858", "⏱️ Duración Total: 0s")
txtRepInfo4 := mainGui.Add("Text", "x36 y195 w368 h20 c153858", "🚀 Promedio por Transacción: 0.0s")
txtRepInfo5 := mainGui.Add("Text", "x36 y220 w368 h20 c0E7D42", "📈 Tasa de Éxito: 100%")

mainGui.Add("GroupBox", "x24 y270 w392 h172", "Gestión de Macros y Auditoría")
btnEditMacro := mainGui.Add("Button", "x36 y295 w175 h40", "📝 Editar Macro`nen Bloc de Notas")
btnOpenMacros := mainGui.Add("Button", "x219 y295 w175 h40", "📁 Carpeta de`nMacros (.txt)")

btnViewLastCSV := mainGui.Add("Button", "x36 y345 w175 h40", "📄 Ver Último`nRegistro CSV")
btnOpenReports := mainGui.Add("Button", "x219 y345 w175 h40", "📁 Carpeta de`nReportes CSV")

mainGui.Add("Text", "x36 y398 w368 h35 c416A8C",
    "💡 Tip: Puedes abrir cualquier macro con el Bloc de Notas para ajustar manualmente teclas, códigos de barra o pausas según lo requiera tu POS."
)

mainTabs.UseTab() ; Fin de pestañas

; --- PIE DE VENTANA (FOOTER AERO GLASS) ---
mainGui.SetFont("s8 c406888", "Segoe UI")
mainGui.Add("Text", "x12 y542 w416 Center",
    "Oracle Xstore POS • Automatización de Macros v2.3 • Ctrl+P: Pausar • Ctrl+M: Detener")
mainGui.SetFont("s9", "Segoe UI")

; ==============================================================================
; ENLACE DE EVENTOS Y CONTROLADORES
; ==============================================================================
btnDetectWin.OnEvent("Click", DetectTargetWindow)
btnRefresh.OnEvent("Click", RefreshMacroList)
btnOpenFolderMacro.OnEvent("Click", (*) => (EnsureRequiredDirectories(), Run("explore `"" . macroFolder . "`"")))

radModeSingle.OnEvent("Click", UpdateExecutionMode)
radModeBatch.OnEvent("Click", UpdateExecutionMode)
chkInfinite.OnEvent("Click", ToggleInfiniteMode)
ddlSpeed.OnEvent("Change", UpdateSpeedMultiplier)

btnPlay.OnEvent("Click", StartAutomation)
btnPausePlay.OnEvent("Click", TogglePauseAutomation)
btnStop.OnEvent("Click", EmergencyStop)

btnRecord.OnEvent("Click", StartRecording)
btnPauseRec.OnEvent("Click", TogglePauseRecording)
btnSaveRec.OnEvent("Click", SaveRecording)
btnCancelRec.OnEvent("Click", CancelRecording)

btnEditMacro.OnEvent("Click", EditSelectedMacro)
btnOpenMacros.OnEvent("Click", (*) => (EnsureRequiredDirectories(), Run("explore `"" . macroFolder . "`"")))
btnOpenReports.OnEvent("Click", (*) => (EnsureRequiredDirectories(), Run("explore `"" . reportsFolder . "`"")))
btnViewLastCSV.OnEvent("Click", OpenLastCSVReport)

mainGui.OnEvent("Close", (*) => ExitApp())

; Cargar macros y mostrar interfaz al arrancar
RefreshMacroList()
mainGui.Show("w440 h568")

; ==============================================================================
; DETECCIÓN Y FOCO DE VENTANA XSTORE
; ==============================================================================

DetectTargetWindow(*) {
    global targetWinTitle, edtTargetWin
    MsgBox(
        "Haz clic en 'Aceptar' y luego activa (haz clic en) la ventana de Xstore POS dentro de los próximos 4 segundos.",
        "Vinculador de Ventana Xstore", "Iconi")
    Sleep(4000)
    activeTitle := WinGetTitle("A")
    if (activeTitle != "" && activeTitle != mainGui.Title) {
        targetWinTitle := activeTitle
        edtTargetWin.Text := activeTitle
        UpdateStatus("🎯 Ventana POS enlazada: " . SubStr(activeTitle, 1, 32))
    } else {
        MsgBox("No se detectó un cambio de ventana o seleccionaste esta misma aplicación.", "Xstore Macro Suite", "Icon!")
    }
}

EnsureTargetWindowActive() {
    global targetWinTitle, edtTargetWin
    currentTitle := Trim(edtTargetWin.Text)
    if (currentTitle == "")
        currentTitle := "Xstore"

    if WinExist(currentTitle) {
        if (!WinActive(currentTitle)) {
            WinActivate(currentTitle)
            WinWaitActive(currentTitle, , 3)
        }
        return WinActive(currentTitle)
    }
    return false
}

; ==============================================================================
; GESTIÓN DE MODOS Y LISTA DE MACROS
; ==============================================================================

UpdateExecutionMode(*) {
    global radModeSingle, radModeBatch, edtReps, chkInfinite
    if (radModeSingle.Value == 1) {
        edtReps.Enabled := false
    } else if (radModeBatch.Value == 1) {
        edtReps.Enabled := true
        chkInfinite.Value := 0
    }
}

ToggleInfiniteMode(*) {
    global chkInfinite, radModeSingle, radModeBatch, edtReps
    if (chkInfinite.Value == 1) {
        radModeSingle.Value := 0
        radModeBatch.Value := 0
        edtReps.Enabled := false
    } else {
        radModeSingle.Value := 1
        edtReps.Enabled := false
    }
}

RefreshMacroList(*) {
    global ddlMacros, btnPlay, macroFolder

    EnsureRequiredDirectories()

    macroFiles := []
    loop files, macroFolder . "\*.txt" {
        macroFiles.Push(A_LoopFileName)
    }

    ddlMacros.Delete()
    if (macroFiles.Length > 0) {
        ddlMacros.Add(macroFiles)
        ddlMacros.Choose(1)
        if (!isRecording && !isPlaying)
            btnPlay.Enabled := true
    } else {
        ddlMacros.Add(["(Sin macros guardadas)"])
        ddlMacros.Choose(1)
        btnPlay.Enabled := false
    }
}

UpdateSpeedMultiplier(*) {
    global ddlSpeed, speedMultiplier
    idx := ddlSpeed.Value
    switch idx {
        case 1: speedMultiplier := 1.25  ; 0.8x seguro / pausado
        case 2: speedMultiplier := 1.0   ; 1.0x normal recomendado
        case 3: speedMultiplier := 0.83  ; 1.2x rápido POS
        case 4: speedMultiplier := 0.67  ; 1.5x turbo ágil
        default: speedMultiplier := 1.0
    }
}

EditSelectedMacro(*) {
    global ddlMacros, macroFolder
    EnsureRequiredDirectories()
    selectedMacro := ddlMacros.Text
    if (selectedMacro == "" || selectedMacro == "(Sin macros guardadas)") {
        MsgBox("Selecciona primero una macro válida para editar.", "Xstore Macro Suite", "Icon!")
        return
    }
    fullPath := macroFolder . "\" . selectedMacro
    if FileExist(fullPath) {
        Run("notepad.exe `"" . fullPath . "`"")
    } else {
        MsgBox("El archivo '" . fullPath . "' no existe.", "Xstore Macro Suite", "Iconx")
    }
}

; ==============================================================================
; MOTOR DE AUTOMATIZACIÓN DE TRANSACCIONES (EJECUCIÓN NATIVA)
; ==============================================================================

StartAutomation(*) {
    global isPlaying, isPausedPlay, stopPlayback, ddlMacros, macroFolder, reportsFolder
    global autoTotalCycles, autoCurrentCycle, autoSuccessCount, autoFailCount
    global autoStartTime, autoCurrentCSV, speedMultiplier, progBar, txtProgress
    global btnPlay, btnPausePlay, btnRecord, radModeSingle, radModeBatch, edtReps, chkInfinite, edtLoopDelay

    EnsureRequiredDirectories()

    if (isRecording) {
        MsgBox("Debes guardar o cancelar la grabación activa antes de iniciar la automatización.", "Xstore Macro Suite", "Icon!")
        return
    }

    selectedMacro := ddlMacros.Text
    if (selectedMacro == "" || selectedMacro == "(Sin macros guardadas)") {
        MsgBox("No hay ninguna macro seleccionada.`nGraba una macro primero en la pestaña '🔴 Grabar Macro'.",
            "Xstore Macro Suite", "Iconx")
        return
    }

    fullMacroPath := macroFolder . "\" . selectedMacro
    if (!FileExist(fullMacroPath)) {
        MsgBox("El archivo de macro '" . fullMacroPath . "' no existe.", "Xstore Macro Suite", "Iconx")
        RefreshMacroList()
        return
    }

    ; Determinar total de repeticiones según el modo seleccionado
    if (chkInfinite.Value == 1) {
        totalReps := 999999
    } else if (radModeBatch.Value == 1) {
        numInput := Integer(edtReps.Text)
        totalReps := (numInput > 0) ? numInput : 1
    } else {
        totalReps := 1 ; Modo 1 Transacción
    }

    loopDelay := Integer(edtLoopDelay.Text >= 0 ? edtLoopDelay.Text : 1000)
    keyDelay := 25 ; Base key delay para máxima estabilidad en hardware POS

    ; Inicializar telemetría de sesión
    autoTotalCycles := totalReps
    autoCurrentCycle := 0
    autoSuccessCount := 0
    autoFailCount := 0
    autoStartTime := A_TickCount
    isPlaying := true
    isPausedPlay := false
    stopPlayback := false

    ; Archivo de registro CSV para auditoría
    csvName := "Registro_Transacciones_" . FormatTime(, "yyyyMMdd_HHmmss") . "_" . RegExReplace(selectedMacro, "\.txt$", "") . ".csv"
    autoCurrentCSV := reportsFolder . "\" . csvName
    csvHeader := "Transaccion,Fecha_Inicio,Fecha_Fin,Duracion_Seg,Duracion_Ms,Estado,Macro`n"
    FileAppend(csvHeader, autoCurrentCSV, "UTF-8")

    ; Actualizar controles UI
    btnPlay.Enabled := false
    btnPausePlay.Enabled := true
    btnPausePlay.Text := "⏸️ PAUSAR`n(Ctrl+P)"
    btnRecord.Enabled := false
    progBar.Value := 0

    ; Conectar con ventana objetivo de Xstore
    UpdateStatus("🎯 Conectando con Xstore POS...")
    if (!EnsureTargetWindowActive()) {
        ans := MsgBox("No se encontró la ventana objetivo ('" . edtTargetWin.Text . "').`n¿Deseas continuar de todas formas?",
            "Aviso de Foco Xstore", "YesNo Icon?")
        if (ans != "Yes") {
            isPlaying := false
            ResetUI()
            UpdateStatus("🛑 Cancelado: ventana de Xstore no detectada")
            return
        }
    }

    if (totalReps == 1)
        UpdateStatus("▶️ Ejecutando 1 Transacción con '" . selectedMacro . "'")
    else if (chkInfinite.Value == 1)
        UpdateStatus("▶️ Automatizando transacciones en modo continuo (∞)")
    else
        UpdateStatus("▶️ Automatizando lote de " . totalReps . " transacciones...")

    ; Iniciar monitor HUD en vivo
    SetTimer(UpdateLiveMetricsHUD, 400)

    ; Leer instrucciones del archivo de macro
    fileLines := FileRead(fullMacroPath, "UTF-8")

    ; Bucle principal de ejecución de transacciones
    loop totalReps {
        if (stopPlayback)
            break

        autoCurrentCycle := A_Index
        cycleStartTick := A_TickCount
        cycleStartTimeStr := FormatTime(, "yyyy-MM-dd HH:mm:ss")

        ; Pausa interactiva
        while (isPausedPlay && !stopPlayback) {
            Sleep(100)
        }

        if (stopPlayback)
            break

        ; Asegurar foco en Xstore antes de cada ticket o venta
        EnsureTargetWindowActive()

        ; Reproducir macro línea a línea
        loop parse, fileLines, "`n", "`r" {
            if (stopPlayback)
                break

            while (isPausedPlay && !stopPlayback) {
                Sleep(100)
            }

            line := Trim(A_LoopField)
            if (line == "" || SubStr(line, 1, 1) == ";")
                continue

            if (SubStr(line, 1, 6) == "Sleep,") {
                rawSleep := Integer(Trim(SubStr(line, 7)))
                actualSleep := Integer(rawSleep * speedMultiplier)
                InterruptibleSleep(actualSleep)
            } else if (SubStr(line, 1, 5) == "Send,") {
                cmd := Trim(SubStr(line, 6))
                if (cmd != "") {
                    SetKeyDelay(keyDelay, keyDelay)
                    SendEvent(cmd)
                    InterruptibleSleep(keyDelay)
                }
            }
        }

        cycleEndTick := A_TickCount
        cycleEndTimeStr := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        cycleDurationMs := cycleEndTick - cycleStartTick
        cycleDurationSec := Round(cycleDurationMs / 1000, 2)

        ; Registrar resultado en CSV
        if (stopPlayback) {
            autoFailCount++
            logStatus := "INTERRUMPIDO"
        } else {
            autoSuccessCount++
            logStatus := "COMPLETADO"
        }

        csvRow := autoCurrentCycle . "," . cycleStartTimeStr . "," . cycleEndTimeStr . ","
            . cycleDurationSec . "," . cycleDurationMs . "," . logStatus . "," . selectedMacro . "`n"
        try FileAppend(csvRow, autoCurrentCSV, "UTF-8")

        ; Pausa entre transacciones (solo si hay más transacciones pendientes)
        if (!stopPlayback && autoCurrentCycle < totalReps) {
            InterruptibleSleep(loopDelay)
        }
    }

    SetTimer(UpdateLiveMetricsHUD, 0)
    isPlaying := false
    isPausedPlay := false

    ; Actualizar métricas finales
    UpdateLiveMetricsHUD()
    UpdateReportsTabSummary()

    if (stopPlayback) {
        UpdateStatus("🛑 Automatización detenida por el usuario")
        MsgBox("Ejecución detenida en la transacción " . autoCurrentCycle . " de " . totalReps . ".`n`nRegistro guardado en:`n" . autoCurrentCSV,
            "Xstore Macro Suite", "Icon!")
    } else {
        UpdateStatus("✅ ¡Transacción finalizada con éxito!")
        if (totalReps == 1) {
            MsgBox("¡Transacción completada exitosamente en Xstore POS!`n`nMacro: " . selectedMacro . "`nDuración: " . cycleDurationSec . "s",
                "Xstore Macro Suite", "Iconi")
        } else {
            MsgBox("¡Automatización completada exitosamente!`n`nTotal de transacciones: " . autoSuccessCount . "`nMacro: " . selectedMacro,
                "Xstore Macro Suite", "Iconi")
        }
    }

    ResetUI()
}

TogglePauseAutomation(*) {
    global isPausedPlay, btnPausePlay
    if (!isPlaying)
        return

    isPausedPlay := !isPausedPlay
    if (isPausedPlay) {
        btnPausePlay.Text := "▶️ REANUDAR`n(Ctrl+P)"
        UpdateStatus("⏸️ Transacción pausada • Presiona Ctrl+P para reanudar")
    } else {
        btnPausePlay.Text := "⏸️ PAUSAR`n(Ctrl+P)"
        UpdateStatus("▶️ Reanudando transacción en Xstore...")
        EnsureTargetWindowActive()
    }
}

InterruptibleSleep(durationMs) {
    global stopPlayback, isPausedPlay
    step := 25
    elapsed := 0
    while (elapsed < durationMs) {
        if (stopPlayback)
            break
        while (isPausedPlay && !stopPlayback) {
            Sleep(50)
        }
        sleepTime := Min(step, durationMs - elapsed)
        Sleep(sleepTime)
        elapsed += sleepTime
    }
}

EmergencyStop(*) {
    global stopPlayback, isPlaying, isRecording
    if (isPlaying) {
        stopPlayback := true
        UpdateStatus("🛑 Deteniendo ejecución de transacciones...")
    } else if (isRecording) {
        CancelRecording()
    } else {
        UpdateStatus("✨ Listo para automatizar transacciones en Xstore POS")
    }
}

; Atajos Globales de Seguridad
#HotIf isPlaying
^p:: TogglePauseAutomation()
<^p:: TogglePauseAutomation()
#HotIf

#HotIf (isPlaying || isRecording)
^m:: EmergencyStop()
<^m:: EmergencyStop()
#HotIf

; ==============================================================================
; TELEMETRÍA Y HUD EN VIVO
; ==============================================================================

UpdateLiveMetricsHUD() {
    global isPlaying, autoTotalCycles, autoCurrentCycle, autoSuccessCount, autoFailCount, autoStartTime, chkInfinite
    global progBar, txtProgress, txtMetricsA, txtMetricsC

    elapsedSec := Round((A_TickCount - autoStartTime) / 1000)
    hours := Format("{:02}", elapsedSec // 3600)
    minutes := Format("{:02}", Mod(elapsedSec, 3600) // 60)
    seconds := Format("{:02}", Mod(elapsedSec, 60))
    timeFormatted := hours . ":" . minutes . ":" . seconds

    if (chkInfinite.Value == 1) {
        progBar.Value := 100
        txtProgress.Text := "Transacción " . autoCurrentCycle . " (Modo Continuo ∞)"
    } else {
        pct := (autoTotalCycles > 0) ? Integer((autoCurrentCycle / autoTotalCycles) * 100) : 0
        progBar.Value := pct
        txtProgress.Text := "Transacción: " . autoCurrentCycle . " de " . autoTotalCycles . " (" . pct . "%)"
    }

    txtMetricsA.Text := "⏱️ Tiempo: " . timeFormatted
    txtMetricsC.Text := "✅ Completadas: " . autoSuccessCount
}

UpdateReportsTabSummary() {
    global autoCurrentCSV, autoSuccessCount, autoFailCount, autoStartTime
    global txtRepInfo1, txtRepInfo2, txtRepInfo3, txtRepInfo4, txtRepInfo5

    totalRuns := autoSuccessCount + autoFailCount
    elapsedSec := Round((A_TickCount - autoStartTime) / 1000)
    avgSec := (autoSuccessCount > 0) ? Round(elapsedSec / autoSuccessCount, 1) : 0.0
    rate := (totalRuns > 0) ? Round((autoSuccessCount / totalRuns) * 100, 1) : 100.0

    txtRepInfo1.Text := "📄 Registro CSV: " . (autoCurrentCSV != "" ? autoCurrentCSV : "(Ninguno)")
    txtRepInfo2.Text := "🔄 Total de Transacciones: " . totalRuns . " (" . autoSuccessCount . " OK, " . autoFailCount . " Interrupciones)"
    txtRepInfo3.Text := "⏱️ Duración Total: " . elapsedSec . " segundos"
    txtRepInfo4.Text := "🚀 Promedio por Transacción: " . avgSec . "s"
    txtRepInfo5.Text := "📈 Tasa de Éxito: " . rate . "%"
}

OpenLastCSVReport(*) {
    global autoCurrentCSV, reportsFolder
    EnsureRequiredDirectories()
    if (autoCurrentCSV != "" && FileExist(autoCurrentCSV)) {
        Run(autoCurrentCSV)
    } else {
        latestFile := ""
        latestTime := ""
        loop files, reportsFolder . "\*.csv" {
            if (A_LoopFileTimeModified > latestTime) {
                latestTime := A_LoopFileTimeModified
                latestFile := A_LoopFileFullPath
            }
        }
        if (latestFile != "")
            Run(latestFile)
        else
            MsgBox("Aún no se han generado registros de transacciones.", "Xstore Macro Suite", "Iconi")
    }
}

; ==============================================================================
; MOTOR DE GRABACIÓN DE MACROS (HOOK NO INTRUSIVO)
; ==============================================================================

StartRecording(*) {
    global isRecording, isPausedRec, firstKeyRecorded, lastTick, macroBuffer, textBuffer, keyHook
    global btnRecord, btnPauseRec, btnSaveRec, btnCancelRec, btnPlay, edtBufferPreview, edtMacroName

    if (isPlaying) {
        MsgBox("No se puede grabar mientras se está ejecutando una automatización.", "Xstore Macro Suite", "Icon! 262144")
        return
    }

    macroBuffer := []
    textBuffer := ""
    isRecording := true
    isPausedRec := false
    firstKeyRecorded := false
    lastTick := 0

    currentName := Trim(edtMacroName.Text)
    if (currentName == "") {
        try edtMacroName.Text := "Transaccion_" . FormatTime(, "yyyyMMdd_HHmmss")
    }

    try edtMacroName.Enabled := false
    edtBufferPreview.Text := "; Grabando pulsaciones... Opera normalmente en Xstore POS.`r`n"

    keyHook := InputHook("V L0")
    keyHook.KeyOpt("{All}", "+N")
    keyHook.OnKeyDown := OnKeyDownHandler
    keyHook.OnChar := OnCharHandler
    keyHook.Start()

    UpdateStatus("🔴 GRABANDO EN DIRECTO... (Opera en Xstore)")
    btnRecord.Enabled := false
    btnPauseRec.Enabled := true
    btnPauseRec.Text := "⏸️ Pausar"
    btnSaveRec.Enabled := true
    btnCancelRec.Enabled := true
    btnPlay.Enabled := false
}

TogglePauseRecording(*) {
    global isPausedRec, lastTick, btnPauseRec, edtMacroName
    if (!isRecording)
        return

    if (isPausedRec) {
        isPausedRec := false
        lastTick := A_TickCount
        UpdateStatus("🔴 GRABANDO EN DIRECTO... (Opera en Xstore)")
        btnPauseRec.Text := "⏸️ Pausar"
        try edtMacroName.Enabled := false
    } else {
        FlushTextBuffer()
        isPausedRec := true
        lastTick := 0
        UpdateStatus("⏸️ Grabación en pausa")
        btnPauseRec.Text := "▶️ Reanudar"
        try edtMacroName.Enabled := true
    }
}

SaveRecording(*) {
    global isRecording, isPausedRec, macroBuffer, macroFolder, ddlMacros, edtMacroName, mainTabs

    if (!isRecording)
        return

    StopHook()
    FlushTextBuffer()
    isRecording := false
    isPausedRec := false
    try edtMacroName.Enabled := true

    if (macroBuffer.Length == 0) {
        UpdateStatus("⚠️ No se registraron pulsaciones de teclas")
        MsgBox("No se registraron pulsaciones de tecla durante la grabación.", "Xstore Macro Suite", "Iconi 262144")
        CancelRecording()
        return
    }

    fileName := Trim(edtMacroName.Text)
    if (fileName == "")
        fileName := "Transaccion_" . FormatTime(, "yyyyMMdd_HHmmss")

    if (!RegExMatch(fileName, "\.txt$"))
        fileName .= ".txt"

    EnsureRequiredDirectories()

    fullPath := macroFolder . "\" . fileName
    fileContent := "; Macro de Transacción para Oracle Xstore POS`n"
    fileContent .= "; Archivo: " . fileName . "`n"
    fileContent .= "; Fecha de Creación: " . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "`n`n"

    for item in macroBuffer {
        fileContent .= item . "`n"
    }

    try {
        if FileExist(fullPath)
            FileDelete(fullPath)
        FileAppend(fileContent, fullPath, "UTF-8")

        RefreshMacroList()
        try ddlMacros.Text := fileName

        ; Cambiar automáticamente a la pestaña de automatización
        try mainTabs.Value := 1

        try edtMacroName.Text := "Transaccion_" . FormatTime(, "yyyyMMdd_HHmmss")

        UpdateStatus("✅ Guardada en biblioteca: " . fileName)
        MsgBox("¡Macro guardada exitosamente en la biblioteca!`n`nArchivo: " . fullPath . "`nInstrucciones: " . macroBuffer.Length .
            "`n`nYa se encuentra seleccionada en la pestaña '🚀 Automatizar'.", "Xstore Macro Suite", "Iconi 262144")
    } catch Error as err {
        MsgBox("Error al guardar archivo: " . err.Message, "Xstore Macro Suite", "Iconx 262144")
        UpdateStatus("❌ Error al guardar archivo de macro")
    }

    ResetUI()
}

CancelRecording(*) {
    global isRecording, isPausedRec, macroBuffer, textBuffer, edtBufferPreview, edtMacroName
    if (!isRecording)
        return

    StopHook()
    isRecording := false
    isPausedRec := false
    try edtMacroName.Enabled := true
    macroBuffer := []
    textBuffer := ""
    edtBufferPreview.Text := "; Grabación cancelada."
    UpdateStatus("❌ Grabación cancelada")
    ResetUI()
}

StopHook() {
    global keyHook
    if (IsObject(keyHook)) {
        try keyHook.Stop()
        keyHook := ""
    }
}

OnKeyDownHandler(ih, vk, sc) {
    global isRecording, isPausedRec, firstKeyRecorded, lastTick, macroBuffer, specialKeys, edtBufferPreview

    if (!isRecording || isPausedRec)
        return

    keyName := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))

    if (vk == 13)
        keyName := "Enter"
    else if (vk == 8)
        keyName := "Backspace"
    else if (vk == 27)
        keyName := "Escape"
    else if (vk == 9)
        keyName := "Tab"
    else if (vk == 32)
        keyName := "Space"
    else if (vk == 38)
        keyName := "Up"
    else if (vk == 40)
        keyName := "Down"
    else if (vk == 37)
        keyName := "Left"
    else if (vk == 39)
        keyName := "Right"
    else if (vk >= 112 && vk <= 123)
        keyName := "F" . (vk - 111)

    isSpecial := specialKeys.Has(keyName)
        || (vk >= 112 && vk <= 123)
        || (vk >= 37 && vk <= 40)
        || (vk == 13 || vk == 9 || vk == 27 || vk == 8 || vk == 32 || vk == 46 || vk == 45)

    if (isSpecial) {
        currentTick := A_TickCount

        if (!firstKeyRecorded) {
            firstKeyRecorded := true
            lastTick := currentTick
            FlushTextBuffer()
        } else {
            delta := (lastTick > 0) ? (currentTick - lastTick) : 0
            FlushTextBuffer()
            if (delta >= 25) {
                macroBuffer.Push("Sleep, " . delta)
                AppendPreviewLine("Sleep, " . delta)
            }
            lastTick := currentTick
        }

        instruction := "Send, {" . keyName . "}"
        macroBuffer.Push(instruction)
        AppendPreviewLine(instruction)
    }
}

OnCharHandler(ih, char) {
    global isRecording, isPausedRec, firstKeyRecorded, lastTick, textBuffer, macroBuffer

    if (!isRecording || isPausedRec)
        return

    if (Ord(char) < 32)
        return

    currentTick := A_TickCount

    if (!firstKeyRecorded) {
        firstKeyRecorded := true
        lastTick := currentTick
    } else {
        delta := (lastTick > 0) ? (currentTick - lastTick) : 0
        if (delta >= 1500 && textBuffer != "") {
            FlushTextBuffer()
            macroBuffer.Push("Sleep, " . delta)
            AppendPreviewLine("Sleep, " . delta)
        }
        lastTick := currentTick
    }

    textBuffer .= char
}

FlushTextBuffer() {
    global textBuffer, macroBuffer
    if (Trim(textBuffer) != "") {
        cleanText := StrReplace(textBuffer, "{", "{{}")
        cleanText := StrReplace(cleanText, "}", "{}}")
        if (Trim(cleanText) != "") {
            instruction := "Send, " . cleanText
            macroBuffer.Push(instruction)
            AppendPreviewLine(instruction)
        }
    }
    textBuffer := ""
}

AppendPreviewLine(lineText) {
    global edtBufferPreview
    try {
        currentText := edtBufferPreview.Text
        if (StrLen(currentText) > 2000)
            edtBufferPreview.Text := SubStr(currentText, -1000) . lineText . "`r`n"
        else
            edtBufferPreview.Text .= lineText . "`r`n"
    }
}

; ==============================================================================
; UTILIDADES UI Y REINICIO
; ==============================================================================

UpdateStatus(statusText) {
    global txtStatus
    txtStatus.Text := statusText
}

ResetUI() {
    global isRecording, isPlaying, btnRecord, btnPauseRec, btnSaveRec, btnCancelRec
    global btnPlay, btnPausePlay, edtMacroName

    btnRecord.Enabled := true
    btnPauseRec.Enabled := false
    btnPauseRec.Text := "⏸️ Pausar"
    btnSaveRec.Enabled := false
    btnCancelRec.Enabled := false
    try edtMacroName.Enabled := true

    btnPlay.Enabled := true
    btnPausePlay.Enabled := false
    btnPausePlay.Text := "⏸️ PAUSAR`n(Ctrl+P)"

    RefreshMacroList()
}
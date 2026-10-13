; ==============================================================================
; PROJECT: QA POS Automation Macro
; VERSION: 2.5.0 (Windows Vista Aero Glass Edition)
; LANGUAGE: AutoHotkey v2.0+
; TARGET: Windows 10/11 / Windows POSReady / Windows Server (Terminales POS)
; PURPOSE: Automatización de alta precisión para transacciones en cajas POS.
;          Incluye motor de ejecución, grabador no intrusivo, editor visual
;          de pasos para reordenar y sustituir SKUs, y gestor de actualizaciones.
; ==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

; ==============================================================================
; VARIABLES DE ESTADO GLOBAL
; ==============================================================================
global appVersion := "2.5.0"
global latestReleaseUrl := "https://github.com/EfrainSN/QA-POS-Automation-Macro/releases"
global latestZipDownloadUrl := ""

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
global targetWinTitle := "POS"
global speedMultiplier := 1.0

; Estado del Editor de Pasos
global editorSteps := []
global currentEditingMacro := ""

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
                "QA POS Automation", "Icon!")
        }
    }

    if (!DirExist(reportsFolder)) {
        try {
            DirCreate(reportsFolder)
            createdAny := true
        } catch Error as err {
            MsgBox("Aviso: No se pudo crear la carpeta de reportes:`n" . reportsFolder . "`n`nDetalle: " . err.Message,
                "QA POS Automation", "Icon!")
        }
    }

    if (FileExist(A_ScriptDir . "\Macro_POS_Local.txt") && !FileExist(macroFolder . "\Macro_POS_Local.txt")) {
        try FileCopy(A_ScriptDir . "\Macro_POS_Local.txt", macroFolder . "\Macro_POS_Local.txt", 0)
    }

    return createdAny
}

EnsureRequiredDirectories()

; ==============================================================================
; INTERFAZ DE USUARIO: WINDOWS VISTA AERO GLASS EDITION
; ==============================================================================
mainGui := Gui("+AlwaysOnTop -MaximizeBox", "QA POS Automation Macro v2.5")
mainGui.BackColor := "D9EBF7" ; Tono azul hielo cristalino tipo Windows Vista Aero
mainGui.SetFont("s9", "Segoe UI")

; --- ENCABEZADO AERO GLASS HEADER ---
hdrBg := mainGui.Add("Text", "x12 y10 w426 h48 +Border Background123859", "")
txtBrand := mainGui.Add("Text", "x24 y14 w280 h20 BackgroundTrans c5AD1FF", "QA POS AUTOMATION MACRO • AERO EDITION")
txtBrand.SetFont("s10 Bold", "Segoe UI")
txtStatus := mainGui.Add("Text", "x24 y34 w280 h18 BackgroundTrans cE2F3FF", "Listo para automatizar transacciones en caja POS")
btnHeaderUpdate := mainGui.Add("Button", "x312 y16 w116 h36", "Actualizaciones")

; --- PESTAÑAS PRINCIPALES ---
mainTabs := mainGui.Add("Tab3", "x12 y65 w426 h482", ["Automatizar", "Grabar Macro", "Editor de Pasos", "Biblioteca", "Actualizaciones"])

; ------------------------------------------------------------------------------
; PESTAÑA 1: AUTOMATIZAR TRANSACCIONES
; ------------------------------------------------------------------------------
mainTabs.UseTab(1)

; 1. Vinculación con Ventana POS
mainGui.Add("GroupBox", "x24 y96 w402 h68", "1. Ventana de la Caja POS")
mainGui.Add("Text", "x36 y119 w85 h20 c153858", "Ventana POS:")
edtTargetWin := mainGui.Add("Edit", "x125 y116 w175 h24 BackgroundFFFFFF", targetWinTitle)
btnDetectWin := mainGui.Add("Button", "x306 y115 w106 h26", "Vincular")

; 2. Selección de Macro / Transacción
mainGui.Add("GroupBox", "x24 y170 w402 h76", "2. Transaccion a Ejecutar")
mainGui.Add("Text", "x36 y193 w55 h20 c153858", "Macro:")
ddlMacros := mainGui.Add("DropDownList", "x95 y190 w175 Choose1", ["(Sin macros)"])
btnRefresh := mainGui.Add("Button", "x276 y189 w70 h26", "Recargar")
btnOpenFolderMacro := mainGui.Add("Button", "x350 y189 w64 h26", "Carpeta")
mainGui.Add("Text", "x36 y220 w378 h18 c416A8C", "Selecciona la secuencia registrada para ejecutar en la terminal POS.")

; 3. Modo de Ejecución de Transacciones
mainGui.Add("GroupBox", "x24 y252 w402 h118", "3. Modo de Automatizacion")
mainGui.Add("Text", "x36 y274 w95 h20 c153858", "Ejecutar:")
radModeSingle := mainGui.Add("Radio", "x135 y273 w110 h20 Checked", "1 Transaccion")
radModeBatch := mainGui.Add("Radio", "x250 y273 w65 h20", "Lote:")
edtReps := mainGui.Add("Edit", "x318 y271 w50 h22 Number Center BackgroundFFFFFF Disabled", "5")
mainGui.Add("Text", "x372 y274 w35 h20 c416A8C", "veces")

chkInfinite := mainGui.Add("CheckBox", "x135 y298 w180 h20", "Modo Continuo sin fin (inf)")

mainGui.Add("Text", "x36 y330 w95 h20 c153858", "Velocidad:")
ddlSpeed := mainGui.Add("DropDownList", "x135 y327 w130 Choose2", [
    "0.8x (Seguro / Pausado)",
    "1.0x (Normal Recomendado)",
    "1.2x (Rapido POS)",
    "1.5x (Turbo Agil)"
])
mainGui.Add("Text", "x274 y330 w130 h20 c416A8C", "Pausa: 1.0s / txn")
edtLoopDelay := mainGui.Add("Edit", "x0 y0 w0 h0 Hidden", "1000")

; 4. Monitor de Progreso Aero Glass
mainGui.Add("GroupBox", "x24 y376 w402 h84", "Estado de la Automatizacion")
progBar := mainGui.Add("Progress", "x36 y396 w378 h16 Range0-100 c00A2ED BackgroundC8E3F5", 0)
txtProgress := mainGui.Add("Text", "x36 y416 w378 h18 Center c153858", "Listo para iniciar. Esperando orden")
txtProgress.SetFont("Bold")

txtMetricsA := mainGui.Add("Text", "x36 y436 w180 h18 c153858", "Tiempo: 00:00:00")
txtMetricsC := mainGui.Add("Text", "x224 y436 w188 h18 Right c0E7D42", "Completadas: 0")

; Botonera Principal de Acción
btnPlay := mainGui.Add("Button", "x24 y468 w144 h44 Default", "EJECUTAR`nTRANSACCION")
btnPausePlay := mainGui.Add("Button", "x174 y468 w124 h44 Disabled", "PAUSAR`n(Ctrl+P)")
btnStop := mainGui.Add("Button", "x304 y468 w122 h44", "DETENER`n(Ctrl+M)")

; ------------------------------------------------------------------------------
; PESTAÑA 2: GRABAR NUEVA MACRO
; ------------------------------------------------------------------------------
mainTabs.UseTab(2)

mainGui.Add("GroupBox", "x24 y96 w402 h170", "Nueva Secuencia de Transaccion")
mainGui.Add("Text", "x36 y118 w378 h28 c416A8C",
    "Asigna un nombre a tu macro, presiona Grabar y opera en la caja POS. Las pulsaciones y pausas quedaran registradas."
)
mainGui.Add("Text", "x36 y153 w110 h20 c153858", "Nombre de Macro:")
edtMacroName := mainGui.Add("Edit", "x150 y150 w252 h24 BackgroundFFFFFF", "Transaccion_" . FormatTime(, "yyyyMMdd_HHmmss"))

btnRecord := mainGui.Add("Button", "x36 y182 w175 h38", "Iniciar Grabacion")
btnPauseRec := mainGui.Add("Button", "x227 y182 w175 h38 Disabled", "Pausar")

btnSaveRec := mainGui.Add("Button", "x36 y224 w175 h36 Disabled", "Guardar en Biblioteca")
btnCancelRec := mainGui.Add("Button", "x227 y224 w175 h36 Disabled", "Cancelar")

mainGui.Add("GroupBox", "x24 y274 w402 h238", "Visor de Secuencia Capturada (En Vivo)")
edtBufferPreview := mainGui.Add("Edit", "x36 y297 w378 h205 ReadOnly BackgroundF8FBFE",
    "; Las pulsaciones y pausas de la terminal POS apareceran aqui...`r`n")

; ------------------------------------------------------------------------------
; PESTAÑA 3: EDITOR DE PASOS (MODIFICAR, REORDENAR Y SUSTITUIR SKUS)
; ------------------------------------------------------------------------------
mainTabs.UseTab(3)

; Selector de Macro a Cargar
mainGui.Add("Text", "x24 y98 w95 h20 c153858", "Macro a Editar:")
ddlEditMacros := mainGui.Add("DropDownList", "x122 y94 w185 Choose1", ["(Sin macros)"])
btnLoadMacro := mainGui.Add("Button", "x314 y93 w112 h26", "Cargar Macro")

; Lista Interactiva de Pasos
lvSteps := mainGui.Add("ListView", "x24 y125 w402 h165 Grid -Multi BackgroundFFFFFF", ["#", "Tipo", "Instruccion / Valor"])
lvSteps.ModifyCol(1, 40)
lvSteps.ModifyCol(2, 105)
lvSteps.ModifyCol(3, 235)

; Barra de Acciones de Reordenamiento
btnStepUp := mainGui.Add("Button", "x24 y295 w94 h27", "▲ Subir")
btnStepDown := mainGui.Add("Button", "x126 y295 w94 h27", "▼ Bajar")
btnStepDup := mainGui.Add("Button", "x228 y295 w94 h27", "Duplicar")
btnStepDel := mainGui.Add("Button", "x330 y295 w96 h27", "Eliminar")

; Tarjeta de Modificación Inmediata de SKU / Valor
mainGui.Add("GroupBox", "x24 y328 w402 h112", "Modificar Paso Seleccionado")
mainGui.Add("Text", "x36 y350 w40 h20 c153858", "Tipo:")
ddlStepType := mainGui.Add("DropDownList", "x78 y347 w125 Choose1", ["Texto / SKU", "Tecla Especial", "Pausa (ms)"])
mainGui.Add("Text", "x212 y350 w40 h20 c153858", "Valor:")
edtStepVal := mainGui.Add("Edit", "x254 y347 w160 h23 BackgroundFFFFFF", "")

btnApplyStep := mainGui.Add("Button", "x36 y378 w175 h28", "Actualizar Paso")
btnInsertStep := mainGui.Add("Button", "x224 y378 w188 h28", "Insertar Nuevo Paso")
mainGui.Add("Text", "x36 y412 w378 h18 c416A8C", "Selecciona un paso de la lista para cambiar su SKU, tecla o pausa.")

; Botonera de Guardado del Editor
btnSaveMacroFile := mainGui.Add("Button", "x24 y448 w196 h42", "GUARDAR CAMBIOS`n(Sobrescribir)")
btnSaveAsMacroFile := mainGui.Add("Button", "x230 y448 w196 h42", "GUARDAR COMO...`n(Nueva Variante)")

; ------------------------------------------------------------------------------
; PESTAÑA 4: BIBLIOTECA Y REGISTRO
; ------------------------------------------------------------------------------
mainTabs.UseTab(4)

mainGui.Add("GroupBox", "x24 y96 w402 h165", "Resumen de la Ultima Automatizacion")
txtRepInfo1 := mainGui.Add("Text", "x36 y120 w378 h20 c153858", "Registro CSV: (Ninguno)")
txtRepInfo2 := mainGui.Add("Text", "x36 y145 w378 h20 c153858", "Total de Transacciones: 0")
txtRepInfo3 := mainGui.Add("Text", "x36 y170 w378 h20 c153858", "Duracion Total: 0s")
txtRepInfo4 := mainGui.Add("Text", "x36 y195 w378 h20 c153858", "Promedio por Transaccion: 0.0s")
txtRepInfo5 := mainGui.Add("Text", "x36 y220 w378 h20 c0E7D42", "Tasa de Exito: 100%")

mainGui.Add("GroupBox", "x24 y270 w402 h172", "Gestion de Macros y Auditoria")
btnOpenInEditor := mainGui.Add("Button", "x36 y295 w175 h40", "Editar en`nEditor de Pasos")
btnOpenNotepad := mainGui.Add("Button", "x227 y295 w175 h40", "Abrir en`nBloc de Notas")

btnOpenMacros := mainGui.Add("Button", "x36 y345 w175 h40", "Carpeta de`nMacros (.txt)")
btnViewLastCSV := mainGui.Add("Button", "x227 y345 w175 h40", "Ver Ultimo`nRegistro CSV")

btnOpenReports := mainGui.Add("Button", "x36 y395 w175 h34", "Reportes CSV")
btnCheckUpdatesLib := mainGui.Add("Button", "x227 y395 w175 h34", "Buscar Actualizaciones")

; ------------------------------------------------------------------------------
; PESTAÑA 5: ACTUALIZACIONES Y RELEASES
; ------------------------------------------------------------------------------
mainTabs.UseTab(5)

mainGui.Add("GroupBox", "x24 y96 w402 h148", "Estado de Actualizaciones (GitHub Releases)")
mainGui.Add("Text", "x36 y120 w150 h20 c153858", "Version Local Instalada:")
txtLocalVer := mainGui.Add("Text", "x190 y120 w220 h20 c153858", "v" . appVersion . " (Aero Edition)")
txtLocalVer.SetFont("Bold")

mainGui.Add("Text", "x36 y142 w150 h20 c153858", "Ultima Version en GitHub:")
txtRemoteVer := mainGui.Add("Text", "x190 y142 w220 h20 c0E7D42", "(No comprobado)")
txtRemoteVer.SetFont("Bold")

mainGui.Add("Text", "x36 y164 w60 h20 c153858", "Estado:")
txtUpdateState := mainGui.Add("Text", "x100 y164 w310 h20 c153858", "Presiona 'Buscar Actualizaciones' para verificar.")

btnCheckUpdates := mainGui.Add("Button", "x36 y192 w180 h38 Default", "Buscar Actualizaciones")
btnOpenReleases := mainGui.Add("Button", "x224 y192 w188 h38", "Abrir GitHub Releases")

mainGui.Add("GroupBox", "x24 y252 w402 h238", "Registro de Cambios y Novedades (Changelog)")
edtReleaseNotes := mainGui.Add("Edit", "x36 y274 w378 h168 ReadOnly BackgroundF8FBFE",
    "Presiona 'Buscar Actualizaciones' para consultar el registro de versiones y mejoras disponibles en el repositorio.")

btnDownloadZip := mainGui.Add("Button", "x36 y448 w378 h34 Disabled", "Descargar Paquete ZIP Portable de la Ultima Version")

mainTabs.UseTab()

; --- PIE DE VENTANA (FOOTER AERO GLASS) ---
mainGui.SetFont("s8 c406888", "Segoe UI")
mainGui.Add("Text", "x12 y552 w426 Center",
    "QA POS Automation Macro v2.5 • Windows Vista Aero Edition • Ctrl+P: Pausar • Ctrl+M: Detener")
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

; Eventos de Pestañas y Editor de Pasos
mainTabs.OnEvent("Change", OnTabChanged)
btnLoadMacro.OnEvent("Click", LoadMacroIntoEditor)
ddlEditMacros.OnEvent("Change", LoadMacroIntoEditor)
lvSteps.OnEvent("ItemSelect", (lv, row, selected) => (selected ? OnStepSelected(lv, row) : 0))
lvSteps.OnEvent("DoubleClick", (lv, row) => (row > 0 ? edtStepVal.Focus() : 0))

btnStepUp.OnEvent("Click", MoveStepUp)
btnStepDown.OnEvent("Click", MoveStepDown)
btnStepDup.OnEvent("Click", DuplicateStep)
btnStepDel.OnEvent("Click", DeleteStep)

btnApplyStep.OnEvent("Click", ApplyStepEdit)
btnInsertStep.OnEvent("Click", InsertStep)
btnSaveMacroFile.OnEvent("Click", SaveMacroChanges)
btnSaveAsMacroFile.OnEvent("Click", SaveAsMacro)

; Eventos de Biblioteca
btnOpenInEditor.OnEvent("Click", OpenSelectedInEditorTab)
btnOpenNotepad.OnEvent("Click", EditSelectedMacro)
btnOpenMacros.OnEvent("Click", (*) => (EnsureRequiredDirectories(), Run("explore `"" . macroFolder . "`"")))
btnOpenReports.OnEvent("Click", (*) => (EnsureRequiredDirectories(), Run("explore `"" . reportsFolder . "`"")))
btnCheckUpdatesLib.OnEvent("Click", (*) => (mainTabs.Value := 5, CheckForUpdates(true)))
btnViewLastCSV.OnEvent("Click", OpenLastCSVReport)

; Eventos de Actualizaciones
btnHeaderUpdate.OnEvent("Click", (*) => (mainTabs.Value := 5, CheckForUpdates(false)))
btnCheckUpdates.OnEvent("Click", (*) => CheckForUpdates(true))
btnOpenReleases.OnEvent("Click", (*) => Run(latestReleaseUrl))
btnDownloadZip.OnEvent("Click", (*) => (latestZipDownloadUrl != "" ? Run(latestZipDownloadUrl) : Run(latestReleaseUrl)))

mainGui.OnEvent("Close", (*) => ExitApp())

; Cargar macros y mostrar interfaz al arrancar
RefreshMacroList()
mainGui.Show("w450 h580")

; Comprobacion no intrusiva de actualizaciones en segundo plano
SetTimer(() => CheckForUpdates(false), -1500)

; ==============================================================================
; DETECCIÓN Y FOCO DE VENTANA POS
; ==============================================================================

DetectTargetWindow(*) {
    global targetWinTitle, edtTargetWin
    MsgBox(
        "Haz clic en 'Aceptar' y luego activa (haz clic en) la ventana de la terminal POS dentro de los proximos 4 segundos.",
        "Vinculador de Ventana POS", "Iconi")
    Sleep(4000)
    activeTitle := WinGetTitle("A")
    if (activeTitle != "" && activeTitle != mainGui.Title) {
        targetWinTitle := activeTitle
        edtTargetWin.Text := activeTitle
        UpdateStatus("Ventana POS enlazada: " . SubStr(activeTitle, 1, 32))
    } else {
        MsgBox("No se detecto un cambio de ventana o seleccionaste esta misma aplicacion.", "QA POS Automation", "Icon!")
    }
}

EnsureTargetWindowActive() {
    global targetWinTitle, edtTargetWin
    currentTitle := Trim(edtTargetWin.Text)
    if (currentTitle == "")
        currentTitle := "POS"

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
    global ddlMacros, ddlEditMacros, btnPlay, macroFolder

    EnsureRequiredDirectories()

    macroFiles := []
    loop files, macroFolder . "\*.txt" {
        macroFiles.Push(A_LoopFileName)
    }

    ddlMacros.Delete()
    ddlEditMacros.Delete()

    if (macroFiles.Length > 0) {
        ddlMacros.Add(macroFiles)
        ddlMacros.Choose(1)

        ddlEditMacros.Add(macroFiles)
        ddlEditMacros.Choose(1)

        if (!isRecording && !isPlaying)
            btnPlay.Enabled := true
    } else {
        ddlMacros.Add(["(Sin macros guardadas)"])
        ddlMacros.Choose(1)

        ddlEditMacros.Add(["(Sin macros guardadas)"])
        ddlEditMacros.Choose(1)

        btnPlay.Enabled := false
    }
}

UpdateSpeedMultiplier(*) {
    global ddlSpeed, speedMultiplier
    idx := ddlSpeed.Value
    switch idx {
        case 1: speedMultiplier := 1.25  ; 0.8x seguro / pausado
        case 2: speedMultiplier := 1.0   ; 1.0x normal recomendado
        case 3: speedMultiplier := 0.83  ; 1.2x rapido POS
        case 4: speedMultiplier := 0.67  ; 1.5x turbo agil
        default: speedMultiplier := 1.0
    }
}

EditSelectedMacro(*) {
    global ddlMacros, macroFolder
    EnsureRequiredDirectories()
    selectedMacro := ddlMacros.Text
    if (selectedMacro == "" || selectedMacro == "(Sin macros guardadas)") {
        MsgBox("Selecciona primero una macro valida para editar.", "QA POS Automation", "Icon!")
        return
    }
    fullPath := macroFolder . "\" . selectedMacro
    if FileExist(fullPath) {
        Run("notepad.exe `"" . fullPath . "`"")
    } else {
        MsgBox("El archivo '" . fullPath . "' no existe.", "QA POS Automation", "Iconx")
    }
}

OpenSelectedInEditorTab(*) {
    global mainTabs, ddlMacros, ddlEditMacros
    selected := ddlMacros.Text
    if (selected != "" && selected != "(Sin macros guardadas)") {
        try ddlEditMacros.Text := selected
        LoadMacroIntoEditor()
    }
    mainTabs.Value := 3
}

; ==============================================================================
; LÓGICA DEL EDITOR DE PASOS
; ==============================================================================

OnTabChanged(ctrl, *) {
    global editorSteps, ddlEditMacros, txtRemoteVer
    if (ctrl.Value == 3 && editorSteps.Length == 0 && ddlEditMacros.Text != "" && ddlEditMacros.Text != "(Sin macros guardadas)") {
        LoadMacroIntoEditor()
    } else if (ctrl.Value == 5 && txtRemoteVer.Text == "(No comprobado)") {
        CheckForUpdates(false)
    }
}

LoadMacroIntoEditor(*) {
    global ddlEditMacros, lvSteps, editorSteps, macroFolder, currentEditingMacro, ddlStepType, edtStepVal
    selected := ddlEditMacros.Text
    if (selected == "" || selected == "(Sin macros guardadas)" || selected == "(Sin macros)") {
        return
    }

    fullPath := macroFolder . "\" . selected
    if (!FileExist(fullPath)) {
        MsgBox("El archivo '" . fullPath . "' no existe.", "Editor de Pasos", "Iconx")
        return
    }

    currentEditingMacro := selected
    editorSteps := []
    lvSteps.Delete()

    fileLines := FileRead(fullPath, "UTF-8")
    idx := 0
    loop parse, fileLines, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line == "" || SubStr(line, 1, 1) == ";")
            continue

        idx++
        stepType := ""
        stepVal := ""
        if (SubStr(line, 1, 6) == "Sleep,") {
            stepType := "Pausa (ms)"
            stepVal := Trim(SubStr(line, 7))
        } else if (SubStr(line, 1, 5) == "Send,") {
            cmd := Trim(SubStr(line, 6))
            if (RegExMatch(cmd, "^\{.+\}$")) {
                stepType := "Tecla Especial"
                stepVal := cmd
            } else {
                stepType := "Texto / SKU"
                stepVal := cmd
            }
        } else {
            stepType := "Comando"
            stepVal := line
        }

        editorSteps.Push({type: stepType, val: stepVal})
        lvSteps.Add("", Format("{:02}", idx), stepType, stepVal)
    }

    if (editorSteps.Length > 0) {
        lvSteps.Modify(1, "Select Focus")
        OnStepSelected(lvSteps, 1)
        UpdateStatus("Macro cargada en editor: " . selected . " (" . editorSteps.Length . " pasos)")
    } else {
        UpdateStatus("La macro seleccionada esta vacia")
    }
}

OnStepSelected(lv, rowNumber) {
    global editorSteps, ddlStepType, edtStepVal
    if (rowNumber <= 0 || rowNumber > editorSteps.Length)
        return
    item := editorSteps[rowNumber]
    switch item.type {
        case "Texto / SKU": ddlStepType.Choose(1)
        case "Tecla Especial": ddlStepType.Choose(2)
        case "Pausa (ms)": ddlStepType.Choose(3)
        default: ddlStepType.Choose(1)
    }
    edtStepVal.Text := item.val
}

ApplyStepEdit(*) {
    global lvSteps, editorSteps, ddlStepType, edtStepVal
    row := lvSteps.GetNext()
    if (row == 0) {
        MsgBox("Selecciona primero un paso de la lista para actualizar.", "Editor de Pasos", "Icon!")
        return
    }

    newVal := Trim(edtStepVal.Text)
    if (newVal == "") {
        MsgBox("El valor no puede estar vacio.", "Editor de Pasos", "Icon!")
        return
    }

    newType := ddlStepType.Text
    if (newType == "Tecla Especial" && !RegExMatch(newVal, "^\{.+\}$")) {
        newVal := "{" . newVal . "}"
    } else if (newType == "Pausa (ms)") {
        newVal := RegExReplace(newVal, "[^\d]", "")
        if (newVal == "")
            newVal := "100"
    }

    editorSteps[row].type := newType
    editorSteps[row].val := newVal

    lvSteps.Modify(row, "", Format("{:02}", row), newType, newVal)
    UpdateStatus("Paso " . row . " actualizado: " . newVal)
}

MoveStepUp(*) {
    global lvSteps, editorSteps
    row := lvSteps.GetNext()
    if (row <= 1)
        return

    temp := editorSteps[row]
    editorSteps[row] := editorSteps[row - 1]
    editorSteps[row - 1] := temp

    RefreshStepListView(row - 1)
}

MoveStepDown(*) {
    global lvSteps, editorSteps
    row := lvSteps.GetNext()
    if (row == 0 || row >= editorSteps.Length)
        return

    temp := editorSteps[row]
    editorSteps[row] := editorSteps[row + 1]
    editorSteps[row + 1] := temp

    RefreshStepListView(row + 1)
}

DeleteStep(*) {
    global lvSteps, editorSteps
    row := lvSteps.GetNext()
    if (row == 0) {
        MsgBox("Selecciona un paso para eliminar.", "Editor de Pasos", "Icon!")
        return
    }

    editorSteps.RemoveAt(row)
    newRow := (row > editorSteps.Length) ? editorSteps.Length : row
    RefreshStepListView(newRow)
    UpdateStatus("Paso eliminado")
}

DuplicateStep(*) {
    global lvSteps, editorSteps
    row := lvSteps.GetNext()
    if (row == 0) {
        MsgBox("Selecciona un paso para duplicar.", "Editor de Pasos", "Icon!")
        return
    }

    copied := {type: editorSteps[row].type, val: editorSteps[row].val}
    editorSteps.InsertAt(row + 1, copied)
    RefreshStepListView(row + 1)
    UpdateStatus("Paso duplicado")
}

InsertStep(*) {
    global lvSteps, editorSteps, ddlStepType, edtStepVal
    val := Trim(edtStepVal.Text)
    if (val == "") {
        MsgBox("Ingresa un valor para el nuevo paso.", "Editor de Pasos", "Icon!")
        return
    }

    newType := ddlStepType.Text
    if (newType == "Tecla Especial" && !RegExMatch(val, "^\{.+\}$")) {
        val := "{" . val . "}"
    } else if (newType == "Pausa (ms)") {
        val := RegExReplace(val, "[^\d]", "")
        if (val == "")
            val := "100"
    }

    newStep := {type: newType, val: val}

    row := lvSteps.GetNext()
    if (row == 0) {
        editorSteps.Push(newStep)
        insertIdx := editorSteps.Length
    } else {
        editorSteps.InsertAt(row + 1, newStep)
        insertIdx := row + 1
    }

    RefreshStepListView(insertIdx)
    UpdateStatus("Nuevo paso insertado en la posicion " . insertIdx)
}

RefreshStepListView(selectIndex := 1) {
    global lvSteps, editorSteps
    lvSteps.Delete()
    for idx, step in editorSteps {
        lvSteps.Add("", Format("{:02}", idx), step.type, step.val)
    }
    if (selectIndex > 0 && selectIndex <= editorSteps.Length) {
        lvSteps.Modify(selectIndex, "Select Focus")
        OnStepSelected(lvSteps, selectIndex)
    }
}

SaveMacroChanges(*) {
    global editorSteps, currentEditingMacro, macroFolder
    if (currentEditingMacro == "") {
        MsgBox("No hay ninguna macro cargada en el editor.", "Editor de Pasos", "Icon!")
        return
    }
    if (editorSteps.Length == 0) {
        MsgBox("La macro no contiene ningun paso.", "Editor de Pasos", "Icon!")
        return
    }

    fullPath := macroFolder . "\" . currentEditingMacro
    fileContent := GenerateMacroFileContent(currentEditingMacro, editorSteps)

    try {
        if FileExist(fullPath)
            FileDelete(fullPath)
        FileAppend(fileContent, fullPath, "UTF-8")
        RefreshMacroList()
        UpdateStatus("Macro guardada con exito: " . currentEditingMacro)
        MsgBox("¡Cambios guardados exitosamente!`n`nArchivo: " . fullPath . "`nPasos: " . editorSteps.Length,
            "Editor de Pasos", "Iconi")
    } catch Error as err {
        MsgBox("Error al guardar la macro: " . err.Message, "Editor de Pasos", "Iconx")
    }
}

SaveAsMacro(*) {
    global editorSteps, currentEditingMacro, macroFolder, ddlMacros
    if (editorSteps.Length == 0) {
        MsgBox("No hay pasos para guardar.", "Editor de Pasos", "Icon!")
        return
    }

    suggested := RegExReplace(currentEditingMacro, "\.txt$", "") . "_v2.txt"
    if (suggested == "_v2.txt" || suggested == "")
        suggested := "Transaccion_Editada_" . FormatTime(, "yyyyMMdd_HHmmss") . ".txt"

    ib := InputBox("Ingresa el nombre para la nueva macro:", "Guardar Macro Como", , suggested)
    if (ib.Result != "OK" || Trim(ib.Value) == "")
        return

    newName := Trim(ib.Value)
    if (!RegExMatch(newName, "\.txt$"))
        newName .= ".txt"

    fullPath := macroFolder . "\" . newName
    fileContent := GenerateMacroFileContent(newName, editorSteps)

    try {
        if FileExist(fullPath)
            FileDelete(fullPath)
        FileAppend(fileContent, fullPath, "UTF-8")
        currentEditingMacro := newName
        RefreshMacroList()
        try ddlMacros.Text := newName
        UpdateStatus("Nueva macro guardada: " . newName)
        MsgBox("¡Nueva macro creada exitosamente!`n`nArchivo: " . fullPath . "`nPasos: " . editorSteps.Length,
            "Editor de Pasos", "Iconi")
    } catch Error as err {
        MsgBox("Error al guardar nueva macro: " . err.Message, "Editor de Pasos", "Iconx")
    }
}

GenerateMacroFileContent(name, steps) {
    out := "; Macro de Transaccion para Terminal POS`n"
    out .= "; Archivo: " . name . "`n"
    out .= "; Fecha de Edicion: " . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "`n`n"
    for step in steps {
        if (step.type == "Pausa (ms)")
            out .= "Sleep, " . step.val . "`n"
        else if (step.type == "Tecla Especial") {
            k := step.val
            if (!RegExMatch(k, "^\{.+\}$"))
                k := "{" . k . "}"
            out .= "Send, " . k . "`n"
        } else
            out .= "Send, " . step.val . "`n"
    }
    return out
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
        MsgBox("Debes guardar o cancelar la grabacion activa antes de iniciar la automatizacion.", "QA POS Automation", "Icon!")
        return
    }

    selectedMacro := ddlMacros.Text
    if (selectedMacro == "" || selectedMacro == "(Sin macros guardadas)") {
        MsgBox("No hay ninguna macro seleccionada.`nGraba una macro primero en la pestaña 'Grabar Macro'.",
            "QA POS Automation", "Iconx")
        return
    }

    fullMacroPath := macroFolder . "\" . selectedMacro
    if (!FileExist(fullMacroPath)) {
        MsgBox("El archivo de macro '" . fullMacroPath . "' no existe.", "QA POS Automation", "Iconx")
        RefreshMacroList()
        return
    }

    if (chkInfinite.Value == 1) {
        totalReps := 999999
    } else if (radModeBatch.Value == 1) {
        numInput := Integer(edtReps.Text)
        totalReps := (numInput > 0) ? numInput : 1
    } else {
        totalReps := 1
    }

    loopDelay := Integer(edtLoopDelay.Text >= 0 ? edtLoopDelay.Text : 1000)
    keyDelay := 25

    autoTotalCycles := totalReps
    autoCurrentCycle := 0
    autoSuccessCount := 0
    autoFailCount := 0
    autoStartTime := A_TickCount
    isPlaying := true
    isPausedPlay := false
    stopPlayback := false

    csvName := "Registro_Transacciones_" . FormatTime(, "yyyyMMdd_HHmmss") . "_" . RegExReplace(selectedMacro, "\.txt$", "") . ".csv"
    autoCurrentCSV := reportsFolder . "\" . csvName
    csvHeader := "Transaccion,Fecha_Inicio,Fecha_Fin,Duracion_Seg,Duracion_Ms,Estado,Macro`n"
    FileAppend(csvHeader, autoCurrentCSV, "UTF-8")

    btnPlay.Enabled := false
    btnPausePlay.Enabled := true
    btnPausePlay.Text := "PAUSAR`n(Ctrl+P)"
    btnRecord.Enabled := false
    progBar.Value := 0

    UpdateStatus("Conectando con terminal POS...")
    if (!EnsureTargetWindowActive()) {
        ans := MsgBox("No se encontro la ventana objetivo ('" . edtTargetWin.Text . "').`n¿Deseas continuar de todas formas?",
            "Aviso de Foco POS", "YesNo Icon?")
        if (ans != "Yes") {
            isPlaying := false
            ResetUI()
            UpdateStatus("Cancelado: ventana POS no detectada")
            return
        }
    }

    if (totalReps == 1)
        UpdateStatus("Ejecutando 1 Transaccion con '" . selectedMacro . "'")
    else if (chkInfinite.Value == 1)
        UpdateStatus("Automatizando transacciones en modo continuo")
    else
        UpdateStatus("Automatizando lote de " . totalReps . " transacciones...")

    SetTimer(UpdateLiveMetricsHUD, 400)

    fileLines := FileRead(fullMacroPath, "UTF-8")

    loop totalReps {
        if (stopPlayback)
            break

        autoCurrentCycle := A_Index
        cycleStartTick := A_TickCount
        cycleStartTimeStr := FormatTime(, "yyyy-MM-dd HH:mm:ss")

        while (isPausedPlay && !stopPlayback) {
            Sleep(100)
        }

        if (stopPlayback)
            break

        EnsureTargetWindowActive()

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

        if (!stopPlayback && autoCurrentCycle < totalReps) {
            InterruptibleSleep(loopDelay)
        }
    }

    SetTimer(UpdateLiveMetricsHUD, 0)
    isPlaying := false
    isPausedPlay := false

    UpdateLiveMetricsHUD()
    UpdateReportsTabSummary()

    if (stopPlayback) {
        UpdateStatus("Automatizacion detenida por el usuario")
        MsgBox("Ejecucion detenida en la transaccion " . autoCurrentCycle . " de " . totalReps . ".`n`nRegistro guardado en:`n" . autoCurrentCSV,
            "QA POS Automation", "Icon!")
    } else {
        UpdateStatus("Transaccion finalizada con exito")
        if (totalReps == 1) {
            MsgBox("Transaccion completada exitosamente en la terminal POS.`n`nMacro: " . selectedMacro . "`nDuracion: " . cycleDurationSec . "s",
                "QA POS Automation", "Iconi")
        } else {
            MsgBox("Automatizacion completada exitosamente.`n`nTotal de transacciones: " . autoSuccessCount . "`nMacro: " . selectedMacro,
                "QA POS Automation", "Iconi")
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
        btnPausePlay.Text := "REANUDAR`n(Ctrl+P)"
        UpdateStatus("Transaccion pausada. Presiona Ctrl+P para reanudar")
    } else {
        btnPausePlay.Text := "PAUSAR`n(Ctrl+P)"
        UpdateStatus("Reanudando transaccion en POS...")
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
        UpdateStatus("Deteniendo ejecucion de transacciones...")
    } else if (isRecording) {
        CancelRecording()
    } else {
        UpdateStatus("Listo para automatizar transacciones en terminal POS")
    }
}

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
        txtProgress.Text := "Transaccion " . autoCurrentCycle . " (Modo Continuo)"
    } else {
        pct := (autoTotalCycles > 0) ? Integer((autoCurrentCycle / autoTotalCycles) * 100) : 0
        progBar.Value := pct
        txtProgress.Text := "Transaccion: " . autoCurrentCycle . " de " . autoTotalCycles . " (" . pct . "%)"
    }

    txtMetricsA.Text := "Tiempo: " . timeFormatted
    txtMetricsC.Text := "Completadas: " . autoSuccessCount
}

UpdateReportsTabSummary() {
    global autoCurrentCSV, autoSuccessCount, autoFailCount, autoStartTime
    global txtRepInfo1, txtRepInfo2, txtRepInfo3, txtRepInfo4, txtRepInfo5

    totalRuns := autoSuccessCount + autoFailCount
    elapsedSec := Round((A_TickCount - autoStartTime) / 1000)
    avgSec := (autoSuccessCount > 0) ? Round(elapsedSec / autoSuccessCount, 1) : 0.0
    rate := (totalRuns > 0) ? Round((autoSuccessCount / totalRuns) * 100, 1) : 100.0

    txtRepInfo1.Text := "Registro CSV: " . (autoCurrentCSV != "" ? autoCurrentCSV : "(Ninguno)")
    txtRepInfo2.Text := "Total de Transacciones: " . totalRuns . " (" . autoSuccessCount . " OK, " . autoFailCount . " Interrupciones)"
    txtRepInfo3.Text := "Duracion Total: " . elapsedSec . " segundos"
    txtRepInfo4.Text := "Promedio por Transaccion: " . avgSec . "s"
    txtRepInfo5.Text := "Tasa de Exito: " . rate . "%"
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
            MsgBox("Aun no se han generado registros de transacciones.", "QA POS Automation", "Iconi")
    }
}

; ==============================================================================
; MOTOR DE GRABACIÓN DE MACROS (HOOK NO INTRUSIVO)
; ==============================================================================

StartRecording(*) {
    global isRecording, isPausedRec, firstKeyRecorded, lastTick, macroBuffer, textBuffer, keyHook
    global btnRecord, btnPauseRec, btnSaveRec, btnCancelRec, btnPlay, edtBufferPreview, edtMacroName

    if (isPlaying) {
        MsgBox("No se puede grabar mientras se esta ejecutando una automatizacion.", "QA POS Automation", "Icon! 262144")
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
    edtBufferPreview.Text := "; Grabando pulsaciones... Opera normalmente en la terminal POS.`r`n"

    keyHook := InputHook("V L0")
    keyHook.KeyOpt("{All}", "+N")
    keyHook.OnKeyDown := OnKeyDownHandler
    keyHook.OnChar := OnCharHandler
    keyHook.Start()

    UpdateStatus("GRABANDO EN DIRECTO... (Opera en terminal POS)")
    btnRecord.Enabled := false
    btnPauseRec.Enabled := true
    btnPauseRec.Text := "Pausar"
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
        UpdateStatus("GRABANDO EN DIRECTO... (Opera en terminal POS)")
        btnPauseRec.Text := "Pausar"
        try edtMacroName.Enabled := false
    } else {
        FlushTextBuffer()
        isPausedRec := true
        lastTick := 0
        UpdateStatus("Grabacion en pausa")
        btnPauseRec.Text := "Reanudar"
        try edtMacroName.Enabled := true
    }
}

SaveRecording(*) {
    global isRecording, isPausedRec, macroBuffer, macroFolder, ddlMacros, ddlEditMacros, edtMacroName, mainTabs

    if (!isRecording)
        return

    StopHook()
    FlushTextBuffer()
    isRecording := false
    isPausedRec := false
    try edtMacroName.Enabled := true

    if (macroBuffer.Length == 0) {
        UpdateStatus("No se registraron pulsaciones de teclas")
        MsgBox("No se registraron pulsaciones de tecla durante la grabacion.", "QA POS Automation", "Iconi 262144")
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
    fileContent := "; Macro de Transaccion para Terminal POS`n"
    fileContent .= "; Archivo: " . fileName . "`n"
    fileContent .= "; Fecha de Creacion: " . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "`n`n"

    for item in macroBuffer {
        fileContent .= item . "`n"
    }

    try {
        if FileExist(fullPath)
            FileDelete(fullPath)
        FileAppend(fileContent, fullPath, "UTF-8")

        RefreshMacroList()
        try ddlMacros.Text := fileName
        try ddlEditMacros.Text := fileName

        try mainTabs.Value := 1
        try edtMacroName.Text := "Transaccion_" . FormatTime(, "yyyyMMdd_HHmmss")

        UpdateStatus("Guardada en biblioteca: " . fileName)
        MsgBox("Macro guardada exitosamente en la biblioteca.`n`nArchivo: " . fullPath . "`nInstrucciones: " . macroBuffer.Length .
            "`n`nYa se encuentra seleccionada en la pestaña 'Automatizar'.", "QA POS Automation", "Iconi 262144")
    } catch Error as err {
        MsgBox("Error al guardar archivo: " . err.Message, "QA POS Automation", "Iconx 262144")
        UpdateStatus("Error al guardar archivo de macro")
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
    edtBufferPreview.Text := "; Grabacion cancelada."
    UpdateStatus("Grabacion cancelada")
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
    btnPauseRec.Text := "Pausar"
    btnSaveRec.Enabled := false
    btnCancelRec.Enabled := false
    try edtMacroName.Enabled := true

    btnPlay.Enabled := true
    btnPausePlay.Enabled := false
    btnPausePlay.Text := "PAUSAR`n(Ctrl+P)"

    RefreshMacroList()
}

; ==============================================================================
; GESTOR DE ACTUALIZACIONES (GITHUB RELEASES API)
; ==============================================================================

CleanJSONString(str) {
    str := StrReplace(str, "\r\n", "`r`n")
    str := StrReplace(str, "\n", "`r`n")
    str := StrReplace(str, "\t", "    ")
    str := StrReplace(str, '\"', '"')
    str := StrReplace(str, "\\", "\")
    return str
}

CompareVersions(v1, v2) {
    v1 := RegExReplace(v1, "^v", "")
    v2 := RegExReplace(v2, "^v", "")
    p1 := StrSplit(v1, ".")
    p2 := StrSplit(v2, ".")
    loop 3 {
        n1 := (p1.Length >= A_Index) ? Integer(p1[A_Index]) : 0
        n2 := (p2.Length >= A_Index) ? Integer(p2[A_Index]) : 0
        if (n1 > n2)
            return 1
        if (n1 < n2)
            return -1
    }
    return 0
}

CheckForUpdates(showFeedback := true) {
    global appVersion, latestReleaseUrl, latestZipDownloadUrl
    global txtRemoteVer, txtUpdateState, edtReleaseNotes, btnDownloadZip, btnHeaderUpdate

    txtUpdateState.Text := "Consultando API de GitHub Releases..."
    try {
        req := ComObject("Msxml2.ServerXMLHTTP.6.0")
        req.setTimeouts(3000, 3000, 3000, 5000)
        req.Open("GET", "https://api.github.com/repos/EfrainSN/QA-POS-Automation-Macro/releases/latest", false)
        req.SetRequestHeader("User-Agent", "QA-POS-Automation-Macro")
        req.SetRequestHeader("Accept", "application/vnd.github.v3+json")
        req.Send()

        if (req.Status != 200) {
            txtUpdateState.Text := "Error de servidor HTTP " . req.Status
            if (showFeedback)
                MsgBox("No se pudo verificar actualizaciones (HTTP " . req.Status . ").", "Actualizaciones", "Icon! 262144")
            return
        }

        resp := req.ResponseText
        remoteTag := ""
        if RegExMatch(resp, '\"tag_name\":\s*\"([^\"]+)\"', &mTag)
            remoteTag := mTag[1]

        releaseTitle := ""
        if RegExMatch(resp, '\"name\":\s*\"([^\"]+)\"', &mName)
            releaseTitle := CleanJSONString(mName[1])

        releaseUrl := ""
        if RegExMatch(resp, '\"html_url\":\s*\"([^\"]+)\"', &mUrl)
            releaseUrl := mUrl[1]
        if (releaseUrl != "")
            latestReleaseUrl := releaseUrl

        bodyText := ""
        if RegExMatch(resp, '\"body\":\s*\"(.*?)(?<!\\)\"', &mBody)
            bodyText := CleanJSONString(mBody[1])

        zipUrl := ""
        if RegExMatch(resp, '\"browser_download_url\":\s*\"([^\"]+Portable\.zip)\"', &mZip)
            zipUrl := mZip[1]
        latestZipDownloadUrl := zipUrl

        comp := CompareVersions(remoteTag, appVersion)
        if (comp > 0) {
            txtRemoteVer.Text := remoteTag . " (Nueva Version Disponible)"
            txtUpdateState.Text := "Existe una nueva version disponible para descargar."
            btnHeaderUpdate.Text := "Nueva Version!"
            btnDownloadZip.Enabled := (latestZipDownloadUrl != "")
            if (showFeedback) {
                MsgBox("Hay una nueva version disponible en GitHub:`n`nInstalada: v" . appVersion . "`nDisponible: " . remoteTag .
                    "`n`nPuedes revisar las novedades o descargar el paquete portable.", "Actualizaciones", "Iconi 262144")
            }
        } else {
            txtRemoteVer.Text := remoteTag . " (Al dia)"
            txtUpdateState.Text := "Tu aplicacion esta actualizada a la version mas reciente."
            btnHeaderUpdate.Text := "v" . appVersion . " (Al dia)"
            btnDownloadZip.Enabled := (latestZipDownloadUrl != "")
            if (showFeedback) {
                MsgBox("Tu version (v" . appVersion . ") esta completamente actualizada.`nNo hay nuevas versiones pendientes.",
                    "Actualizaciones", "Iconi 262144")
            }
        }

        displayText := "VERSION EN GITHUB: " . remoteTag . "`r`n"
        displayText .= "TITULO: " . releaseTitle . "`r`n"
        displayText .= "ENLACE: " . latestReleaseUrl . "`r`n`r`n"
        displayText .= "--- NOVEDADES Y NOTAS DE LA VERSION ---`r`n"
        displayText .= (bodyText != "") ? bodyText : "(Sin notas de version declaradas)"
        edtReleaseNotes.Text := displayText

    } catch Error as err {
        txtUpdateState.Text := "No se pudo conectar a GitHub (Modo offline)."
        if (showFeedback) {
            MsgBox("No se pudo conectar con GitHub.`nTerminal sin conexion a internet o bloqueada por firewall.`n`nDetalle: " . err.Message,
                "Actualizaciones", "Icon! 262144")
        }
    }
}


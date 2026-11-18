; ==============================================================================
; MODULE: src\UI\MainWindow.ahk
; PURPOSE: Construccion de la interfaz principal, eventos, Biblioteca de
;          Transacciones PosLog y ciclo de vida de la aplicacion
; ==============================================================================

BuildMainWindowUI() {
    global appVersion, targetWinTitle, macroFolder, reportsFolder, screenshotsFolder, ticketsFolder
    global latestReleaseUrl, latestZipDownloadUrl, smartLogSyncEnabled, sentinelEnabled, selfHealEnabled
    global mainGui, mainTabs, txtStatus, btnHeaderUpdate, edtTargetWin, btnDetectWin
    global ddlMacros, btnRefresh, btnOpenFolderMacro, radModeSingle, radModeBatch, edtReps, chkInfinite
    global ddlSpeed, chkSmartSync, edtLoopDelay, chkSentinel, btnSentinelPath, txtSentinelStatus
    global btnPosLogPath, txtPosLogStatus, chkSelfHeal
    global progBar, txtProgress, txtMetricsA, txtMetricsC, btnPlay, btnPausePlay, btnStop
    global edtMacroName, btnRecord, btnPauseRec, btnSaveRec, btnCancelRec, edtBufferPreview
    global ddlEditMacros, btnLoadMacro, btnBatchOptimize, lvSteps, btnStepUp, btnStepDown, btnStepDup
    global btnStepDel, btnPreviewClick, btnTestStep, btnRunFromHere, ddlStepType, edtStepVal
    global btnApplyStep, btnInsertStep, txtStepDesc, btnSaveMacroFile, btnSaveAsMacroFile
    global txtRepInfo1, txtRepInfo2, txtRepInfo3, txtRepInfo4, txtRepInfo5
    global lvLibTrans, btnViewTicket, btnReloadPosLog
    global btnOpenInEditor, btnOpenNotepad, btnViewDashboard, btnViewLastCSV
    global btnOpenMacros, btnOpenReports, btnOpenScreenshots, btnCheckUpdatesLib
    global txtLocalVer, txtRemoteVer, txtUpdateState, btnCheckUpdates, btnOpenReleases, edtReleaseNotes, btnDownloadZip

    mainGui := Gui("+AlwaysOnTop -MaximizeBox", "QA POS Automation Macro v" . appVersion)
    mainGui.BackColor := "D9EBF7"
    mainGui.SetFont("s9", "Segoe UI")

    ; --- ENCABEZADO PRINCIPAL ---
    mainGui.Add("Text", "x12 y10 w446 h48 +Border Background123859", "")
    txtBrand := mainGui.Add("Text", "x24 y14 w300 h20 BackgroundTrans c5AD1FF", "QA POS AUTOMATION MACRO - MODULAR EDITION")
    txtBrand.SetFont("s10 Bold", "Segoe UI")
    txtStatus := mainGui.Add("Text", "x24 y34 w300 h18 BackgroundTrans cE2F3FF", "Listo para automatizar transacciones en caja POS")
    btnHeaderUpdate := mainGui.Add("Button", "x332 y16 w116 h36", "Actualizaciones")

    ; --- PESTAÑAS PRINCIPALES ---
    mainTabs := mainGui.Add("Tab3", "x12 y65 w446 h492", ["Automatizar", "Grabar Macro", "Editor de Pasos", "Biblioteca", "Actualizaciones"])

    ; ------------------------------------------------------------------------------
    ; PESTAÑA 1: AUTOMATIZAR TRANSACCIONES
    ; ------------------------------------------------------------------------------
    mainTabs.UseTab(1)

    mainGui.Add("GroupBox", "x24 y94 w422 h60", "1. Ventana de la Caja POS")
    mainGui.Add("Text", "x36 y115 w85 h20 c153858", "Ventana POS:")
    edtTargetWin := mainGui.Add("Edit", "x125 y112 w195 h24 BackgroundFFFFFF", targetWinTitle)
    btnDetectWin := mainGui.Add("Button", "x326 y111 w106 h26", "Vincular")

    mainGui.Add("GroupBox", "x24 y158 w422 h68", "2. Transaccion a Ejecutar")
    mainGui.Add("Text", "x36 y179 w55 h20 c153858", "Macro:")
    ddlMacros := mainGui.Add("DropDownList", "x95 y176 w195 Choose1", ["(Sin macros)"])
    btnRefresh := mainGui.Add("Button", "x296 y175 w68 h26", "Recargar")
    btnOpenFolderMacro := mainGui.Add("Button", "x368 y175 w64 h26", "Carpeta")
    mainGui.Add("Text", "x36 y204 w396 h18 c416A8C", "Sincronizacion con log Xstore, PosLog.xml y Copiar/Pegar activos.")

    mainGui.Add("GroupBox", "x24 y230 w422 h148", "3. Modo de Automatizacion, Centinela y PosLog.xml")
    mainGui.Add("Text", "x36 y250 w60 h20 c153858", "Ejecutar:")
    radModeSingle := mainGui.Add("Radio", "x100 y249 w105 h20 Checked", "1 Transaccion")
    radModeBatch := mainGui.Add("Radio", "x210 y249 w50 h20", "Lote:")
    edtReps := mainGui.Add("Edit", "x265 y247 w45 h22 Number Center BackgroundFFFFFF Disabled", "5")
    mainGui.Add("Text", "x315 y250 w35 h20 c416A8C", "veces")
    chkInfinite := mainGui.Add("CheckBox", "x355 y249 w75 h20", "Infinito")

    mainGui.Add("Text", "x36 y275 w70 h20 c153858", "Velocidad:")
    ddlSpeed := mainGui.Add("DropDownList", "x110 y272 w145 Choose2", [
        "0.8x (Seguro / Pausado)",
        "1.0x (Normal Recomendado)",
        "1.2x (Rapido POS)",
        "1.5x (Turbo Agil)"
    ])
    chkSmartSync := mainGui.Add("CheckBox", "x264 y274 w172 h20 Checked", "Sync Log Xstore (WaitPrompt)")
    edtLoopDelay := mainGui.Add("Edit", "x0 y0 w0 h0 Hidden", "1000")

    chkSentinel := mainGui.Add("CheckBox", "x36 y301 w195 h20 Checked", "Centinela Xstore (Auto-Parada)")
    btnSentinelPath := mainGui.Add("Button", "x235 y299 w88 h22", "Ruta Log...")
    txtSentinelStatus := mainGui.Add("Text", "x328 y302 w105 h18 Right c0E7D42", "[Log Activo]")

    mainGui.Add("Text", "x36 y327 w195 h18 c153858", "Extraccion Ticket (PosLog.xml):")
    btnPosLogPath := mainGui.Add("Button", "x235 y324 w88 h22", "Ruta PosLog...")
    txtPosLogStatus := mainGui.Add("Text", "x328 y327 w105 h18 Right c0E7D42", "[PosLog Activo]")

    chkSelfHeal := mainGui.Add("CheckBox", "x36 y351 w396 h20", "Auto-Recuperar en Lote (Cerrar popup de error con Enter/Esc y seguir)")

    mainGui.Add("GroupBox", "x24 y382 w422 h82", "Estado de la Automatizacion")
    progBar := mainGui.Add("Progress", "x36 y400 w398 h16 Range0-100 c00A2ED BackgroundC8E3F5", 0)
    txtProgress := mainGui.Add("Text", "x36 y420 w398 h18 Center c153858", "Listo para iniciar. Esperando orden")
    txtProgress.SetFont("Bold")

    txtMetricsA := mainGui.Add("Text", "x36 y440 w190 h18 c153858", "Tiempo: 00:00:00")
    txtMetricsC := mainGui.Add("Text", "x234 y440 w200 h18 Right c0E7D42", "Completadas: 0")

    btnPlay := mainGui.Add("Button", "x24 y472 w154 h44 Default", "EJECUTAR`nTRANSACCION")
    btnPausePlay := mainGui.Add("Button", "x184 y472 w126 h44 Disabled", "PAUSAR`n(Ctrl+P)")
    btnStop := mainGui.Add("Button", "x316 y472 w130 h44", "DETENER`n(Ctrl+M)")

    ; ------------------------------------------------------------------------------
    ; PESTAÑA 2: GRABAR NUEVA MACRO
    ; ------------------------------------------------------------------------------
    mainTabs.UseTab(2)

    mainGui.Add("GroupBox", "x24 y96 w422 h170", "Nueva Secuencia de Transaccion")
    mainGui.Add("Text", "x36 y118 w398 h28 c416A8C",
        "Asigna un nombre, presiona Grabar y opera en Xstore. Detecta botones [Action], Prompts, Copiar/Pegar (SKUs, Gerente, Tarjetas) y coordenadas."
    )
    mainGui.Add("Text", "x36 y153 w110 h20 c153858", "Nombre de Macro:")
    edtMacroName := mainGui.Add("Edit", "x150 y150 w272 h24 BackgroundFFFFFF", "Transaccion_" . FormatTime(, "yyyyMMdd_HHmmss"))

    btnRecord := mainGui.Add("Button", "x36 y182 w185 h38", "Iniciar Grabacion")
    btnPauseRec := mainGui.Add("Button", "x237 y182 w185 h38 Disabled", "Pausar")

    btnSaveRec := mainGui.Add("Button", "x36 y224 w185 h36 Disabled", "Guardar en Biblioteca")
    btnCancelRec := mainGui.Add("Button", "x237 y224 w185 h36 Disabled", "Cancelar")

    mainGui.Add("GroupBox", "x24 y274 w422 h244", "Visor de Secuencia Capturada (En Vivo con Etiquetado Xstore)")
    edtBufferPreview := mainGui.Add("Edit", "x36 y297 w398 h208 ReadOnly BackgroundF8FBFE",
        "; Las pulsaciones, textos pegados (Ctrl+V / Raton), botones [Action] y Prompts apareceran aqui...`r`n")

    ; ------------------------------------------------------------------------------
    ; PESTAÑA 3: EDITOR DE PASOS
    ; ------------------------------------------------------------------------------
    mainTabs.UseTab(3)

    mainGui.Add("Text", "x24 y96 w90 h20 c153858", "Macro a Editar:")
    ddlEditMacros := mainGui.Add("DropDownList", "x116 y92 w190 Choose1", ["(Sin macros)"])
    btnLoadMacro := mainGui.Add("Button", "x310 y91 w64 h26", "Cargar")
    btnBatchOptimize := mainGui.Add("Button", "x378 y91 w68 h26", "Masivo")

    lvSteps := mainGui.Add("ListView", "x24 y122 w422 h162 Grid -Multi BackgroundFFFFFF", ["#", "Tipo", "Accion / Contexto POS", "Instruccion / Valor"])
    lvSteps.ModifyCol(1, 32)
    lvSteps.ModifyCol(2, 92)
    lvSteps.ModifyCol(3, 145)
    lvSteps.ModifyCol(4, 130)

    btnStepUp := mainGui.Add("Button", "x24 y288 w58 h26", "Subir")
    btnStepDown := mainGui.Add("Button", "x85 y288 w58 h26", "Bajar")
    btnStepDup := mainGui.Add("Button", "x146 y288 w62 h26", "Duplicar")
    btnStepDel := mainGui.Add("Button", "x211 y288 w58 h26", "Eliminar")
    btnPreviewClick := mainGui.Add("Button", "x272 y288 w56 h26", "Mira")
    btnTestStep := mainGui.Add("Button", "x331 y288 w56 h26", "Paso")
    btnRunFromHere := mainGui.Add("Button", "x390 y288 w56 h26", "Aqui")

    mainGui.Add("GroupBox", "x24 y318 w422 h128", "Modificar Paso Seleccionado")
    mainGui.Add("Text", "x36 y340 w38 h20 c153858", "Tipo:")
    ddlStepType := mainGui.Add("DropDownList", "x76 y337 w132 Choose1", [
        "Texto / SKU",
        "Tecla Especial",
        "Pausa (ms)",
        "Clic Raton",
        "Clic UIA (Boton)",
        "Esperar Prompt (Log)"
    ])
    mainGui.Add("Text", "x214 y340 w38 h20 c153858", "Valor:")
    edtStepVal := mainGui.Add("Edit", "x254 y337 w180 h23 BackgroundFFFFFF", "")

    btnApplyStep := mainGui.Add("Button", "x36 y368 w192 h28", "Actualizar Paso")
    btnInsertStep := mainGui.Add("Button", "x242 y368 w192 h28", "Insertar Nuevo Paso")
    txtStepDesc := mainGui.Add("Text", "x36 y402 w398 h36 c416A8C", "Selecciona un paso para editarlo, ver su mira en Xstore (Mira), probar solo ese paso (Paso) o correr desde alli (Aqui).")

    btnSaveMacroFile := mainGui.Add("Button", "x24 y452 w206 h42", "GUARDAR CAMBIOS`n(Sobrescribir)")
    btnSaveAsMacroFile := mainGui.Add("Button", "x240 y452 w206 h42", "GUARDAR COMO...`n(Nueva Variante)")

    ; ------------------------------------------------------------------------------
    ; PESTAÑA 4: BIBLIOTECA, COMPROBANTES POSLOG Y DASHBOARD FORENSE
    ; ------------------------------------------------------------------------------
    mainTabs.UseTab(4)

    mainGui.Add("GroupBox", "x24 y92 w422 h86", "Resumen de Telemetria y Ultima Ejecucion")
    txtRepInfo1 := mainGui.Add("Text", "x34 y110 w402 h18 c153858", "Registro CSV: (Ninguno)")
    txtRepInfo2 := mainGui.Add("Text", "x34 y130 w200 h18 c153858", "Transacciones: 0")
    txtRepInfo3 := mainGui.Add("Text", "x238 y130 w198 h18 c153858", "Volumen / Tiempo: Q 0.00")
    txtRepInfo4 := mainGui.Add("Text", "x34 y150 w200 h18 c153858", "Latencia Media / P95: 0.00s")
    txtRepInfo5 := mainGui.Add("Text", "x238 y150 w198 h18 c0E7D42", "Exito: 100% | Tickets: 0")

    mainGui.Add("GroupBox", "x24 y182 w422 h202", "Comprobantes de Transacciones (PosLog.xml / xstore.log)")
    lvLibTrans := mainGui.Add("ListView", "x32 y200 w406 h146 Grid -Multi BackgroundFFFFFF", [
        "#", "Trans #", "Documento", "Cliente / NIT", "Pago", "Total", "Tiempo", "Estado"
    ])
    lvLibTrans.ModifyCol(1, 28)
    lvLibTrans.ModifyCol(2, 54)
    lvLibTrans.ModifyCol(3, 68)
    lvLibTrans.ModifyCol(4, 110)
    lvLibTrans.ModifyCol(5, 65)
    lvLibTrans.ModifyCol(6, 68)
    lvLibTrans.ModifyCol(7, 48)
    lvLibTrans.ModifyCol(8, 70)

    btnViewTicket := mainGui.Add("Button", "x32 y351 w136 h26", "Ver Comprobante")
    btnReloadPosLog := mainGui.Add("Button", "x172 y351 w130 h26", "Leer PosLog.xml")
    btnLibPosLogPath := mainGui.Add("Button", "x306 y351 w132 h26", "Ruta PosLog...")

    mainGui.Add("GroupBox", "x24 y388 w422 h124", "Dashboard Analitico, Macros y Carpetas de Evidencia")
    btnViewDashboard := mainGui.Add("Button", "x32 y406 w132 h32", "Abrir Dashboard")
    btnViewLastCSV := mainGui.Add("Button", "x169 y406 w132 h32", "Ver Registro CSV")
    btnOpenInEditor := mainGui.Add("Button", "x306 y406 w132 h32", "Editar Macro")

    btnOpenMacros := mainGui.Add("Button", "x32 y442 w132 h30", "Carpeta Macros")
    btnOpenReports := mainGui.Add("Button", "x169 y442 w132 h30", "Carpeta Reportes")
    btnOpenNotepad := mainGui.Add("Button", "x306 y442 w132 h30", "Bloc de Notas")

    btnOpenScreenshots := mainGui.Add("Button", "x32 y476 w198 h28", "Capturas de Error (.png)")
    btnCheckUpdatesLib := mainGui.Add("Button", "x240 y476 w198 h28", "Buscar Actualizaciones")

    ; ------------------------------------------------------------------------------
    ; PESTAÑA 5: ACTUALIZACIONES Y RELEASES
    ; ------------------------------------------------------------------------------
    mainTabs.UseTab(5)

    mainGui.Add("GroupBox", "x24 y96 w422 h148", "Estado de Actualizaciones (GitHub Releases)")
    mainGui.Add("Text", "x36 y120 w150 h20 c153858", "Version Local Instalada:")
    txtLocalVer := mainGui.Add("Text", "x190 y120 w235 h20 c153858", "v" . appVersion . " (Modular Edition)")
    txtLocalVer.SetFont("Bold")

    mainGui.Add("Text", "x36 y142 w150 h20 c153858", "Ultima Version en GitHub:")
    txtRemoteVer := mainGui.Add("Text", "x190 y142 w235 h20 c0E7D42", "(No comprobado)")
    txtRemoteVer.SetFont("Bold")

    mainGui.Add("Text", "x36 y164 w60 h20 c153858", "Estado:")
    txtUpdateState := mainGui.Add("Text", "x100 y164 w330 h20 c153858", "Presiona 'Buscar Actualizaciones' para verificar.")

    btnCheckUpdates := mainGui.Add("Button", "x36 y192 w190 h38 Default", "Buscar Actualizaciones")
    btnOpenReleases := mainGui.Add("Button", "x238 y192 w190 h38", "Abrir GitHub Releases")

    mainGui.Add("GroupBox", "x24 y252 w422 h244", "Registro de Cambios y Novedades (Changelog)")
    edtReleaseNotes := mainGui.Add("Edit", "x36 y274 w398 h172 ReadOnly BackgroundF8FBFE",
        "Presiona 'Buscar Actualizaciones' para consultar el registro de versiones y mejoras disponibles en el repositorio.")

    btnDownloadZip := mainGui.Add("Button", "x36 y452 w398 h34 Disabled", "Descargar Paquete ZIP Portable de la Ultima Version")

    mainTabs.UseTab()

    ; --- PIE DE VENTANA ---
    mainGui.SetFont("s8 c406888", "Segoe UI")
    mainGui.Add("Text", "x12 y562 w446 Center",
        "QA POS Automation Macro v" . appVersion . " - Modular Edition - Ctrl+P: Pausar - Ctrl+M: Detener")
    mainGui.SetFont("s9", "Segoe UI")

    ; --- ENLACE DE EVENTOS Y CONTROLADORES ---
    btnDetectWin.OnEvent("Click", DetectTargetWindow)
    edtTargetWin.OnEvent("Change", (*) => SaveSettings())
    ddlMacros.OnEvent("Change", (*) => SaveSettings())
    btnRefresh.OnEvent("Click", RefreshMacroList)
    btnOpenFolderMacro.OnEvent("Click", (*) => (EnsureRequiredDirectories(), Run("explore `"" . macroFolder . "`"")))

    radModeSingle.OnEvent("Click", UpdateExecutionMode)
    radModeBatch.OnEvent("Click", UpdateExecutionMode)
    edtReps.OnEvent("Change", (*) => SaveSettings())
    chkInfinite.OnEvent("Click", ToggleInfiniteMode)
    ddlSpeed.OnEvent("Change", UpdateSpeedMultiplier)
    chkSmartSync.OnEvent("Click", (*) => (smartLogSyncEnabled := (chkSmartSync.Value == 1), SaveSettings()))

    chkSentinel.OnEvent("Click", (*) => (sentinelEnabled := (chkSentinel.Value == 1), UpdateSentinelStatus(), SaveSettings()))
    btnSentinelPath.OnEvent("Click", ConfigureSentinelPath)
    btnPosLogPath.OnEvent("Click", ConfigurePosLogPath)
    chkSelfHeal.OnEvent("Click", (*) => (selfHealEnabled := (chkSelfHeal.Value == 1), SaveSettings()))

    btnPlay.OnEvent("Click", (*) => StartAutomation(1))
    btnPausePlay.OnEvent("Click", TogglePauseAutomation)
    btnStop.OnEvent("Click", EmergencyStop)

    btnRecord.OnEvent("Click", StartRecording)
    btnPauseRec.OnEvent("Click", TogglePauseRecording)
    btnSaveRec.OnEvent("Click", SaveRecording)
    btnCancelRec.OnEvent("Click", CancelRecording)

    mainTabs.OnEvent("Change", OnTabChanged)
    btnLoadMacro.OnEvent("Click", LoadMacroIntoEditor)
    btnBatchOptimize.OnEvent("Click", ShowBatchOptimizerDialog)
    ddlEditMacros.OnEvent("Change", LoadMacroIntoEditor)
    lvSteps.OnEvent("ItemSelect", (lv, row, selected) => (selected ? OnStepSelected(lv, row) : 0))
    lvSteps.OnEvent("DoubleClick", (lv, row) => (row > 0 ? HighlightStepOnPOS() : 0))

    btnStepUp.OnEvent("Click", MoveStepUp)
    btnStepDown.OnEvent("Click", MoveStepDown)
    btnStepDup.OnEvent("Click", DuplicateStep)
    btnStepDel.OnEvent("Click", DeleteStep)
    btnPreviewClick.OnEvent("Click", HighlightStepOnPOS)
    btnTestStep.OnEvent("Click", TestSingleSelectedStep)
    btnRunFromHere.OnEvent("Click", RunMacroFromSelectedStep)

    btnApplyStep.OnEvent("Click", ApplyStepEdit)
    btnInsertStep.OnEvent("Click", InsertStep)
    btnSaveMacroFile.OnEvent("Click", SaveMacroChanges)
    btnSaveAsMacroFile.OnEvent("Click", SaveAsMacro)

    lvLibTrans.OnEvent("DoubleClick", (lv, row) => (row > 0 ? ViewSelectedTransactionTicket() : 0))
    btnViewTicket.OnEvent("Click", ViewSelectedTransactionTicket)
    btnReloadPosLog.OnEvent("Click", ReloadLibraryTransactionsFromPosLog)
    btnLibPosLogPath.OnEvent("Click", ConfigurePosLogPath)

    btnOpenInEditor.OnEvent("Click", OpenSelectedInEditorTab)
    btnOpenNotepad.OnEvent("Click", EditSelectedMacro)
    btnViewDashboard.OnEvent("Click", OpenLastHTMLDashboard)
    btnOpenMacros.OnEvent("Click", (*) => (EnsureRequiredDirectories(), Run("explore `"" . macroFolder . "`"")))
    btnOpenReports.OnEvent("Click", (*) => (EnsureRequiredDirectories(), Run("explore `"" . reportsFolder . "`"")))
    btnCheckUpdatesLib.OnEvent("Click", (*) => (mainTabs.Value := 5, CheckForUpdates(true)))
    btnViewLastCSV.OnEvent("Click", OpenLastCSVReport)
    btnOpenScreenshots.OnEvent("Click", (*) => (EnsureRequiredDirectories(), Run("explore `"" . screenshotsFolder . "`"")))

    btnHeaderUpdate.OnEvent("Click", (*) => (mainTabs.Value := 5, CheckForUpdates(false)))
    btnCheckUpdates.OnEvent("Click", (*) => CheckForUpdates(true))
    btnOpenReleases.OnEvent("Click", (*) => Run(latestReleaseUrl))
    btnDownloadZip.OnEvent("Click", (*) => (latestZipDownloadUrl != "" ? Run(latestZipDownloadUrl) : Run(latestReleaseUrl)))

    mainGui.OnEvent("Close", (*) => (SaveSettings(), ExitApp()))
    OnExit((*) => SaveSettings())
}

InitializeApplication() {
    global savedLastMacro, mainGui
    EnsureRequiredDirectories()
    BuildMainWindowUI()
    DetectDefaultLogPath()
    DetectDefaultPosLogPath()
    LoadSettings()
    RefreshMacroList(savedLastMacro)
    UpdateSentinelStatus()
    UpdatePosLogStatus()
    ReloadLibraryTransactionsFromPosLog()
    mainGui.Show("w470 h590")
    AutoDetectPosOnStartup()
    SetTimer(() => CheckForUpdates(false), -1500)
}

UpdateExecutionMode(*) {
    global radModeSingle, radModeBatch, edtReps, chkInfinite
    if (radModeSingle.Value == 1) {
        edtReps.Enabled := false
    } else if (radModeBatch.Value == 1) {
        edtReps.Enabled := true
        chkInfinite.Value := 0
    }
    SaveSettings()
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
    SaveSettings()
}

RefreshMacroList(preferredMacro := "", *) {
    global ddlMacros, ddlEditMacros, btnPlay, macroFolder, isRecording, isPlaying

    EnsureRequiredDirectories()

    currentSel := (Type(preferredMacro) == "String" && preferredMacro != "") ? preferredMacro : ddlMacros.Text

    macroFiles := []
    loop files, macroFolder . "\*.txt" {
        macroFiles.Push(A_LoopFileName)
    }

    ddlMacros.Delete()
    ddlEditMacros.Delete()

    if (macroFiles.Length > 0) {
        ddlMacros.Add(macroFiles)
        ddlEditMacros.Add(macroFiles)

        chosenIdx := 1
        for idx, f in macroFiles {
            if (f = currentSel) {
                chosenIdx := idx
                break
            }
        }
        ddlMacros.Choose(chosenIdx)
        ddlEditMacros.Choose(chosenIdx)

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
        case 1: speedMultiplier := 1.25
        case 2: speedMultiplier := 1.0
        case 3: speedMultiplier := 0.83
        case 4: speedMultiplier := 0.67
        default: speedMultiplier := 1.0
    }
    SaveSettings()
}

EditSelectedMacro(*) {
    global ddlMacros, macroFolder
    EnsureRequiredDirectories()
    selectedMacro := ddlMacros.Text
    if (selectedMacro == "" || selectedMacro == "(Sin macros guardadas)") {
        MsgBox("Selecciona primero una macro valida para editar.", "QA POS Automation", "Icon! 262144")
        return
    }
    fullPath := macroFolder . "\" . selectedMacro
    if FileExist(fullPath) {
        Run("notepad.exe `"" . fullPath . "`"")
    } else {
        MsgBox("El archivo '" . fullPath . "' no existe.", "QA POS Automation", "Iconx 262144")
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

OnTabChanged(ctrl, *) {
    global editorSteps, ddlEditMacros, txtRemoteVer, libraryTransactions
    if (ctrl.Value == 3 && editorSteps.Length == 0 && ddlEditMacros.Text != "" && ddlEditMacros.Text != "(Sin macros guardadas)") {
        LoadMacroIntoEditor()
    } else if (ctrl.Value == 4 && libraryTransactions.Length == 0) {
        ReloadLibraryTransactionsFromPosLog()
    } else if (ctrl.Value == 5 && txtRemoteVer.Text == "(No comprobado)") {
        CheckForUpdates(false)
    }
}

UpdateStatus(statusText) {
    global txtStatus
    if IsObject(txtStatus)
        txtStatus.Text := statusText
}

ResetUI() {
    global isRecording, isPlaying, isCountdownActive, btnRecord, btnPauseRec, btnSaveRec, btnCancelRec
    global btnPlay, btnPausePlay, edtMacroName, mainGui

    HideCountdownHUD()
    HideFloatingMiniHUD()
    if (isCountdownActive) {
        isCountdownActive := false
        SetTimer(RecordingCountdownTick, 0)
    }

    ToolTip()
    if IsObject(mainGui)
        WinSetTransparent("Off", mainGui)

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

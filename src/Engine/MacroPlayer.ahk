; ==============================================================================
; MODULE: src\Engine\MacroPlayer.ahk
; PURPOSE: Motor de reproduccion nativa con Sync Log, coordenadas proporcionales,
;          envio de texto literal ({Text}) inmune a CapsLock, extraccion dual
;          de comprobantes (PosLog.xml + xstore.log) y Self-Healing
; ==============================================================================

ResolveProportionalCoords(rawPayload, rawX, rawY, &outX, &outY) {
    global targetPosHwnd
    outX := rawX
    outY := rawY
    if RegExMatch(rawPayload, "i)WinSize=(\d+)x(\d+)", &mSz) {
        origW := Integer(mSz[1])
        origH := Integer(mSz[2])
        if (origW > 0 && origH > 0) {
            ; Si la ventana activa actual coincide exactamente con el WinSize grabado (ej. un dialogo modal 1307x803), no reescalar
            actW := 0, actH := 0
            try WinGetPos(, , &actW, &actH, "A")
            if (actW == origW && actH == origH)
                return

            if (targetPosHwnd) {
                curW := 0, curH := 0
                try WinGetPos(, , &curW, &curH, "ahk_id " . targetPosHwnd)
                ; Solo reescalar si ambas dimensiones corresponden a la ventana principal redimensionada
                if (curW > 100 && curH > 100 && (curW != origW || curH != origH) && origW >= 1360) {
                    outX := Round(rawX * (curW / origW))
                    outY := Round(rawY * (curH / origH))
                }
            }
        }
    }
}

PerformSafePosClick(clickX, clickY, btn := "Left") {
    global targetPosHwnd
    CoordMode("Mouse", "Window")
    if (!targetPosHwnd || !WinActive("ahk_id " . targetPosHwnd)) {
        if (!EnsureTargetWindowActive())
            return false
    }

    ; Desplazar fisicamente el cursor sobre el control en Xstore para activar hover/foco antes del evento AWT/Swing
    MouseMove(clickX, clickY, 0)
    Sleep(25)

    Click(btn . " Down")
    Sleep(45)
    Click(btn . " Up")
    Sleep(30)
    return true
}

PerformSafePosClickScreen(screenX, screenY, btn := "Left") {
    global targetPosHwnd
    CoordMode("Mouse", "Screen")
    if (!targetPosHwnd || !WinActive("ahk_id " . targetPosHwnd)) {
        if (!EnsureTargetWindowActive())
            return false
    }

    MouseMove(screenX, screenY, 0)
    Sleep(25)
    Click(btn . " Down")
    Sleep(45)
    Click(btn . " Up")
    Sleep(30)
    return true
}

ExecuteSingleMacroLine(line, logFileHandle := "", &sentinelTriggered := false, &errR := "", &errD := "", &errSnippet := "") {
    global speedMultiplier, targetPosHwnd, targetWinTitle, lastActionLogPos
    keyDelay := 25

    if (SubStr(line, 1, 6) == "Sleep,") {
        payload := Trim(SubStr(line, 7))
        rawSleep := RegExMatch(payload, "(\d+)", &mMs) ? Integer(mMs[1]) : 50
        actualSleep := Integer(rawSleep * speedMultiplier)
        waitPrompt := RegExMatch(payload, 'WaitPrompt="([^"]+)"', &mWp) ? mWp[1] : ""

        if (waitPrompt != "" && logFileHandle) {
            SmartWaitForXstorePrompt(logFileHandle, waitPrompt, actualSleep, &sentinelTriggered, &errR, &errD, &errSnippet)
        } else {
            InterruptibleSleepWithSentinel(actualSleep, logFileHandle, &sentinelTriggered, &errR, &errD, &errSnippet)
        }
    } else if (SubStr(line, 1, 11) == "WaitPrompt," || SubStr(line, 1, 8) == "WaitLog,") {
        payload := Trim(SubStr(line, InStr(line, ",") + 1))
        promptCode := RegExMatch(payload, '^([^,]+)', &mP) ? Trim(StrReplace(mP[1], '"', '')) : payload
        timeoutMs := RegExMatch(payload, 'i)Timeout=\s*(\d+)', &mTo) ? Integer(mTo[1]) : 5000
        SmartWaitForXstorePrompt(logFileHandle, promptCode, timeoutMs, &sentinelTriggered, &errR, &errD, &errSnippet)
    } else if (SubStr(line, 1, 5) == "Send,") {
        cmd := Trim(SubStr(line, 6))
        if (cmd != "") {
            preSendLogPos := -1
            if (logFileHandle && IsObject(logFileHandle)) {
                try {
                    preSendLogPos := logFileHandle.Length
                    lastActionLogPos := preSendLogPos
                }
            }
            SetStoreCapsLockMode(true)
            SetKeyDelay(35, 35)

            if (RegExMatch(cmd, "^[A-Za-z0-9]$")) {
                ; Tecla individual de atajo Xstore (ej. 'n' para No en APPLY_TRANS_TAX_EXEMPTION, '5' en menu, 's'/'y' para Si):
                ; Enviar Virtual Keycode real (WM_KEYDOWN + WM_KEYUP) porque Java Swing ignora paquetes Unicode {Text} en botones modales
                k := StrLower(cmd)
                SendEvent("{" . k . " down}")
                Sleep(45)
                SendEvent("{" . k . " up}")

                ; Si es un atajo de decision en modal ('n', 's', 'y') y Xstore no registro el [Action] en 240ms, reintentar una vez
                if ((k == "n" || k == "s" || k == "y") && logFileHandle && preSendLogPos >= 0) {
                    Sleep(240)
                    if (!VerifyXstoreActionLogged(logFileHandle, preSendLogPos)) {
                        SendEvent("{" . k . " down}")
                        Sleep(55)
                        SendEvent("{" . k . " up}")
                    }
                }
            } else if (RegExMatch(cmd, "^\{.+\}$") || RegExMatch(cmd, "^[\^\+\!\#]+\{?[A-Za-z0-9]+\}?$")) {
                SendEvent(cmd)
            } else {
                ; Enviar texto o SKU mediante Virtual Keycodes reales (escapando solo modificadores AHK)
                safeKeys := StrReplace(cmd, "{{}", "`vLBRACE`v")
                safeKeys := StrReplace(safeKeys, "{}}", "`vRBRACE`v")
                safeKeys := RegExReplace(safeKeys, "([\!\+\^\#])", "{$1}")
                safeKeys := StrReplace(safeKeys, "`vLBRACE`v", "{{}")
                safeKeys := StrReplace(safeKeys, "`vRBRACE`v", "{}}")
                SendEvent(safeKeys)
            }
            InterruptibleSleep(keyDelay)
        }
    } else if (SubStr(line, 1, 10) == "UIA_Click,") {
        rawPayload := Trim(SubStr(line, 11))
        targetName := RegExMatch(rawPayload, 'Name="([^"]+)"', &mName) ? mName[1] : ""
        targetId := RegExMatch(rawPayload, 'AutomationId="([^"]+)"', &mId) ? mId[1] : ""
        xstoreAction := RegExMatch(rawPayload, 'XstoreAction="([^"]+)"', &mAct) ? mAct[1] : ""
        rawX := RegExMatch(rawPayload, 'i)Fallback=\s*(-?\d+)', &mX) ? Integer(mX[1]) : 0
        rawY := RegExMatch(rawPayload, 'i)Fallback=\s*-?\d+\s*,\s*(-?\d+)', &mY) ? Integer(mY[1]) : 0

        fallbackX := rawX
        fallbackY := rawY
        ResolveProportionalCoords(rawPayload, rawX, rawY, &fallbackX, &fallbackY)

        preClickLogPos := -1
        if (logFileHandle && IsObject(logFileHandle)) {
            try {
                preClickLogPos := logFileHandle.Length
                lastActionLogPos := preClickLogPos
            }
        }

        clicked := false
        isWindowName := (targetName != "" && (targetName == targetWinTitle || InStr(targetWinTitle, targetName) || InStr(targetName, "Oracle Retail") || InStr(targetName, "Point of Service") || targetName == "Xstore"))

        ; Si XstoreAction existe (ej. "Aceptar [ACCEPT]") pero el Name de UIA contradice la accion (ej. Name="Cancelar"),
        ; ignorar la busqueda UIA engañosa de Java Swing y usar directamente la coordenada Fallback exacta.
        nameContradictsAction := (xstoreAction != "" && targetName != "" && !InStr(xstoreAction, targetName))

        if (!isWindowName && !nameContradictsAction && (fallbackX == 0 && fallbackY == 0) && targetPosHwnd && (targetName != "" || targetId != "")) {
            try {
                xstoreWin := UIA.ElementFromHandle(targetPosHwnd)
                if (xstoreWin) {
                    cond := {}
                    if (targetName != "")
                        cond.Name := targetName
                    if (targetId != "")
                        cond.AutomationId := targetId

                    targetEl := xstoreWin.FindElement(cond)
                    if (targetEl && targetEl.LocalizedControlType != "window" && targetEl.LocalizedControlType != "ventana") {
                        try targetEl.Highlight(-200, "0078D7", 2)
                        try {
                            rect := targetEl.BoundingRectangle
                            if (rect && rect.w > 0 && rect.h > 0) {
                                PerformSafePosClickScreen(rect.x + (rect.w // 2), rect.y + (rect.h // 2), "Left")
                                clicked := true
                            } else {
                                targetEl.Click("left")
                                clicked := true
                            }
                        } catch {
                            try {
                                targetEl.Click()
                                clicked := true
                            }
                        }
                    }
                }
            }
        }

        if (!clicked && (fallbackX != 0 || fallbackY != 0)) {
            PerformSafePosClick(fallbackX, fallbackY, "Left")
        }

        ; Si el paso tiene XstoreAction y Xstore no registro el clic en 180ms, reintentar clic una vez
        if (xstoreAction != "" && logFileHandle && (fallbackX != 0 || fallbackY != 0)) {
            Sleep(180)
            if (!VerifyXstoreActionLogged(logFileHandle, preClickLogPos, xstoreAction)) {
                PerformSafePosClick(fallbackX, fallbackY, "Left")
            }
        }
        InterruptibleSleep(keyDelay)
    } else if (SubStr(line, 1, 11) == "MouseClick," || SubStr(line, 1, 6) == "Click,") {
        isMouseClick := (SubStr(line, 1, 11) == "MouseClick,")
        rawArgs := isMouseClick ? SubStr(line, 12) : Trim(SubStr(line, 7))
        args := StrSplit(rawArgs, ",")
        btn := "Left"
        rawX := 0
        rawY := 0
        if (isMouseClick) {
            btn := (args.Length >= 1) ? Trim(args[1]) : "Left"
            rawX := (args.Length >= 2) ? Integer(RegExReplace(args[2], "[^\d-]", "")) : 0
            rawY := (args.Length >= 3) ? Integer(RegExReplace(args[3], "[^\d-]", "")) : 0
        } else {
            if (args.Length == 2) {
                rawX := Integer(RegExReplace(args[1], "[^\d-]", ""))
                rawY := Integer(RegExReplace(args[2], "[^\d-]", ""))
            } else if (args.Length >= 3) {
                btn := Trim(args[1])
                rawX := Integer(RegExReplace(args[2], "[^\d-]", ""))
                rawY := Integer(RegExReplace(args[3], "[^\d-]", ""))
            }
        }

        clickX := rawX
        clickY := rawY
        ResolveProportionalCoords(line, rawX, rawY, &clickX, &clickY)

        PerformSafePosClick(clickX, clickY, btn)
        InterruptibleSleep(keyDelay)
    }
}

PerformPosSelfHealing(logFileHandle) {
    EnsureTargetWindowActive()
    ShowFloatingMiniHUD("[AUTO-RECUPERANDO XSTORE POS]", "Cerrando modal de error en caja...", "Continuando con el siguiente ciclo del lote")
    SoundBeep(600, 120)
    Sleep(300)
    ; Los dialogos modales de error en Xstore (ERROR_WITH_INFO, VALIDATION_ERROR_MESSAGE) se cierran con Enter o Escape
    SendEvent("{Enter}")
    Sleep(450)
    SendEvent("{Escape}")
    Sleep(550)
    if (logFileHandle) {
        try logFileHandle.Seek(0, 2)
    }
}

StartAutomation(startFromStep := 1, *) {
    global isPlaying, isPausedPlay, stopPlayback, isRecording, isCountdownActive, ddlMacros, macroFolder, reportsFolder
    global autoTotalCycles, autoCurrentCycle, autoSuccessCount, autoFailCount, autoRecoveredCount
    global autoStartTime, autoCurrentCSV, autoCurrentHTML, autoAuditRecords, speedMultiplier, progBar, txtProgress
    global btnPlay, btnPausePlay, btnRecord, radModeSingle, radModeBatch, edtReps, chkInfinite, edtLoopDelay
    global sentinelEnabled, selfHealEnabled, smartLogSyncEnabled, xstoreLogPath, posLogPath, libraryTransactions
    global edtTargetWin, targetWinTitle, targetPosHwnd, mainGui

    if (Type(startFromStep) != "Integer" || startFromStep < 1)
        startFromStep := 1

    if (isPlaying)
        return

    EnsureRequiredDirectories()

    if (isRecording) {
        MsgBox("Debes guardar o cancelar la grabacion activa antes de iniciar la automatizacion.", "QA POS Automation", "Icon! 262144")
        return
    }

    selectedMacro := ddlMacros.Text
    if (selectedMacro == "" || selectedMacro == "(Sin macros guardadas)") {
        MsgBox("No hay ninguna macro seleccionada.`nGraba una macro primero en la pestaña 'Grabar Macro'.",
            "QA POS Automation", "Iconx 262144")
        return
    }

    fullMacroPath := macroFolder . "\" . selectedMacro
    if (!FileExist(fullMacroPath)) {
        MsgBox("El archivo de macro '" . fullMacroPath . "' no existe.", "QA POS Automation", "Iconx 262144")
        RefreshMacroList()
        return
    }

    if (chkInfinite.Value == 1) {
        totalReps := 999999
    } else if (radModeBatch.Value == 1) {
        rawReps := RegExReplace(edtReps.Text, "[^\d]", "")
        numInput := (rawReps != "") ? Integer(rawReps) : 1
        totalReps := (numInput > 0) ? numInput : 1
    } else {
        totalReps := 1
    }

    rawDelay := RegExReplace(edtLoopDelay.Text, "[^\d]", "")
    loopDelay := (rawDelay != "") ? Integer(rawDelay) : 1000

    autoTotalCycles := totalReps
    autoCurrentCycle := 0
    autoSuccessCount := 0
    autoFailCount := 0
    autoRecoveredCount := 0
    autoAuditRecords := []
    autoStartTime := A_TickCount
    isPlaying := true
    isPausedPlay := false
    stopPlayback := false
    cycleDurationSec := 0.0

    logFileHandle := ""
    sentinelTriggered := false
    sentinelReason := ""
    sentinelDetail := ""
    sentinelSnippet := ""
    lastErrorScreenshot := ""

    if (FileExist(xstoreLogPath)) {
        try {
            logFileHandle := FileOpen(xstoreLogPath, "r-d", "UTF-8")
            if (logFileHandle)
                logFileHandle.Seek(0, 2)
        } catch {
            logFileHandle := ""
        }
    }

    stampStr := FormatTime(, "yyyyMMdd_HHmmss")
    cleanMacroBase := RegExReplace(selectedMacro, "\.txt$", "")
    csvName := "Registro_Transacciones_" . stampStr . "_" . cleanMacroBase . ".csv"
    htmlName := "Reporte_Dashboard_" . stampStr . "_" . cleanMacroBase . ".html"
    autoCurrentCSV := reportsFolder . "\" . csvName
    autoCurrentHTML := reportsFolder . "\" . htmlName

    csvHeader := "Ciclo,Trans_Seq,Tipo_Doc,Cliente_NIT,Total,Fecha_Inicio,Fecha_Fin,Duracion_Seg,Duracion_Ms,Estado,Macro`n"
    try FileAppend(csvHeader, autoCurrentCSV, "UTF-8")

    btnPlay.Enabled := false
    btnPausePlay.Enabled := true
    btnPausePlay.Text := "PAUSAR`n(Ctrl+P)"
    btnRecord.Enabled := false
    progBar.Value := 0

    UpdateStatus("Validando y anclando terminal POS (Xstore)...")
    targetHwnd := EnsureTargetWindowActive()
    if (!targetHwnd) {
        MsgBox("No se pudo detectar ni anclar la ventana de la terminal POS ('" . edtTargetWin.Text . "').`n`nPor seguridad transaccional, la macro no se iniciara para evitar enviar pulsaciones a otra aplicacion.`nVerifica que Xstore este abierto y visible antes de comenzar.",
            "Seguridad POS - Ventana no detectada", "Iconx 262144")
        if (logFileHandle) {
            try logFileHandle.Close()
            logFileHandle := ""
        }
        isPlaying := false
        ResetUI()
        UpdateStatus("Cancelado: ventana POS no detectada")
        return
    }

    if (!WinActive("ahk_id " . targetHwnd)) {
        WinActivate("ahk_id " . targetHwnd)
        WinWaitActive("ahk_id " . targetHwnd, , 2)
    }

    ; Activar modo translucido en la ventana principal durante la ejecucion igual que en grabacion
    try WinSetTransparent(150, mainGui)

    UpdateStatus("Terminal POS anclada. Iniciando en 3 segundos...")
    isCountdownActive := true
    loop 3 {
        if (stopPlayback)
            break
        secRemaining := 4 - A_Index
        startSubMsg := (startFromStep > 1) ? ("Iniciando desde el Paso #" . startFromStep . "...") : "Iniciando despacho en Xstore... Suelta teclado y raton"
        ShowCountdownHUD("XSTORE ANCLADO Y VALIDADO", secRemaining, "Terminal: " . targetWinTitle . "`n" . startSubMsg)
        SoundBeep(700 + (3 - secRemaining) * 120, 150)

        if (!WinActive("ahk_id " . targetHwnd)) {
            EnsureTargetWindowActive()
        }
        InterruptibleSleep(1000)
    }
    isCountdownActive := false
    HideCountdownHUD()

    if (stopPlayback) {
        HideFloatingMiniHUD()
        if (logFileHandle) {
            try logFileHandle.Close()
            logFileHandle := ""
        }
        isPlaying := false
        ResetUI()
        UpdateStatus("Cancelado por el usuario antes de iniciar")
        return
    }

    if (totalReps == 1)
        UpdateStatus("Ejecutando 1 Transaccion con '" . selectedMacro . "'")
    else if (chkInfinite.Value == 1)
        UpdateStatus("Automatizando transacciones en modo continuo")
    else
        UpdateStatus("Automatizando lote de " . totalReps . " transacciones...")

    SetTimer(UpdateLiveMetricsHUD, 300)

    try {
        fileLines := FileRead(fullMacroPath, "UTF-8")
        executableLines := []
        loop parse, fileLines, "`n", "`r" {
            l := Trim(A_LoopField)
            if (l != "" && SubStr(l, 1, 1) != ";")
                executableLines.Push(l)
        }
        totalStepsCount := executableLines.Length

        loop totalReps {
            if (stopPlayback)
                break

            autoCurrentCycle := A_Index
            cycleStartTick := A_TickCount
            cycleStartTimeStr := FormatTime(, "yyyy-MM-dd HH:mm:ss")
            sentinelTriggered := false
            sentinelReason := ""
            sentinelDetail := ""
            sentinelSnippet := ""
            cycleScreenshot := ""

            cycleXstoreStartPos := 0
            if (logFileHandle && IsObject(logFileHandle)) {
                try cycleXstoreStartPos := logFileHandle.Length
            }

            cyclePosLogStartPos := 0
            if (posLogPath != "" && FileExist(posLogPath)) {
                try cyclePosLogStartPos := FileGetSize(posLogPath)
            }

            while (isPausedPlay && !stopPlayback) {
                Sleep(100)
            }

            if (stopPlayback)
                break

            EnsureTargetWindowActive()

            firstStepThisCycle := (autoCurrentCycle == 1) ? startFromStep : 1

            for stepIdx, line in executableLines {
                if (stepIdx < firstStepThisCycle)
                    continue

                if (stopPlayback)
                    break

                while (isPausedPlay && !stopPlayback) {
                    Sleep(100)
                }

                ; Guardian de Foco POS: validar que Xstore siga en primer plano antes de enviar teclas
                if (targetPosHwnd && !WinActive("ahk_id " . targetPosHwnd)) {
                    EnsureTargetWindowActive()
                    if (!WinWaitActive("ahk_id " . targetPosHwnd, , 1)) {
                        isPausedPlay := true
                        btnPausePlay.Text := "REANUDAR`n(Ctrl+P)"
                        try WinSetTransparent(220, mainGui)
                        UpdateStatus("PAUSA DE SEGURIDAD: Foco en Xstore perdido. Haz clic en Xstore y presiona Ctrl+P")
                        ShowFloatingMiniHUD("[PAUSA POR FOCO PERDIDO]", "Paso " . Format("{:02}", stepIdx) . "/" . Format("{:02}", totalStepsCount), "Haz clic en Xstore y presiona Ctrl+P para reanudar")
                        SoundBeep(400, 250)
                        while (isPausedPlay && !stopPlayback) {
                            Sleep(100)
                        }
                        if (!stopPlayback)
                            try WinSetTransparent(150, mainGui)
                    }
                }

                cycleLabel := (chkInfinite.Value == 1) ? ("CICLO #" . autoCurrentCycle) : ("CICLO " . autoCurrentCycle . "/" . totalReps)
                stepHuman := FormatStepLineForHUD(line)
                ShowFloatingMiniHUD("[EJECUTANDO] " . cycleLabel . " - PASO " . Format("{:02}", stepIdx) . "/" . Format("{:02}", totalStepsCount),
                    stepHuman, "Ctrl+P: Pausar | Ctrl+M: Parada de Emergencia")

                errR := "", errD := "", errSnip := ""
                ExecuteSingleMacroLine(line, logFileHandle, &sentinelTriggered, &errR, &errD, &errSnip)

                if (sentinelTriggered) {
                    sentinelReason := errR
                    sentinelDetail := errD
                    sentinelSnippet := errSnip
                    cycleScreenshot := CaptureWindowScreenshot(edtTargetWin.Text, autoCurrentCycle)
                    lastErrorScreenshot := cycleScreenshot
                    SoundBeep(450, 180)
                    SoundBeep(350, 350)
                    break
                }

                if (sentinelEnabled && logFileHandle && !stopPlayback) {
                    if (CheckXstoreSentinel(logFileHandle, &errR, &errD, &errSnip)) {
                        sentinelTriggered := true
                        sentinelReason := errR
                        sentinelDetail := errD
                        sentinelSnippet := errSnip
                        stopPlayback := true
                        cycleScreenshot := CaptureWindowScreenshot(edtTargetWin.Text, autoCurrentCycle)
                        lastErrorScreenshot := cycleScreenshot
                        SoundBeep(450, 180)
                        SoundBeep(350, 350)
                        break
                    }
                }
            }

            cycleEndTick := A_TickCount
            cycleEndTimeStr := FormatTime(, "yyyy-MM-dd HH:mm:ss")
            cycleDurationMs := cycleEndTick - cycleStartTick
            cycleDurationSec := Round(cycleDurationMs / 1000, 2)

            ; Breve espera de sincronizacion de escritura en disco para capturar PosLog.xml y xstore.log
            Sleep(180)
            cycleTicket := CaptureLatestTransactionTicket(logFileHandle, cycleXstoreStartPos, posLogPath, cyclePosLogStartPos)

            if (sentinelTriggered) {
                if (selfHealEnabled && totalReps > 1 && autoCurrentCycle < totalReps) {
                    autoRecoveredCount++
                    autoFailCount++
                    logStatus := "RECUPERADO_CENTINELA (" . sentinelReason . " - " . sentinelDetail . ")"
                    PerformPosSelfHealing(logFileHandle)
                    sentinelTriggered := false
                    stopPlayback := false
                } else {
                    autoFailCount++
                    logStatus := "FALLO_CENTINELA (" . sentinelReason . " - " . sentinelDetail . ")"
                }
            } else if (stopPlayback) {
                autoFailCount++
                logStatus := "INTERRUMPIDO"
            } else {
                autoSuccessCount++
                logStatus := "COMPLETADO"
            }

            seqCol := (IsObject(cycleTicket) && cycleTicket.HasOwnProp("transSeq") && cycleTicket.transSeq != "") ? cycleTicket.transSeq : "-"
            docCol := (IsObject(cycleTicket) && cycleTicket.HasOwnProp("docType") && cycleTicket.docType != "") ? StrReplace(cycleTicket.docType, ",", " ") : "-"
            nitCol := (IsObject(cycleTicket) && cycleTicket.HasOwnProp("customerDocNumber") && cycleTicket.customerDocNumber != "") ? StrReplace(cycleTicket.customerDocNumber, ",", " ") : "-"
            totCol := (IsObject(cycleTicket) && cycleTicket.HasOwnProp("grandTotal")) ? Format("{:.2f}", cycleTicket.grandTotal) : "0.00"

            csvRow := autoCurrentCycle . "," . seqCol . "," . docCol . "," . nitCol . "," . totCol . ","
                . cycleStartTimeStr . "," . cycleEndTimeStr . "," . cycleDurationSec . "," . cycleDurationMs . ","
                . StrReplace(logStatus, ",", ";") . "," . selectedMacro . "`n"
            try FileAppend(csvRow, autoCurrentCSV, "UTF-8")

            autoAuditRecords.Push({
                cycle: autoCurrentCycle,
                startTime: cycleStartTimeStr,
                endTime: cycleEndTimeStr,
                durationSec: cycleDurationSec,
                durationMs: cycleDurationMs,
                status: logStatus,
                macro: selectedMacro,
                screenshot: cycleScreenshot,
                reason: sentinelReason,
                detail: sentinelDetail,
                logSnippet: sentinelSnippet,
                ticket: cycleTicket
            })

            if (!stopPlayback && autoCurrentCycle < totalReps) {
                InterruptibleSleep(loopDelay)
            }
        }
    } catch Error as err {
        UpdateStatus("Error durante ejecucion: " . err.Message)
        MsgBox("Error inesperado en la reproduccion de la macro:`n" . err.Message, "Error de Automatizacion", "Iconx 262144")
    } finally {
        if (logFileHandle) {
            try logFileHandle.Close()
            logFileHandle := ""
        }
        try WinSetTransparent("Off", mainGui)
        HideFloatingMiniHUD()
        isPlaying := false
        isPausedPlay := false
        SetTimer(UpdateLiveMetricsHUD, 0)
        UpdateLiveMetricsHUD()
        GenerateHTMLDashboardReport(selectedMacro)
        UpdateReportsTabSummary()
        RefreshLibraryTransactionsView()
        ResetUI()
    }

    if (sentinelTriggered) {
        UpdateStatus("Detenido por Centinela: " . SubStr(sentinelReason, 1, 35))
        msgText := "El Centinela Xstore detecto una condicion de fallo o popup inesperado en caja.`n`n"
        msgText .= "Transaccion: " . autoCurrentCycle . " de " . totalReps . "`n"
        msgText .= "Motivo: " . sentinelReason . "`n"
        msgText .= "Detalle: " . sentinelDetail . "`n`n"
        if (lastErrorScreenshot != "")
            msgText .= "Captura de pantalla guardada en:`n" . lastErrorScreenshot . "`n`n"
        msgText .= "Dashboard HTML Forense y CSV generados en la carpeta Reports."
        MsgBox(msgText, "Alerta Centinela Xstore", "Iconx 262144")
    } else if (stopPlayback) {
        UpdateStatus("Automatizacion detenida por el usuario")
        SoundBeep(500, 200)
        MsgBox("Ejecucion detenida en la transaccion " . autoCurrentCycle . " de " . totalReps . ".`n`nDashboard HTML y CSV guardados en:`n" . autoCurrentHTML,
            "QA POS Automation", "Icon! 262144")
    } else {
        UpdateStatus("Automatizacion completada exitosamente")
        SoundBeep(1000, 250)
        if (totalReps == 1) {
            lastSeqMsg := ""
            if (autoAuditRecords.Length > 0 && IsObject(autoAuditRecords[1].ticket) && autoAuditRecords[1].ticket.transSeq != "") {
                t := autoAuditRecords[1].ticket
                lastSeqMsg := "`nTransaccion POS: #" . t.transSeq . " (" . t.docType . " - " . t.currency . " " . Format("{:.2f}", t.grandTotal) . ")"
            }
            MsgBox("Transaccion completada exitosamente en la terminal POS.`n`nMacro: " . selectedMacro . "`nDuracion: " . cycleDurationSec . "s" . lastSeqMsg,
                "QA POS Automation", "Iconi 262144")
        } else {
            healExtra := (autoRecoveredCount > 0) ? ("`nAuto-Recuperadas por Centinela: " . autoRecoveredCount) : ""
            MsgBox("Automatizacion de lote completada.`n`nExitosas: " . autoSuccessCount . " de " . totalReps . healExtra . "`nMacro: " . selectedMacro . "`n`nPuedes inspeccionar los comprobantes y el Dashboard en la pestaña 'Biblioteca'.",
                "QA POS Automation", "Iconi 262144")
        }
    }
}

FormatStepLineForHUD(line) {
    if (SubStr(line, 1, 6) == "Sleep,") {
        val := Trim(SubStr(line, 7))
        return GetStepHumanDescription("Pausa (ms)", val)
    } else if (SubStr(line, 1, 11) == "WaitPrompt," || SubStr(line, 1, 8) == "WaitLog,") {
        val := Trim(SubStr(line, InStr(line, ",") + 1))
        return GetStepHumanDescription("Esperar Prompt (Log)", val)
    } else if (SubStr(line, 1, 5) == "Send,") {
        cmd := Trim(SubStr(line, 6))
        t := RegExMatch(cmd, "^\{.+\}$") ? "Tecla Especial" : "Texto / SKU"
        return GetStepHumanDescription(t, cmd)
    } else if (SubStr(line, 1, 10) == "UIA_Click,") {
        return GetStepHumanDescription("Clic UIA (Boton)", Trim(SubStr(line, 11)))
    } else if (SubStr(line, 1, 11) == "MouseClick," || SubStr(line, 1, 6) == "Click,") {
        return GetStepHumanDescription("Clic Raton", Trim(SubStr(line, InStr(line, ",") + 1)))
    }
    return SubStr(line, 1, 45)
}

TogglePauseAutomation(*) {
    global isPlaying, isPausedPlay, btnPausePlay, autoCurrentCycle, autoTotalCycles, mainGui
    if (!isPlaying)
        return

    isPausedPlay := !isPausedPlay
    if (isPausedPlay) {
        btnPausePlay.Text := "REANUDAR`n(Ctrl+P)"
        try WinSetTransparent(220, mainGui)
        UpdateStatus("Transaccion pausada. Presiona Ctrl+P para reanudar")
        ShowFloatingMiniHUD("[AUTOMATIZACION EN PAUSA]", "Ciclo " . autoCurrentCycle . " de " . autoTotalCycles, "Presiona Ctrl+P para reanudar o Ctrl+M para detener")
    } else {
        btnPausePlay.Text := "PAUSAR`n(Ctrl+P)"
        try WinSetTransparent(150, mainGui)
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

InterruptibleSleepWithSentinel(durationMs, logHandle, &sentinelTriggered, &errR, &errD, &errSnippet) {
    global stopPlayback, isPausedPlay, sentinelEnabled
    step := 25
    elapsed := 0
    lastSentinelCheck := 0
    while (elapsed < durationMs) {
        if (stopPlayback)
            break
        while (isPausedPlay && !stopPlayback) {
            Sleep(50)
        }
        sleepTime := Min(step, durationMs - elapsed)
        Sleep(sleepTime)
        elapsed += sleepTime

        if (sentinelEnabled && logHandle && (elapsed - lastSentinelCheck >= 150)) {
            lastSentinelCheck := elapsed
            if (CheckXstoreSentinel(logHandle, &errR, &errD, &errSnippet)) {
                sentinelTriggered := true
                stopPlayback := true
                break
            }
        }
    }
}

EmergencyStop(*) {
    global stopPlayback, isPlaying, isRecording, isCountdownActive
    HideCountdownHUD()
    HideFloatingMiniHUD()
    if (isPlaying) {
        stopPlayback := true
        ResetUI()
        UpdateStatus("Deteniendo ejecucion de transacciones...")
    } else if (isRecording || isCountdownActive) {
        CancelRecording()
    } else {
        ResetUI()
        UpdateStatus("Listo para automatizar transacciones en terminal POS")
    }
}

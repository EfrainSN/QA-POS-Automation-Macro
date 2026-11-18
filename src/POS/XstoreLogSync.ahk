; ==============================================================================
; MODULE: src\POS\XstoreLogSync.ahk
; PURPOSE: Sincronizacion deterministica con xstore.log (WaitPrompt y [Action])
;          optimizada para soportar logs DEBUG de gran volumen (400MB+)
; ==============================================================================

OpenRecordingLogMonitor() {
    global recLogHandle, xstoreLogPath, lastDetectedLogPrompt, lastRecordedClickIdx
    CloseRecordingLogMonitor()
    lastDetectedLogPrompt := ""
    lastRecordedClickIdx := 0
    if (FileExist(xstoreLogPath)) {
        try {
            recLogHandle := FileOpen(xstoreLogPath, "r-d", "UTF-8")
            if (recLogHandle)
                recLogHandle.Seek(0, 2)
        } catch {
            recLogHandle := ""
        }
    }
}

CloseRecordingLogMonitor() {
    global recLogHandle
    SetTimer(EnrichLastClickFromXstoreLog, 0)
    if (recLogHandle) {
        try recLogHandle.Close()
        recLogHandle := ""
    }
}

HarvestLogPromptBeforeStep() {
    global recLogHandle, lastDetectedLogPrompt
    if (!recLogHandle)
        return lastDetectedLogPrompt

    try {
        if (!recLogHandle.AtEOF && recLogHandle.Length > recLogHandle.Pos) {
            diff := recLogHandle.Length - recLogHandle.Pos
            ; Ventana de 256 KB para no perder Prompts cuando el POS vuelca miles de lineas DEBUG SQL
            if (diff > 262144)
                recLogHandle.Seek(-262144, 2)
            rawChunk := recLogHandle.Read()
            chunk := StripDebugSqlLines(rawChunk)

            pos := 1
            while RegExMatch(chunk, "\[(?:Prompt|Form)\]\s+([A-Za-z0-9_\.]+)", &mP, pos) {
                pCode := Trim(mP[1])
                if (pCode != "" && !InStr(pCode, "ERROR"))
                    lastDetectedLogPrompt := pCode
                pos := mP.Pos + mP.Len
            }
        }
    }
    pOut := lastDetectedLogPrompt
    lastDetectedLogPrompt := ""
    return pOut
}

EnrichLastClickFromXstoreLog() {
    global isRecording, recLogHandle, macroBuffer, lastRecordedClickIdx, lastDetectedLogPrompt
    if (!isRecording || !recLogHandle || lastRecordedClickIdx <= 0 || lastRecordedClickIdx > macroBuffer.Length)
        return

    try {
        if (recLogHandle.AtEOF || recLogHandle.Length <= recLogHandle.Pos)
            return

        diff := recLogHandle.Length - recLogHandle.Pos
        if (diff > 262144)
            recLogHandle.Seek(-262144, 2)

        rawChunk := recLogHandle.Read()
        if (rawChunk == "")
            return

        chunk := StripDebugSqlLines(rawChunk)

        detectedAction := ""
        if RegExMatch(chunk, "\[Action\]\s*<click>\s*->\s*([^\r\n:]+?)\s*::", &mAct) {
            detectedAction := Trim(mAct[1])
        }

        pos := 1
        while RegExMatch(chunk, "\[(?:Prompt|Form)\]\s+([A-Za-z0-9_\.]+)", &mP, pos) {
            pCode := Trim(mP[1])
            if (pCode != "" && !InStr(pCode, "ERROR"))
                lastDetectedLogPrompt := pCode
            pos := mP.Pos + mP.Len
        }

        if (detectedAction != "") {
            cleanAct := StrReplace(detectedAction, '"', '')
            origLine := macroBuffer[lastRecordedClickIdx]
            if (!InStr(origLine, "XstoreAction=")) {
                ; Si el log de Xstore nos da el nombre real del boton (ej. "Aceptar [ACCEPT]"), corregir el Name de UIA si era distinto (ej. Name="Cancelar")
                actLabel := Trim(RegExReplace(cleanAct, "\[.*\]", ""))
                if (actLabel != "" && RegExMatch(origLine, 'Name="([^"]+)"', &mOldName)) {
                    if (mOldName[1] != actLabel && !InStr(mOldName[1], "Oracle Retail")) {
                        origLine := StrReplace(origLine, 'Name="' . mOldName[1] . '"', 'Name="' . actLabel . '"', , , 1)
                    }
                }
                enrichedLine := origLine . ', XstoreAction="' . cleanAct . '"'
                macroBuffer[lastRecordedClickIdx] := enrichedLine
                RebuildPreviewFromBuffer()
                ShowFloatingMiniHUD("GRABANDO EN VIVO", "Boton Xstore: " . cleanAct, "Pasos: " . macroBuffer.Length . " | Ctrl+M: Terminar")
            }
        }
    }
}

VerifyXstoreActionLogged(logHandle, startPos, expectedAction := "") {
    if (!logHandle || startPos < 0)
        return true

    savedPos := logHandle.Pos
    try {
        if (logHandle.Length <= startPos)
            return false
        seekFrom := Max(startPos, logHandle.Length - 262144)
        logHandle.Seek(seekFrom, 0)
        newText := logHandle.Read()
        logHandle.Seek(savedPos, 0)

        if (InStr(newText, "[Action]") || InStr(newText, "OPCHAIN_FLOW"))
            return true
    } catch {
        try logHandle.Seek(savedPos, 0)
    }
    return false
}

SmartWaitForXstorePrompt(logHandle, expectedPrompt, baseDurationMs, &sentinelTriggered, &errR, &errD, &errSnippet) {
    global stopPlayback, isPausedPlay, smartLogSyncEnabled, sentinelEnabled, lastActionLogPos
    expectedPrompt := Trim(expectedPrompt)
    if (!smartLogSyncEnabled || !logHandle || expectedPrompt == "") {
        InterruptibleSleepWithSentinel(baseDurationMs, logHandle, &sentinelTriggered, &errR, &errD, &errSnippet)
        return
    }

    maxTimeoutMs := Max(Integer(baseDurationMs * 2.2), 6000)
    startWait := A_TickCount
    promptFound := false

    searchPos := (lastActionLogPos > 0 && lastActionLogPos <= logHandle.Length) ? lastActionLogPos : logHandle.Pos

    ShowFloatingMiniHUD("ESPERANDO PROMPT XSTORE", "Log: [" . expectedPrompt . "]", "Sync activa (Timeout: " . Round(maxTimeoutMs / 1000, 1) . "s)")

    while ((A_TickCount - startWait) < maxTimeoutMs) {
        if (stopPlayback)
            break
        while (isPausedPlay && !stopPlayback) {
            Sleep(50)
        }

        if (sentinelEnabled && logHandle) {
            if (CheckXstoreSentinel(logHandle, &errR, &errD, &errSnippet)) {
                sentinelTriggered := true
                stopPlayback := true
                return
            }
        }

        try {
            curPos := logHandle.Pos
            totalLen := logHandle.Length
            if (totalLen > searchPos) {
                ; Ventana de 512 KB para evitar que rafagas de DEBUG SQL desplacen el Prompt buscado
                if (totalLen - searchPos > 524288)
                    searchPos := totalLen - 524288
                logHandle.Seek(searchPos, 0)
                recentChunk := logHandle.Read()
                logHandle.Seek(curPos, 0)
                if (RegExMatch(recentChunk, "i)\[(?:Prompt|Form)\]\s*(?:->\s*)?\Q" . expectedPrompt . "\E\b") || InStr(recentChunk, "[Prompt] " . expectedPrompt)) {
                    promptFound := true
                    lastActionLogPos := totalLen
                    break
                }
            }
        }

        if ((A_TickCount - startWait) >= baseDurationMs && logHandle.Length == searchPos) {
            break
        }

        Sleep(40)
    }

    if (promptFound && !stopPlayback) {
        ; Esperar 350ms tras detectarse el [Prompt] en el log para que Java Swing (AWT-EventQueue-0)
        ; termine de renderizar y otorgar foco de teclado al dialogo modal (ej. APPLY_TRANS_TAX_EXEMPTION)
        Sleep(350)
    }
}

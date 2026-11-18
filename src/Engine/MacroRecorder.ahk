; ==============================================================================
; MODULE: src\Engine\MacroRecorder.ahk
; PURPOSE: Motor de grabación en directo con captura de Portapapeles (Copy/Paste),
;          botones [Action] y [Prompt] de xstore.log y coordenadas proporcionales
; ==============================================================================

CleanClipboardText(rawText) {
    if (rawText == "")
        return ""
    ; Eliminar saltos de línea finales que agregan Excel o Bloc de Notas al copiar con el ratón
    cleaned := RegExReplace(rawText, "[\r\n]+$", "")
    cleaned := RegExReplace(cleaned, "^[\r\n]+", "")
    ; Si contiene múltiples líneas internas, convertirlas en espacio simple
    cleaned := RegExReplace(cleaned, "[\r\n]+", " ")
    return Trim(cleaned)
}

OnClipboardChangedDuringRec(dataType) {
    global isRecording, isPausedRec, lastCopiedClipboardText, macroBuffer
    if (!isRecording || isPausedRec)
        return
    if (dataType == 1) {
        try {
            clipVal := CleanClipboardText(A_Clipboard)
            if (clipVal != "") {
                lastCopiedClipboardText := clipVal
                ShowFloatingMiniHUD("[GRABANDO EN VIVO]", "Copiado: " . SubStr(clipVal, 1, 24), "Pegalo en Xstore (Ctrl+V) | Pasos: " . macroBuffer.Length)
            }
        }
    }
}

RecordClipboardPaste(source := "Paste") {
    global isRecording, isPausedRec, firstKeyRecorded, lastTick, textBuffer, macroBuffer
    global lastPasteTick, lastCopiedClipboardText, hadTypedInCurrentField

    if (!isRecording || isPausedRec)
        return

    currentTick := A_TickCount
    ; Debounce de 220ms para evitar duplicados si se dispara por Hotkey (~*^v) y por InputHook simultáneamente
    if (currentTick - lastPasteTick < 220)
        return

    activeHwnd := WinActive("A")
    if (activeHwnd && !IsPosWindow(activeHwnd))
        return

    lastPasteTick := currentTick

    clipText := ""
    try clipText := CleanClipboardText(A_Clipboard)
    if (clipText == "" && lastCopiedClipboardText != "")
        clipText := lastCopiedClipboardText

    if (clipText == "")
        return

    if (!firstKeyRecorded) {
        firstKeyRecorded := true
        lastTick := currentTick
    } else {
        delta := (lastTick > 0) ? (currentTick - lastTick) : 0
        if (textBuffer == "" && delta >= 25) {
            sleepLine := BuildRecordedSleepLine(delta)
            macroBuffer.Push(sleepLine)
            AppendPreviewLine(sleepLine)
        } else if (textBuffer != "") {
            FlushTextBuffer()
        }
        lastTick := currentTick
    }

    textBuffer .= clipText
    hadTypedInCurrentField := true
    FlushTextBuffer()
    ShowFloatingMiniHUD("[GRABANDO EN VIVO]", "Pegado: " . SubStr(clipText, 1, 25), "Pasos: " . macroBuffer.Length . " | Ctrl+M: Terminar")
}

RebuildPreviewFromBuffer() {
    global macroBuffer, edtBufferPreview
    out := "; Grabando en directo (Sincronizado con xstore.log y Portapapeles)...`r`n"
    startIdx := Max(1, macroBuffer.Length - 25)
    loop (macroBuffer.Length - startIdx + 1) {
        idx := startIdx + A_Index - 1
        out .= macroBuffer[idx] . "`r`n"
    }
    try edtBufferPreview.Text := out
}

StartRecording(*) {
    global isRecording, isPausedRec, isPlaying, isCountdownActive, recordingCountdown
    global btnRecord, btnPauseRec, btnSaveRec, btnCancelRec, btnPlay, edtBufferPreview, edtMacroName, mainGui, targetWinTitle

    if (isPlaying) {
        MsgBox("No se puede grabar mientras se esta ejecutando una automatizacion.", "QA POS Automation", "Icon! 262144")
        return
    }

    if (isRecording || isCountdownActive)
        return

    currentName := Trim(edtMacroName.Text)
    if (currentName == "") {
        try edtMacroName.Text := "Transaccion_" . FormatTime(, "yyyyMMdd_HHmmss")
    }

    try edtMacroName.Enabled := false
    btnRecord.Enabled := false
    btnPauseRec.Enabled := false
    btnSaveRec.Enabled := false
    btnCancelRec.Enabled := true
    btnPlay.Enabled := false

    ; 1. Activar fondo translúcido Aero Glass nítido de inmediato
    WinSetTransparent(150, mainGui)

    ; 2. Activar y anclar la ventana de Xstore / POS si existe para ubicar al operador
    EnsureTargetWindowActive()

    ; 3. Iniciar temporizador regresivo de 3 segundos con banner HUD visual
    isCountdownActive := true
    recordingCountdown := 3
    UpdateStatus("PREPARATE... Grabando en 3 segundos (Ubicate en Xstore)")
    edtBufferPreview.Text := "; PREPARATE: Grabando en 3 segundos... Ubicate en la terminal POS.`r`n"

    ShowCountdownHUD("PREPARATE PARA GRABAR MACRO", "3", "Terminal: " . targetWinTitle . "`nPosicionate en la pantalla de Xstore")
    SoundBeep(650, 150)

    SetTimer(RecordingCountdownTick, 1000)
}

RecordingCountdownTick() {
    global recordingCountdown, isCountdownActive, isRecording, isPausedRec, firstKeyRecorded, lastTick, macroBuffer, textBuffer, keyHook
    global btnPauseRec, btnSaveRec, edtBufferPreview, mainGui, targetWinTitle
    global lastCopiedClipboardText, lastPasteTick, hadTypedInCurrentField, pendingRightClickMenu

    if (!isCountdownActive) {
        SetTimer(RecordingCountdownTick, 0)
        HideCountdownHUD()
        return
    }

    recordingCountdown--

    if (recordingCountdown > 0) {
        UpdateStatus("PREPARATE... Grabando en " . recordingCountdown . " segundo" . (recordingCountdown > 1 ? "s" : "") . " (Ubicate en Xstore)")
        edtBufferPreview.Text := "; PREPARATE: Grabando en " . recordingCountdown . " segundo" . (recordingCountdown > 1 ? "s" : "") . "... Ubicate en la terminal POS.`r`n"
        ShowCountdownHUD("PREPARATE PARA GRABAR MACRO", recordingCountdown, "Terminal: " . targetWinTitle . "`nIniciando captura de eventos...")
        SoundBeep(650 + (3 - recordingCountdown) * 130, 150)
    } else {
        SetTimer(RecordingCountdownTick, 0)
        isCountdownActive := false

        ShowCountdownHUD("¡GRABANDO EN DIRECTO!", "REC", "Opera normalmente en la terminal POS")
        SetTimer(HideCountdownHUD, -1000)

        macroBuffer := []
        textBuffer := ""
        isRecording := true
        isPausedRec := false
        firstKeyRecorded := false
        lastTick := 0
        lastPasteTick := 0
        hadTypedInCurrentField := false
        pendingRightClickMenu := false
        try lastCopiedClipboardText := CleanClipboardText(A_Clipboard)
        try OnClipboardChange(OnClipboardChangedDuringRec, 1)

        OpenRecordingLogMonitor()

        edtBufferPreview.Text := "; Grabando pulsaciones, pegado de portapapeles y eventos de Xstore...`r`n"
        SoundBeep(1200, 250)

        ShowFloatingMiniHUD("[GRABANDO MACRO EN VIVO]", "Esperando acciones en Xstore...", "Ctrl+M: Cancelar")

        keyHook := InputHook("V L0")
        keyHook.KeyOpt("{All}", "+N")
        keyHook.OnKeyDown := OnKeyDownHandler
        keyHook.OnChar := OnCharHandler
        keyHook.Start()

        UpdateStatus("GRABANDO EN DIRECTO (Sincronizado con Xstore y Portapapeles)...")
        btnPauseRec.Enabled := true
        btnPauseRec.Text := "Pausar"
        btnSaveRec.Enabled := true
    }
}

TogglePauseRecording(*) {
    global isPausedRec, lastTick, btnPauseRec, edtMacroName, mainGui
    if (!isRecording)
        return

    if (isPausedRec) {
        isPausedRec := false
        lastTick := A_TickCount
        WinSetTransparent(150, mainGui)
        UpdateStatus("GRABANDO EN DIRECTO (Fondo translucido activo)...")
        ShowFloatingMiniHUD("[GRABANDO MACRO EN VIVO]", "Grabacion reanudada", "Ctrl+M: Cancelar")
        btnPauseRec.Text := "Pausar"
        try edtMacroName.Enabled := false
    } else {
        FlushTextBuffer()
        isPausedRec := true
        lastTick := 0
        WinSetTransparent(220, mainGui)
        UpdateStatus("Grabacion en pausa")
        ShowFloatingMiniHUD("[GRABACION EN PAUSA]", "Eventos pausados temporalmente", "Presiona Reanudar en la suite")
        btnPauseRec.Text := "Reanudar"
        try edtMacroName.Enabled := true
    }
}

SaveRecording(*) {
    global isRecording, isPausedRec, isCountdownActive, macroBuffer, macroFolder, ddlMacros, ddlEditMacros, edtMacroName, mainTabs, mainGui

    if (isCountdownActive) {
        isCountdownActive := false
        SetTimer(RecordingCountdownTick, 0)
    }

    if (!isRecording) {
        try OnClipboardChange(OnClipboardChangedDuringRec, 0)
        CloseRecordingLogMonitor()
        HideFloatingMiniHUD()
        WinSetTransparent("Off", mainGui)
        ResetUI()
        return
    }

    StopHook()
    try OnClipboardChange(OnClipboardChangedDuringRec, 0)
    FlushTextBuffer()
    EnrichLastClickFromXstoreLog()
    CloseRecordingLogMonitor()
    HideFloatingMiniHUD()
    isRecording := false
    isPausedRec := false
    try edtMacroName.Enabled := true
    WinSetTransparent("Off", mainGui)

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

        RefreshMacroList(fileName)
        try ddlMacros.Text := fileName
        try ddlEditMacros.Text := fileName
        SaveSettings()

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
    global isRecording, isPausedRec, isCountdownActive, macroBuffer, textBuffer, edtBufferPreview, edtMacroName, mainGui
    HideCountdownHUD()
    HideFloatingMiniHUD()
    try OnClipboardChange(OnClipboardChangedDuringRec, 0)
    CloseRecordingLogMonitor()
    if (isCountdownActive) {
        isCountdownActive := false
        SetTimer(RecordingCountdownTick, 0)
    }

    StopHook()
    isRecording := false
    isPausedRec := false
    try edtMacroName.Enabled := true
    macroBuffer := []
    textBuffer := ""
    edtBufferPreview.Text := "; Grabacion cancelada."
    UpdateStatus("Grabacion cancelada")
    WinSetTransparent("Off", mainGui)
    ResetUI()
}

StopHook() {
    global keyHook
    if (IsObject(keyHook)) {
        try keyHook.Stop()
        keyHook := ""
    }
}

BuildRecordedSleepLine(deltaMs) {
    promptCode := HarvestLogPromptBeforeStep()
    if (promptCode != "" && deltaMs >= 200) {
        return 'Sleep, ' . deltaMs . ', WaitPrompt="' . promptCode . '"'
    }
    return "Sleep, " . deltaMs
}

OnKeyDownHandler(ih, vk, sc) {
    global isRecording, isPausedRec, firstKeyRecorded, lastTick, macroBuffer, textBuffer, specialKeys, hadTypedInCurrentField

    if (!isRecording || isPausedRec)
        return

    activeHwnd := WinActive("A")
    if (activeHwnd && !IsPosWindow(activeHwnd))
        return

    ctrlDown := GetKeyState("Control", "P") || GetKeyState("Control")
    shiftDown := GetKeyState("Shift", "P") || GetKeyState("Shift")

    ; 1. Detectar Pegado por Teclado: Ctrl+V (vk 86) o Shift+Insert (vk 45)
    if ((vk == 86 && ctrlDown) || (vk == 45 && shiftDown)) {
        RecordClipboardPaste("KeyHook")
        return
    }

    ; 2. Ignorar atajos de copiado (Ctrl+C / Ctrl+Insert) para no ensuciar la macro
    if ((vk == 67 && ctrlDown) || (vk == 45 && ctrlDown)) {
        return
    }

    if (vk == 8 && hadTypedInCurrentField) {
        if (StrLen(textBuffer) > 0) {
            textBuffer := SubStr(textBuffer, 1, -1)
            lastTick := A_TickCount
            ShowFloatingMiniHUD("[GRABANDO EN VIVO]", "Editando texto: " . (textBuffer != "" ? textBuffer : "(vacio)"), "Pasos: " . macroBuffer.Length . " | Ctrl+M: Terminar")
        }
        return
    }

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

    ; Si está escribiendo un nombre con espacio intermedio (ej. "Carlos Chavez"), mantener el espacio en textBuffer
    if (vk == 32 && textBuffer != "") {
        textBuffer .= " "
        lastTick := A_TickCount
        return
    }

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
                sleepLine := BuildRecordedSleepLine(delta)
                macroBuffer.Push(sleepLine)
                AppendPreviewLine(sleepLine)
            }
            lastTick := currentTick
        }

        hadTypedInCurrentField := false
        instruction := "Send, {" . keyName . "}"
        macroBuffer.Push(instruction)
        AppendPreviewLine(instruction)
        ShowFloatingMiniHUD("[GRABANDO EN VIVO]", "Tecla: {" . keyName . "}", "Pasos: " . macroBuffer.Length . " | Ctrl+M: Terminar")
    }
}

OnCharHandler(ih, char) {
    global isRecording, isPausedRec, firstKeyRecorded, lastTick, textBuffer, macroBuffer, hadTypedInCurrentField

    if (!isRecording || isPausedRec)
        return

    activeHwnd := WinActive("A")
    if (activeHwnd && !IsPosWindow(activeHwnd))
        return

    ; ASCII 22 (0x16) corresponde a Ctrl+V
    if (Ord(char) == 22) {
        RecordClipboardPaste("CharHook")
        return
    }

    if (Ord(char) < 32)
        return

    ; Si es espacio y ya se manejó en OnKeyDownHandler, evitar duplicar
    if (char == " ")
        return

    currentTick := A_TickCount

    if (!firstKeyRecorded) {
        firstKeyRecorded := true
        lastTick := currentTick
    } else {
        delta := (lastTick > 0) ? (currentTick - lastTick) : 0
        if (textBuffer == "" && delta >= 25) {
            ; Registrar primero la pausa y el WaitPrompt ocurridos entre el clic/tecla previo y el primer dígito escrito
            sleepLine := BuildRecordedSleepLine(delta)
            macroBuffer.Push(sleepLine)
            AppendPreviewLine(sleepLine)
        } else if (delta >= 1500 && textBuffer != "") {
            FlushTextBuffer()
            sleepLine := BuildRecordedSleepLine(delta)
            macroBuffer.Push(sleepLine)
            AppendPreviewLine(sleepLine)
        }
        lastTick := currentTick
    }

    textBuffer .= char
    hadTypedInCurrentField := true
}

FlushTextBuffer() {
    global textBuffer, macroBuffer, hadTypedInCurrentField
    if (Trim(textBuffer) != "") {
        cleanText := StrReplace(textBuffer, "{", "{{}")
        cleanText := StrReplace(cleanText, "}", "{}}")
        if (Trim(cleanText) != "") {
            instruction := "Send, " . cleanText
            macroBuffer.Push(instruction)
            AppendPreviewLine(instruction)
            ShowFloatingMiniHUD("[GRABANDO EN VIVO]", "Texto/SKU: " . cleanText, "Pasos: " . macroBuffer.Length . " | Ctrl+M: Terminar")
        }
    }
    textBuffer := ""
    hadTypedInCurrentField := false
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

RecordMouseClick(buttonName) {
    global isRecording, isPausedRec, firstKeyRecorded, lastTick, macroBuffer, textBuffer
    global targetWinTitle, lastRecordedClickIdx, hadTypedInCurrentField
    global pendingRightClickMenu, pendingRightClickTick, pendingRightClickX, pendingRightClickY

    if (!isRecording || isPausedRec)
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos(&screenX, &screenY, &mWin)

    ; Ignorar clics sobre la propia suite de automatización o sobre los HUDs flotantes
    if (IsOwnAppWindow(mWin))
        return

    ; Si el usuario hace clic en una ventana externa (ej. Bloc de Notas o Excel) para copiar un SKU/Gerente/Tarjeta,
    ; ignorar ese clic para no contaminar la macro de Xstore.
    if (!IsPosWindow(mWin)) {
        ShowFloatingMiniHUD("[GRABANDO EN VIVO]", "Ventana externa (Clic omitido)", "Copia el dato y vuelve a Xstore")
        return
    }

    relX := screenX
    relY := screenY
    wW := 0
    wH := 0
    try {
        WinGetPos(&wX, &wY, &wW, &wH, "ahk_id " . mWin)
        relX := screenX - wX
        relY := screenY - wY
    } catch {
        CoordMode("Mouse", "Window")
        MouseGetPos(&relX, &relY)
    }

    winSizeTag := (wW > 0 && wH > 0) ? (", WinSize=" . wW . "x" . wH) : ""

    ; --- INTEGRACIÓN UIA v2: Reconocimiento inteligente del elemento/botón ---
    uiaName := ""
    uiaId := ""
    typeStr := ""
    try {
        el := UIA.SmallestElementFromPoint(screenX, screenY)
        if (el) {
            try uiaName := Trim(el.Name)
            try uiaId := Trim(el.AutomationId)
            try typeStr := StrLower(Trim(el.LocalizedControlType))

            if (uiaName == targetWinTitle || InStr(targetWinTitle, uiaName) || InStr(uiaName, "Oracle Retail") || InStr(uiaName, "Point of Service") || uiaName == "Xstore" || typeStr == "window" || typeStr == "ventana" || typeStr == "pane" || typeStr == "panel" || typeStr == "client") {
                uiaName := ""
            }

            if (uiaName != "" || uiaId != "") {
                try el.Highlight(-250, "00FF00", 2)
            }
        }
    }

    ; Si el usuario hace Clic Derecho (RButton) en Xstore (ej. para abrir menú contextual Pegar),
    ; registrar el foco en el campo y activar detección de menú contextual.
    if (buttonName == "Right") {
        pendingRightClickMenu := true
        pendingRightClickTick := A_TickCount
        pendingRightClickX := screenX
        pendingRightClickY := screenY
    } else if (buttonName == "Left") {
        ; Verificar si este clic izquierdo es sobre la opción "Pegar" / "Paste" de un menú contextual
        isPasteMenuClick := false
        if (InStr(uiaName, "Pegar") || InStr(uiaName, "Paste") || InStr(uiaId, "Paste")) {
            isPasteMenuClick := true
        } else if (pendingRightClickMenu && (A_TickCount - pendingRightClickTick < 5000)) {
            try {
                if (WinGetClass("ahk_id " . mWin) == "#32768" || InStr(typeStr, "menu"))
                    isPasteMenuClick := true
            }
        }

        if (isPasteMenuClick) {
            pendingRightClickMenu := false
            SetTimer(() => RecordClipboardPaste("MouseMenuPaste"), -80)
            return
        }
        pendingRightClickMenu := false
    }

    currentTick := A_TickCount
    FlushTextBuffer()
    hadTypedInCurrentField := false

    if (!firstKeyRecorded) {
        firstKeyRecorded := true
        lastTick := currentTick
    } else {
        delta := (lastTick > 0) ? (currentTick - lastTick) : 0
        if (delta >= 25) {
            sleepLine := BuildRecordedSleepLine(delta)
            macroBuffer.Push(sleepLine)
            AppendPreviewLine(sleepLine)
        }
        lastTick := currentTick
    }

    if (uiaName != "") {
        cleanName := StrReplace(uiaName, '"', '\"')
        cleanName := StrReplace(cleanName, "`r", " ")
        cleanName := StrReplace(cleanName, "`n", " ")
        cleanName := Trim(cleanName)
        instruction := 'UIA_Click, Name="' . cleanName . '", Fallback=' . relX . ', ' . relY . winSizeTag
    } else if (uiaId != "") {
        cleanId := StrReplace(uiaId, '"', '\"')
        instruction := 'UIA_Click, AutomationId="' . cleanId . '", Fallback=' . relX . ', ' . relY . winSizeTag
    } else {
        instruction := 'UIA_Click, Name="Oracle Retail Xstore Point of Service", Fallback=' . relX . ', ' . relY . winSizeTag
    }

    macroBuffer.Push(instruction)
    lastRecordedClickIdx := macroBuffer.Length
    AppendPreviewLine(instruction)
    ShowFloatingMiniHUD("[GRABANDO EN VIVO]", "Clic POS (" . relX . ", " . relY . ")", "Pasos: " . macroBuffer.Length . " | Leyendo log Xstore...")

    SetTimer(EnrichLastClickFromXstoreLog, -140)
}

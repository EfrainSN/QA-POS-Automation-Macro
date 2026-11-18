; ==============================================================================
; MODULE: src\POS\PosWindowManager.ahk
; PURPOSE: Detección, vinculación, validación de foco y filtrado de ventana POS
; ==============================================================================

AutoDetectPosOnStartup() {
    global targetWinTitle, targetPosHwnd, edtTargetWin, mainGui
    try {
        for cand in ["Xstore", "xstore", "Oracle Retail", "Point of Service", "POS"] {
            if WinExist(cand) {
                hw := WinExist(cand)
                t := WinGetTitle(hw)
                if (t != "" && hw != mainGui.Hwnd && !InStr(t, "QA POS Automation Macro") && !RegExMatch(t, "i)^(Program Manager|Default IME|MSCTFIME UI)$")) {
                    targetWinTitle := t
                    targetPosHwnd := hw
                    edtTargetWin.Text := targetWinTitle
                    UpdateStatus("Ventana POS detectada: " . SubStr(targetWinTitle, 1, 35))
                    break
                }
            }
        }
    }
}

IsOwnAppWindow(hwnd) {
    global mainGui, countdownHudGui, liveMiniHudGui, clickTargetGui
    if (!hwnd)
        return false
    if (IsObject(mainGui) && hwnd == mainGui.Hwnd)
        return true
    if (IsObject(countdownHudGui) && countdownHudGui && hwnd == countdownHudGui.Hwnd)
        return true
    if (IsObject(liveMiniHudGui) && liveMiniHudGui && hwnd == liveMiniHudGui.Hwnd)
        return true
    if (IsObject(clickTargetGui) && clickTargetGui && hwnd == clickTargetGui.Hwnd)
        return true
    try {
        if (WinGetPID("ahk_id " . hwnd) == DllCall("GetCurrentProcessId", "UInt"))
            return true
    }
    return false
}

IsPosWindow(hwnd) {
    global targetPosHwnd, edtTargetWin
    if (!hwnd || IsOwnAppWindow(hwnd))
        return false

    try {
        wClass := WinGetClass("ahk_id " . hwnd)
        if (wClass == "#32768" || InStr(wClass, "SunAwt"))
            return true
    }

    if (targetPosHwnd && WinExist("ahk_id " . targetPosHwnd)) {
        if (hwnd == targetPosHwnd)
            return true
        try {
            if (WinGetPID("ahk_id " . hwnd) == WinGetPID("ahk_id " . targetPosHwnd))
                return true
        }
        try {
            wTitle := WinGetTitle("ahk_id " . hwnd)
            cfgTitle := IsObject(edtTargetWin) ? Trim(edtTargetWin.Text) : ""
            if ((cfgTitle != "" && InStr(wTitle, cfgTitle))
                || InStr(wTitle, "Xstore")
                || InStr(wTitle, "Oracle Retail")
                || InStr(wTitle, "Point of Service")) {
                return true
            }
        }
        ; Si Xstore está anclado y el usuario hace clic en Bloc de Notas, Excel, Navegador o Explorador
        ; para copiar un SKU, gerente o tarjeta con el ratón, ignorar esos clics externos en la macro.
        try {
            procName := StrLower(WinGetProcessName("ahk_id " . hwnd))
            if RegExMatch(procName, "^(notepad|notepad\+\+|excel|winword|chrome|msedge|firefox|brave|explorer|applicationframehost|code|powershell|cmd)\.exe$") {
                return false
            }
        }
    }

    return true
}

DetectTargetWindow(*) {
    global targetWinTitle, targetPosHwnd, edtTargetWin, mainGui

    currentTitle := Trim(edtTargetWin.Text)
    candidates := []
    if (currentTitle != "" && currentTitle != "Xstore")
        candidates.Push(currentTitle)
    candidates.Push("Xstore", "xstore", "Oracle Retail", "Point of Service", "POS")

    ; 1. Si la ventana de Xstore o POS ya está abierta en el sistema, vincularla y activarla de inmediato
    for cand in candidates {
        if WinExist(cand) {
            foundHwnd := WinExist(cand)
            foundTitle := WinGetTitle(foundHwnd)
            if (foundTitle != "" && !IsOwnAppWindow(foundHwnd) && !InStr(foundTitle, "QA POS Automation Macro") && !RegExMatch(foundTitle, "i)^(Program Manager|Default IME|MSCTFIME UI)$")) {
                WinActivate(foundHwnd)
                targetWinTitle := foundTitle
                targetPosHwnd := foundHwnd
                edtTargetWin.Text := foundTitle
                SaveSettings()
                SoundBeep(1000, 200)
                UpdateStatus("Ventana POS vinculada: " . SubStr(foundTitle, 1, 35))
                MsgBox("¡Ventana de Xstore POS vinculada exitosamente!`n`nTitulo detectado:`n" . foundTitle . "`n`nLa terminal ha sido ubicada y vinculada.",
                    "Vinculador POS", "Iconi 262144")
                return
            }
        }
    }

    ; 2. Si no se detectó automáticamente o el usuario desea seleccionar manualmente otra ventana
    WinSetTransparent(150, mainGui)
    UpdateStatus("MODO VINCULAR: Haz clic en la ventana de Xstore / POS ahora...")

    ToolTip("MODO VINCULACION ACTIVADO`n`nHaz clic en cualquier parte de la ventana de tu caja POS (Xstore)...`n(Presiona ESC para cancelar)", 12, 12)
    SoundBeep(700, 150)

    startTime := A_TickCount

    CheckActiveWindowChange() {
        if (GetKeyState("Escape", "P")) {
            SetTimer(CheckActiveWindowChange, 0)
            ToolTip()
            WinSetTransparent("Off", mainGui)
            UpdateStatus("Vinculacion cancelada por el usuario")
            return
        }

        if (A_TickCount - startTime > 12000) {
            SetTimer(CheckActiveWindowChange, 0)
            ToolTip()
            WinSetTransparent("Off", mainGui)
            UpdateStatus("Tiempo agotado. Escribe el titulo en el campo.")
            MsgBox("Tiempo de espera agotado.`n`nPuedes escribir directamente 'xstore' o el titulo de tu ventana en el campo de texto.",
                "Vinculador POS", "Icon! 262144")
            return
        }

        activeHwnd := WinActive("A")
        if (activeHwnd && !IsOwnAppWindow(activeHwnd)) {
            activeTitle := WinGetTitle(activeHwnd)
            if (activeTitle != "" && !InStr(activeTitle, "QA POS Automation Macro") && !RegExMatch(activeTitle, "i)^(Program Manager|Default IME|MSCTFIME UI)$")) {
                SetTimer(CheckActiveWindowChange, 0)
                ToolTip()
                WinSetTransparent("Off", mainGui)
                targetWinTitle := activeTitle
                targetPosHwnd := activeHwnd
                edtTargetWin.Text := activeTitle
                SaveSettings()
                UpdateStatus("Ventana POS vinculada: " . SubStr(activeTitle, 1, 35))
                SoundBeep(1000, 200)
                MsgBox("¡Ventana vinculada exitosamente!`n`nTitulo capturado:`n" . activeTitle . "`n`nYa puedes grabar o ejecutar transacciones sobre ella.",
                    "Vinculador POS", "Iconi 262144")
            }
        }
    }

    SetTimer(CheckActiveWindowChange, 100)
}

EnsureTargetWindowActive() {
    global targetWinTitle, targetPosHwnd, edtTargetWin, mainGui
    currentTitle := IsObject(edtTargetWin) ? Trim(edtTargetWin.Text) : targetWinTitle
    if (currentTitle == "")
        currentTitle := "Xstore"

    foundHwnd := 0
    if WinExist(currentTitle) {
        h := WinExist(currentTitle)
        if (!IsOwnAppWindow(h))
            foundHwnd := h
    }

    if (!foundHwnd) {
        for candidate in [currentTitle, "xstore", "POS", "Oracle Retail", "Point of Service"] {
            if WinExist(candidate) {
                h := WinExist(candidate)
                t := WinGetTitle(h)
                if (!IsOwnAppWindow(h) && !InStr(t, "QA POS Automation Macro") && !RegExMatch(t, "i)^(Program Manager|Default IME|MSCTFIME UI)$")) {
                    foundHwnd := h
                    targetWinTitle := t
                    if IsObject(edtTargetWin)
                        edtTargetWin.Text := t
                    break
                }
            }
        }
    }

    if (!foundHwnd) {
        targetPosHwnd := 0
        return 0
    }

    targetPosHwnd := foundHwnd

    ; Si la ventana está minimizada, restaurarla a su tamaño normal
    if (WinGetMinMax("ahk_id " . foundHwnd) == -1)
        WinRestore("ahk_id " . foundHwnd)

    ; Forzar activación en primer plano
    WinActivate("ahk_id " . foundHwnd)
    DllCall("SetForegroundWindow", "Ptr", foundHwnd)
    DllCall("BringWindowToTop", "Ptr", foundHwnd)

    ; Validar activación real con el sistema operativo (espera de hasta 1.5 segundos)
    if (!WinWaitActive("ahk_id " . foundHwnd, , 1.5)) {
        DllCall("SwitchToThisWindow", "Ptr", foundHwnd, "Int", 1)
        WinActivate("ahk_id " . foundHwnd)
        Sleep(80)
    }

    return foundHwnd
}

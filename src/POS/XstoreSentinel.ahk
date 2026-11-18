; ==============================================================================
; MODULE: src\POS\XstoreSentinel.ahk
; PURPOSE: Subsistema Centinela Xstore con soporte para logs DEBUG masivos (400MB+),
;          deteccion de SMN_INVALID_CARD_PROMPT y diagnostico exacto de rechazos VTOL
; ==============================================================================

DetectDefaultLogPath() {
    global xstoreLogPath
    candidates := [
        "C:\xstore\log\xstore.log",
        "D:\xstore\log\xstore.log",
        A_ScriptDir . "\xstore.log",
        A_ScriptDir . "\xstore 6.log",
        A_ScriptDir . "\xstor_14_10_2026e.log"
    ]
    for cand in candidates {
        if FileExist(cand) {
            xstoreLogPath := cand
            return cand
        }
    }
    return xstoreLogPath
}

UpdateSentinelStatus() {
    global xstoreLogPath, txtSentinelStatus, chkSentinel
    if (!IsObject(chkSentinel) || !IsObject(txtSentinelStatus))
        return

    if (chkSentinel.Value == 0) {
        txtSentinelStatus.Text := "[Inactivo]"
        txtSentinelStatus.SetFont("c888888")
    } else if (FileExist(xstoreLogPath)) {
        txtSentinelStatus.Text := "[Log Activo]"
        txtSentinelStatus.SetFont("c0E7D42")
    } else {
        txtSentinelStatus.Text := "[Sin Log]"
        txtSentinelStatus.SetFont("cBA1A1A")
    }
}

ConfigureSentinelPath(*) {
    global xstoreLogPath
    selectedFile := FileSelect(3, xstoreLogPath, "Seleccionar archivo de log de Xstore", "Archivos de Log (*.log; *.txt)")
    if (selectedFile != "") {
        xstoreLogPath := selectedFile
        UpdateSentinelStatus()
        SaveSettings()
        MsgBox("Ruta de Xstore Log configurada:`n`n" . xstoreLogPath, "Centinela Xstore", "Iconi 262144")
    }
}

StripDebugSqlLines(rawChunk) {
    if (!InStr(rawChunk, " DEBUG "))
        return rawChunk
    return RegExReplace(rawChunk, "m)^[ \t]*DEBUG[ \t]+\[[^\r\n]*(\r?\n|$)", "")
}

ExtractSnippetAroundMatch(chunk, matchPos) {
    startIdx := Max(1, matchPos - 360)
    len := Min(StrLen(chunk) - startIdx + 1, 800)
    return Trim(SubStr(chunk, startIdx, len))
}

ExtractVtolRejectionFromChunk(cleanChunk, &vtolCode := "", &vtolMsg := "") {
    vtolCode := ""
    vtolMsg := ""
    pos := 1
    found := false
    while RegExMatch(cleanChunk, "Sale Response\s*:\s*\{([^\}]+)\}", &mBlock, pos) {
        blockBody := mBlock[1]
        if (InStr(blockBody, "26:Error") || !InStr(blockBody, "27:00")) {
            if RegExMatch(blockBody, "28:([^\r\n\}]+)", &mMsg) {
                msgCandidate := Trim(mMsg[1])
                if (msgCandidate != "" && msgCandidate != "APROBADO") {
                    vtolMsg := msgCandidate
                    if RegExMatch(blockBody, "27:([0-9A-Za-z]+)", &mCode)
                        vtolCode := Trim(mCode[1])
                    found := true
                }
            }
        }
        pos := mBlock.Pos + mBlock.Len
    }
    return found
}

CheckXstoreSentinel(logHandle, &errorReason := "", &errorDetail := "", &errorSnippet := "") {
    if (!logHandle)
        return false

    if (logHandle.AtEOF || logHandle.Pos >= logHandle.Length)
        return false

    newBytes := logHandle.Length - logHandle.Pos
    if (newBytes <= 0)
        return false

    ; Ventana de 512 KB para soportar cajas con nivel DEBUG JDBC activo (mas de 5,000 queries por transaccion)
    if (newBytes > 524288) {
        logHandle.Seek(-524288, 2)
    }

    rawChunk := logHandle.Read()
    if (rawChunk == "")
        return false

    cleanChunk := StripDebugSqlLines(rawChunk)
    if (cleanChunk == "")
        return false

    ; 1. Prompts modales de error de Xstore y validacion de tarjetas en OPCHAIN_FLOW
    if RegExMatch(cleanChunk, "\[Prompt\]\s+(ERROR_WITH_INFO|VALIDATION_ERROR_MESSAGE|SMN_INVALID_CARD_PROMPT|FORM_VALIDATION_FAILED[A-Za-z0-9_]*|WORKSTATION_IS_CLOSED[A-Za-z0-9_]*)", &match) {
        promptCode := match[1]
        errorReason := promptCode
        errorSnippet := ExtractSnippetAroundMatch(cleanChunk, match.Pos)

        switch promptCode {
            case "ERROR_WITH_INFO":
                vCode := "", vMsg := ""
                if ExtractVtolRejectionFromChunk(cleanChunk, &vCode, &vMsg) {
                    errorReason := (vCode != "") ? ("RECHAZO_VTOL_" . vCode) : "RECHAZO_VTOL"
                    errorDetail := (vCode != "" ? ("27:" . vCode . " | ") : "") . "28:" . vMsg
                } else if InStr(cleanChunk, "CheckItemNotOnFileOp") {
                    errorDetail := "Articulo o SKU no registrado en catalogo (Item Not On File)"
                } else {
                    errorDetail := "Error operativo o rechazo de negocio en Xstore (ERROR_WITH_INFO)"
                }
            case "SMN_INVALID_CARD_PROMPT":
                errorDetail := "Numero de tarjeta invalido, vacio o formato rechazado por Xstore"
            case "VALIDATION_ERROR_MESSAGE":
                errorDetail := "Validacion de pago, campo o monto de transaccion rechazada"
            case "FORM_VALIDATION_FAILED", "FORM_VALIDATION_FAILED_ALT":
                errorDetail := "Formulario con campos obligatorios vacios o invalidos"
            case "WORKSTATION_IS_CLOSED_NO_ACCESS":
                errorDetail := "Caja cerrada sin turno operativo habilitado"
            default:
                errorDetail := "Ventana modal de error en Xstore (" . promptCode . ")"
        }
        return true
    }

    ; 2. Reglas de negocio rechazadas en OPCHAIN_FLOW
    if RegExMatch(cleanChunk, "X\[Rule\]\s+class\s+([A-Za-z0-9_\.]+)", &matchRule) {
        errorReason := "REGLA_RECHAZADA"
        errorDetail := "Regla de negocio no cumplida: " . matchRule[1]
        errorSnippet := ExtractSnippetAroundMatch(cleanChunk, matchRule.Pos)
        return true
    }

    ; 3. Excepciones de articulo inexistente
    if (InStr(cleanChunk, "CheckItemNotOnFileOp") && InStr(cleanChunk, "ERROR_WITH_INFO")) {
        errorReason := "ITEM_NOT_ON_FILE"
        errorDetail := "SKU o codigo de barra no encontrado en catalogo"
        errorSnippet := ExtractSnippetAroundMatch(cleanChunk, InStr(cleanChunk, "CheckItemNotOnFileOp"))
        return true
    }

    return false
}

CaptureWindowScreenshot(targetTitle, cycleNum := 0) {
    global screenshotsFolder
    EnsureRequiredDirectories()

    targetHwnd := 0
    if (targetTitle != "" && WinExist(targetTitle))
        targetHwnd := WinExist(targetTitle)
    else
        targetHwnd := DllCall("GetDesktopWindow", "Ptr")

    stamp := FormatTime(, "yyyyMMdd_HHmmss")
    filename := "Error_Ciclo_" . cycleNum . "_" . stamp . ".png"
    outputPath := screenshotsFolder . "\" . filename

    pToken := 0
    si := Buffer(24, 0)
    NumPut("UInt", 1, si, 0)
    if (DllCall("gdiplus\GdiplusStartup", "UPtr*", &pToken, "Ptr", si.Ptr, "Ptr", 0) != 0)
        return ""

    rect := Buffer(16, 0)
    if (!DllCall("GetWindowRect", "Ptr", targetHwnd, "Ptr", rect.Ptr)) {
        DllCall("gdiplus\GdiplusShutdown", "Ptr", pToken)
        return ""
    }
    w := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")
    h := NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")
    if (w <= 0 || h <= 0) {
        w := A_ScreenWidth
        h := A_ScreenHeight
        targetHwnd := DllCall("GetDesktopWindow", "Ptr")
    }

    hdcSrc := DllCall("GetDC", "Ptr", targetHwnd, "Ptr")
    hdcDest := DllCall("CreateCompatibleDC", "Ptr", hdcSrc, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdcSrc, "Int", w, "Int", h, "Ptr")
    hbmOld := DllCall("SelectObject", "Ptr", hdcDest, "Ptr", hbm, "Ptr")
    DllCall("BitBlt", "Ptr", hdcDest, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdcSrc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)

    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hbm, "Ptr", 0, "UPtr*", &pBitmap)

    clsidPNG := Buffer(16, 0)
    DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsidPNG.Ptr)

    res := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", outputPath, "Ptr", clsidPNG.Ptr, "Ptr", 0)

    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    DllCall("SelectObject", "Ptr", hdcDest, "Ptr", hbmOld)
    DllCall("DeleteObject", "Ptr", hbm)
    DllCall("DeleteDC", "Ptr", hdcDest)
    DllCall("ReleaseDC", "Ptr", targetHwnd, "Ptr", hdcSrc)
    DllCall("gdiplus\GdiplusShutdown", "Ptr", pToken)

    return (res == 0 && FileExist(outputPath)) ? outputPath : ""
}

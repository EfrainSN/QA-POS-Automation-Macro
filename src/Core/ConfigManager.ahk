; ==============================================================================
; MODULE: src\Core\ConfigManager.ahk
; PURPOSE: Gestion de directorios requeridos y persistencia en config.ini
; ==============================================================================

EnsureRequiredDirectories() {
    global macroFolder, reportsFolder, screenshotsFolder, ticketsFolder
    createdAny := false

    for dirPath in [macroFolder, reportsFolder, screenshotsFolder, ticketsFolder] {
        if (!DirExist(dirPath)) {
            try {
                DirCreate(dirPath)
                createdAny := true
            }
        }
    }

    if (FileExist(A_ScriptDir . "\Macro_POS_Local.txt") && !FileExist(macroFolder . "\Macro_POS_Local.txt")) {
        try FileCopy(A_ScriptDir . "\Macro_POS_Local.txt", macroFolder . "\Macro_POS_Local.txt", 0)
    }

    return createdAny
}

LoadSettings() {
    global configFilePath, targetWinTitle, xstoreLogPath, posLogPath, sentinelEnabled, selfHealEnabled, smartLogSyncEnabled
    global savedLastMacro, edtTargetWin, chkSentinel, chkSelfHeal, chkSmartSync, ddlSpeed, radModeSingle, radModeBatch, chkInfinite, edtReps

    if (!FileExist(configFilePath))
        return

    try {
        winT := IniRead(configFilePath, "General", "TargetWindow", targetWinTitle)
        if (winT != "") {
            targetWinTitle := winT
            edtTargetWin.Text := winT
        }

        savedLastMacro := IniRead(configFilePath, "General", "LastMacro", "")

        logP := IniRead(configFilePath, "Sentinel", "LogPath", "")
        if (logP != "" && FileExist(logP))
            xstoreLogPath := logP

        posP := IniRead(configFilePath, "Sentinel", "PosLogPath", "")
        if (posP != "" && FileExist(posP))
            posLogPath := posP

        sentinelEnabled := (IniRead(configFilePath, "Sentinel", "Enabled", "1") == "1")
        chkSentinel.Value := sentinelEnabled ? 1 : 0

        selfHealEnabled := (IniRead(configFilePath, "Sentinel", "SelfHeal", "0") == "1")
        chkSelfHeal.Value := selfHealEnabled ? 1 : 0

        smartLogSyncEnabled := (IniRead(configFilePath, "Automation", "SmartLogSync", "1") == "1")
        chkSmartSync.Value := smartLogSyncEnabled ? 1 : 0

        spdIdx := Integer(IniRead(configFilePath, "Automation", "SpeedIndex", "2"))
        if (spdIdx >= 1 && spdIdx <= 4) {
            ddlSpeed.Choose(spdIdx)
            UpdateSpeedMultiplier()
        }

        modeStr := IniRead(configFilePath, "Automation", "ExecMode", "Single")
        repsVal := IniRead(configFilePath, "Automation", "BatchReps", "5")
        edtReps.Text := repsVal

        if (modeStr == "Batch") {
            radModeSingle.Value := 0
            radModeBatch.Value := 1
            chkInfinite.Value := 0
            edtReps.Enabled := true
        } else if (modeStr == "Infinite") {
            radModeSingle.Value := 0
            radModeBatch.Value := 0
            chkInfinite.Value := 1
            edtReps.Enabled := false
        } else {
            radModeSingle.Value := 1
            radModeBatch.Value := 0
            chkInfinite.Value := 0
            edtReps.Enabled := false
        }
    }
}

SaveSettings(*) {
    global configFilePath, edtTargetWin, ddlMacros, xstoreLogPath, posLogPath, chkSentinel, chkSelfHeal, chkSmartSync
    global ddlSpeed, radModeBatch, chkInfinite, edtReps

    if (!IsObject(edtTargetWin) || !IsObject(ddlMacros))
        return

    try {
        IniWrite(Trim(edtTargetWin.Text), configFilePath, "General", "TargetWindow")
        if (ddlMacros.Text != "" && !InStr(ddlMacros.Text, "(Sin macros"))
            IniWrite(ddlMacros.Text, configFilePath, "General", "LastMacro")

        IniWrite(xstoreLogPath, configFilePath, "Sentinel", "LogPath")
        IniWrite(posLogPath, configFilePath, "Sentinel", "PosLogPath")
        IniWrite(chkSentinel.Value ? "1" : "0", configFilePath, "Sentinel", "Enabled")
        IniWrite(chkSelfHeal.Value ? "1" : "0", configFilePath, "Sentinel", "SelfHeal")

        IniWrite(chkSmartSync.Value ? "1" : "0", configFilePath, "Automation", "SmartLogSync")
        IniWrite(String(ddlSpeed.Value), configFilePath, "Automation", "SpeedIndex")
        IniWrite(Trim(edtReps.Text), configFilePath, "Automation", "BatchReps")

        modeStr := (chkInfinite.Value == 1) ? "Infinite" : ((radModeBatch.Value == 1) ? "Batch" : "Single")
        IniWrite(modeStr, configFilePath, "Automation", "ExecMode")
    }
}

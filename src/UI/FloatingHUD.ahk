; ==============================================================================
; MODULE: src\UI\FloatingHUD.ahk
; PURPOSE: HUDs flotantes no intrusivos (Countdown OSD, Mini-HUD en vivo y Mira)
; ==============================================================================

ShowCountdownHUD(titleText, numberText, subText := "") {
    global countdownHudGui
    try {
        if (!countdownHudGui) {
            countdownHudGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border +E0x20")
            countdownHudGui.BackColor := "123859" ; Azul Zafiro Aero
            countdownHudGui.MarginX := 25
            countdownHudGui.MarginY := 16

            countdownHudGui.SetFont("s10 bold c5AD1FF", "Segoe UI")
            countdownHudGui.Add("Text", "vHudTitle w390 Center", titleText)

            countdownHudGui.SetFont("s38 bold cFFFFFF", "Segoe UI")
            countdownHudGui.Add("Text", "vHudNum w390 Center y+4", numberText)

            countdownHudGui.SetFont("s9 cD9EBF7", "Segoe UI")
            countdownHudGui.Add("Text", "vHudSub w390 Center y+4", subText)
        } else {
            countdownHudGui["HudTitle"].Text := titleText
            countdownHudGui["HudNum"].Text := numberText
            countdownHudGui["HudSub"].Text := subText
        }

        posX := (A_ScreenWidth - 440) // 2
        posY := Integer(A_ScreenHeight * 0.16)
        countdownHudGui.Show("x" . posX . " y" . posY . " w440 NoActivate")
    }
}

HideCountdownHUD() {
    global countdownHudGui
    try {
        if (countdownHudGui)
            countdownHudGui.Hide()
    }
}

ShowFloatingMiniHUD(leftTitle, midAction, rightHint := "Ctrl+P: Pausa | Ctrl+M: Parar") {
    global liveMiniHudGui
    try {
        if (!liveMiniHudGui) {
            liveMiniHudGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border +E0x20")
            liveMiniHudGui.BackColor := "123859"
            liveMiniHudGui.MarginX := 12
            liveMiniHudGui.MarginY := 6

            liveMiniHudGui.SetFont("s9 bold c5AD1FF", "Segoe UI")
            liveMiniHudGui.Add("Text", "vMiniLeft x12 y6 w210 h20", leftTitle)

            liveMiniHudGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
            liveMiniHudGui.Add("Text", "vMiniMid x228 y6 w255 h20 Center", midAction)

            liveMiniHudGui.SetFont("s8 cD9EBF7", "Segoe UI")
            liveMiniHudGui.Add("Text", "vMiniRight x488 y7 w190 h18 Right", rightHint)
        } else {
            liveMiniHudGui["MiniLeft"].Text := SubStr(leftTitle, 1, 30)
            liveMiniHudGui["MiniMid"].Text := SubStr(midAction, 1, 38)
            liveMiniHudGui["MiniRight"].Text := SubStr(rightHint, 1, 32)
        }

        posX := (A_ScreenWidth - 690) // 2
        liveMiniHudGui.Show("x" . posX . " y6 w690 h32 NoActivate")
    }
}

HideFloatingMiniHUD() {
    global liveMiniHudGui
    try {
        if (liveMiniHudGui)
            liveMiniHudGui.Hide()
    }
}

ShowClickReticleOverlay(screenX, screenY, labelText := "") {
    global clickTargetGui
    try {
        if (clickTargetGui)
            clickTargetGui.Destroy()

        clickTargetGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border +E0x20")
        clickTargetGui.BackColor := "00FF66"
        clickTargetGui.SetFont("s8 bold c123859", "Segoe UI")
        clickTargetGui.Add("Text", "x2 y2 w176 h20 Center Background00FF66", "[MIRA] " . SubStr(labelText, 1, 25))

        boxX := Max(0, screenX - 90)
        boxY := Max(0, screenY - 12)
        clickTargetGui.Show("x" . boxX . " y" . boxY . " w180 h24 NoActivate")
        SoundBeep(1100, 90)
        SetTimer(HideClickReticleOverlay, -1400)
    }
}

HideClickReticleOverlay() {
    global clickTargetGui
    try {
        if (clickTargetGui) {
            clickTargetGui.Destroy()
            clickTargetGui := ""
        }
    }
}

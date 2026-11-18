; ==============================================================================
; MODULE: src\Core\Globals.ahk
; PURPOSE: Variables de estado global, constantes y referencias compartidas
; ==============================================================================

global appVersion := "2.9.1"
global latestReleaseUrl := "https://github.com/EfrainSN/QA-POS-Automation-Macro/releases"
global latestZipDownloadUrl := ""

global isRecording := false
global isPausedRec := false
global isPlaying := false
global isPausedPlay := false
global stopPlayback := false
global isCountdownActive := false
global recordingCountdown := 0
global firstKeyRecorded := false
global lastTick := 0
global textBuffer := ""
global macroBuffer := []
global keyHook := ""

global lastCopiedClipboardText := ""
global lastPasteTick := 0
global hadTypedInCurrentField := false
global pendingRightClickMenu := false
global pendingRightClickTick := 0
global pendingRightClickX := 0
global pendingRightClickY := 0

global recLogHandle := ""
global lastDetectedLogPrompt := ""
global lastRecordedClickIdx := 0
global lastActionLogPos := 0

global macroFolder := A_ScriptDir . "\Macros"
global reportsFolder := A_ScriptDir . "\Reports"
global screenshotsFolder := reportsFolder . "\Screenshots"
global ticketsFolder := reportsFolder . "\Tickets"
global configFilePath := A_ScriptDir . "\config.ini"
global xstoreLogPath := "C:\xstore\log\xstore.log"
global posLogPath := A_ScriptDir . "\PosLog.xml"
global sentinelEnabled := true
global selfHealEnabled := false
global smartLogSyncEnabled := true

global autoTotalCycles := 1
global autoCurrentCycle := 0
global autoSuccessCount := 0
global autoFailCount := 0
global autoRecoveredCount := 0
global autoStartTime := 0
global autoCycleStart := 0
global autoCurrentCSV := ""
global autoCurrentHTML := ""
global autoAuditRecords := []
global libraryTransactions := []
global targetWinTitle := "Xstore"
global targetPosHwnd := 0
global speedMultiplier := 1.0
global savedLastMacro := ""

global editorSteps := []
global currentEditingMacro := ""

global mainGui := ""
global mainTabs := ""
global txtStatus := ""
global btnHeaderUpdate := ""
global edtTargetWin := ""
global btnDetectWin := ""
global ddlMacros := ""
global btnRefresh := ""
global btnOpenFolderMacro := ""
global radModeSingle := ""
global radModeBatch := ""
global edtReps := ""
global chkInfinite := ""
global ddlSpeed := ""
global chkSmartSync := ""
global edtLoopDelay := ""
global chkSentinel := ""
global btnSentinelPath := ""
global txtSentinelStatus := ""
global btnPosLogPath := ""
global txtPosLogStatus := ""
global chkSelfHeal := ""
global progBar := ""
global txtProgress := ""
global txtMetricsA := ""
global txtMetricsC := ""
global btnPlay := ""
global btnPausePlay := ""
global btnStop := ""
global edtMacroName := ""
global btnRecord := ""
global btnPauseRec := ""
global btnSaveRec := ""
global btnCancelRec := ""
global edtBufferPreview := ""
global ddlEditMacros := ""
global btnLoadMacro := ""
global btnBatchOptimize := ""
global lvSteps := ""
global btnStepUp := ""
global btnStepDown := ""
global btnStepDup := ""
global btnStepDel := ""
global btnPreviewClick := ""
global btnTestStep := ""
global btnRunFromHere := ""
global ddlStepType := ""
global edtStepVal := ""
global btnApplyStep := ""
global btnInsertStep := ""
global txtStepDesc := ""
global btnSaveMacroFile := ""
global btnSaveAsMacroFile := ""
global txtRepInfo1 := ""
global txtRepInfo2 := ""
global txtRepInfo3 := ""
global lvLibTrans := ""
global btnViewTicket := ""
global btnReloadPosLog := ""
global btnOpenInEditor := ""
global btnOpenNotepad := ""
global btnViewDashboard := ""
global btnViewLastCSV := ""
global btnOpenMacros := ""
global btnOpenReports := ""
global btnOpenScreenshots := ""
global btnCheckUpdatesLib := ""
global txtLocalVer := ""
global txtRemoteVer := ""
global txtUpdateState := ""
global btnCheckUpdates := ""
global btnOpenReleases := ""
global edtReleaseNotes := ""
global btnDownloadZip := ""

global countdownHudGui := ""
global liveMiniHudGui := ""
global clickTargetGui := ""

global specialKeys := Map(
    "Enter", true, "Escape", true, "Tab", true, "Space", true, "Backspace", true,
    "Delete", true, "Insert", true, "Up", true, "Down", true, "Left", true, "Right", true,
    "Home", true, "End", true, "PgUp", true, "PgDn", true,
    "F1", true, "F2", true, "F3", true, "F4", true, "F5", true, "F6", true,
    "F7", true, "F8", true, "F9", true, "F10", true, "F11", true, "F12", true,
    "NumpadEnter", true
)

; ==============================================================================
; MODULE: src\Engine\Hotkeys.ahk
; PURPOSE: Atajos globales de control (Ctrl+P, Ctrl+M) y captura de ratón/pegado
; ==============================================================================

#HotIf isPlaying
^p:: TogglePauseAutomation()
<^p:: TogglePauseAutomation()
#HotIf

#HotIf (isPlaying || isRecording || isCountdownActive)
^m:: EmergencyStop()
<^m:: EmergencyStop()
#HotIf

#HotIf (isRecording && !isPausedRec)
~*LButton:: RecordMouseClick("Left")
~*RButton:: RecordMouseClick("Right")
~*^v:: RecordClipboardPaste("HotkeyCtrlV")
~*+Insert:: RecordClipboardPaste("HotkeyShiftIns")
#HotIf

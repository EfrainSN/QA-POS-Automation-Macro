; ==============================================================================
; MODULE: src\UI\StepEditor.ahk
; PURPOSE: Editor interactivo de pasos, mira visual sobre Xstore, prueba de paso
;          individual, ejecución parcial y optimizador masivo de SKUs/pausas
; ==============================================================================

GetStepHumanDescription(stepType, stepVal) {
    if (stepType == "Pausa (ms)") {
        msVal := RegExMatch(stepVal, "(\d+)", &mMs) ? Integer(mMs[1]) : 0
        secStr := Round(msVal / 1000, 2) . "s"
        if RegExMatch(stepVal, 'WaitPrompt="([^"]+)"', &mPrompt)
            return "Sync [" . mPrompt[1] . "] (" . secStr . ")"
        return "Espera de " . secStr . " (" . msVal . " ms)"
    } else if (stepType == "Esperar Prompt (Log)") {
        if RegExMatch(stepVal, '^([^,]+)', &mP)
            return "Esperar Log: " . Trim(mP[1])
        return "Esperar Prompt en Log"
    } else if (stepType == "Tecla Especial") {
        cleanK := RegExReplace(stepVal, "[\{\}]", "")
        switch StrLower(cleanK) {
            case "enter", "numpadenter": return "Confirmar (Enter)"
            case "escape": return "Cancelar / Atras (Esc)"
            case "tab": return "Siguiente Campo (Tab)"
            case "space": return "Espacio"
            case "backspace": return "Borrar (Backspace)"
            default: return "Tecla: " . cleanK
        }
    } else if (stepType == "Texto / SKU") {
        if RegExMatch(stepVal, "^\d{5,}$")
            return "Escaneo SKU / ID: " . stepVal
        return "Ingresar: " . stepVal
    } else if (stepType == "Clic UIA (Boton)" || stepType == "Clic Raton") {
        if RegExMatch(stepVal, 'XstoreAction="([^"]+)"', &mAct)
            return "Boton: " . mAct[1]
        if RegExMatch(stepVal, 'Name="([^"]+)"', &mName) {
            n := mName[1]
            if (!InStr(n, "Oracle Retail") && !InStr(n, "Point of Service") && n != "Xstore")
                return "Boton UIA: " . n
        }
        if RegExMatch(stepVal, 'i)Fallback=\s*(-?\d+)\s*,\s*(-?\d+)', &mFb)
            return "Clic POS (" . mFb[1] . ", " . mFb[2] . ")"
        if RegExMatch(stepVal, '(-?\d+)\s*,\s*(-?\d+)', &mXy)
            return "Clic (" . mXy[1] . ", " . mXy[2] . ")"
        return "Clic en Pantalla POS"
    }
    return stepVal
}

LoadMacroIntoEditor(*) {
    global ddlEditMacros, lvSteps, editorSteps, macroFolder, currentEditingMacro, ddlStepType, edtStepVal
    selected := ddlEditMacros.Text
    if (selected == "" || selected == "(Sin macros guardadas)" || selected == "(Sin macros)") {
        return
    }

    fullPath := macroFolder . "\" . selected
    if (!FileExist(fullPath)) {
        MsgBox("El archivo '" . fullPath . "' no existe.", "Editor de Pasos", "Iconx 262144")
        return
    }

    currentEditingMacro := selected
    editorSteps := []
    lvSteps.Delete()

    fileLines := FileRead(fullPath, "UTF-8")
    idx := 0
    loop parse, fileLines, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line == "" || SubStr(line, 1, 1) == ";")
            continue

        idx++
        stepType := ""
        stepVal := ""
        if (SubStr(line, 1, 6) == "Sleep,") {
            stepType := "Pausa (ms)"
            stepVal := Trim(SubStr(line, 7))
        } else if (SubStr(line, 1, 11) == "WaitPrompt," || SubStr(line, 1, 8) == "WaitLog,") {
            stepType := "Esperar Prompt (Log)"
            stepVal := Trim(SubStr(line, InStr(line, ",") + 1))
        } else if (SubStr(line, 1, 5) == "Send,") {
            cmd := Trim(SubStr(line, 6))
            if (RegExMatch(cmd, "^\{.+\}$")) {
                stepType := "Tecla Especial"
                stepVal := cmd
            } else {
                stepType := "Texto / SKU"
                stepVal := cmd
            }
        } else if (SubStr(line, 1, 10) == "UIA_Click,") {
            stepType := "Clic UIA (Boton)"
            stepVal := Trim(SubStr(line, 11))
        } else if (SubStr(line, 1, 11) == "MouseClick," || SubStr(line, 1, 6) == "Click,") {
            stepType := "Clic Raton"
            stepVal := Trim(SubStr(line, InStr(line, ",") + 1))
        } else {
            stepType := "Comando"
            stepVal := line
        }

        desc := GetStepHumanDescription(stepType, stepVal)
        editorSteps.Push({type: stepType, val: stepVal})
        lvSteps.Add("", Format("{:02}", idx), stepType, desc, stepVal)
    }

    if (editorSteps.Length > 0) {
        lvSteps.Modify(1, "Select Focus")
        OnStepSelected(lvSteps, 1)
        UpdateStatus("Macro cargada en editor: " . selected . " (" . editorSteps.Length . " pasos)")
    } else {
        UpdateStatus("La macro seleccionada esta vacia")
    }
}

OnStepSelected(lv, rowNumber) {
    global editorSteps, ddlStepType, edtStepVal, txtStepDesc
    if (rowNumber <= 0 || rowNumber > editorSteps.Length)
        return
    item := editorSteps[rowNumber]
    switch item.type {
        case "Texto / SKU": ddlStepType.Choose(1)
        case "Tecla Especial": ddlStepType.Choose(2)
        case "Pausa (ms)": ddlStepType.Choose(3)
        case "Clic Raton": ddlStepType.Choose(4)
        case "Clic UIA (Boton)": ddlStepType.Choose(5)
        case "Esperar Prompt (Log)": ddlStepType.Choose(6)
        default: ddlStepType.Choose(1)
    }
    edtStepVal.Text := item.val
    desc := GetStepHumanDescription(item.type, item.val)
    txtStepDesc.Text := "Paso #" . Format("{:02}", rowNumber) . " - " . desc . "`nUsa 'Mira' para ver el clic en Xstore, 'Paso' para probarlo o 'Aqui' para correr desde este paso."
}

ApplyStepEdit(*) {
    global lvSteps, editorSteps, ddlStepType, edtStepVal
    row := lvSteps.GetNext()
    if (row == 0) {
        MsgBox("Selecciona primero un paso de la lista para actualizar.", "Editor de Pasos", "Icon! 262144")
        return
    }

    newVal := Trim(edtStepVal.Text)
    if (newVal == "") {
        MsgBox("El valor no puede estar vacio.", "Editor de Pasos", "Icon! 262144")
        return
    }

    newType := ddlStepType.Text
    if (newType == "Tecla Especial" && !RegExMatch(newVal, "^\{.+\}$")) {
        newVal := "{" . newVal . "}"
    } else if (newType == "Pausa (ms)") {
        if (!InStr(newVal, "WaitPrompt=")) {
            newVal := RegExReplace(newVal, "[^\d]", "")
            if (newVal == "")
                newVal := "100"
        }
    }

    editorSteps[row].type := newType
    editorSteps[row].val := newVal
    desc := GetStepHumanDescription(newType, newVal)

    lvSteps.Modify(row, "", Format("{:02}", row), newType, desc, newVal)
    OnStepSelected(lvSteps, row)
    UpdateStatus("Paso " . row . " actualizado: " . desc)
}

MoveStepUp(*) {
    global lvSteps, editorSteps
    row := lvSteps.GetNext()
    if (row <= 1)
        return

    temp := editorSteps[row]
    editorSteps[row] := editorSteps[row - 1]
    editorSteps[row - 1] := temp

    RefreshStepListView(row - 1)
}

MoveStepDown(*) {
    global lvSteps, editorSteps
    row := lvSteps.GetNext()
    if (row == 0 || row >= editorSteps.Length)
        return

    temp := editorSteps[row]
    editorSteps[row] := editorSteps[row + 1]
    editorSteps[row + 1] := temp

    RefreshStepListView(row + 1)
}

DeleteStep(*) {
    global lvSteps, editorSteps
    row := lvSteps.GetNext()
    if (row == 0) {
        MsgBox("Selecciona un paso para eliminar.", "Editor de Pasos", "Icon! 262144")
        return
    }

    editorSteps.RemoveAt(row)
    newRow := (row > editorSteps.Length) ? editorSteps.Length : row
    RefreshStepListView(newRow)
    UpdateStatus("Paso eliminado")
}

DuplicateStep(*) {
    global lvSteps, editorSteps
    row := lvSteps.GetNext()
    if (row == 0) {
        MsgBox("Selecciona un paso para duplicar.", "Editor de Pasos", "Icon! 262144")
        return
    }

    copied := {type: editorSteps[row].type, val: editorSteps[row].val}
    editorSteps.InsertAt(row + 1, copied)
    RefreshStepListView(row + 1)
    UpdateStatus("Paso duplicado")
}

InsertStep(*) {
    global lvSteps, editorSteps, ddlStepType, edtStepVal
    val := Trim(edtStepVal.Text)
    if (val == "") {
        MsgBox("Ingresa un valor para el nuevo paso.", "Editor de Pasos", "Icon! 262144")
        return
    }

    newType := ddlStepType.Text
    if (newType == "Tecla Especial" && !RegExMatch(val, "^\{.+\}$")) {
        val := "{" . val . "}"
    } else if (newType == "Pausa (ms)" && !InStr(val, "WaitPrompt=")) {
        val := RegExReplace(val, "[^\d]", "")
        if (val == "")
            val := "100"
    }

    newStep := {type: newType, val: val}

    row := lvSteps.GetNext()
    if (row == 0) {
        editorSteps.Push(newStep)
        insertIdx := editorSteps.Length
    } else {
        editorSteps.InsertAt(row + 1, newStep)
        insertIdx := row + 1
    }

    RefreshStepListView(insertIdx)
    UpdateStatus("Nuevo paso insertado en la posicion " . insertIdx)
}

RefreshStepListView(selectIndex := 1) {
    global lvSteps, editorSteps
    lvSteps.Delete()
    for idx, step in editorSteps {
        desc := GetStepHumanDescription(step.type, step.val)
        lvSteps.Add("", Format("{:02}", idx), step.type, desc, step.val)
    }
    if (selectIndex > 0 && selectIndex <= editorSteps.Length) {
        lvSteps.Modify(selectIndex, "Select Focus")
        OnStepSelected(lvSteps, selectIndex)
    }
}

HighlightStepOnPOS(*) {
    global lvSteps, editorSteps
    row := lvSteps.GetNext()
    if (row <= 0 || row > editorSteps.Length) {
        MsgBox("Selecciona primero un paso en la lista.", "Mira Visual POS", "Icon! 262144")
        return
    }

    step := editorSteps[row]
    if (step.type != "Clic UIA (Boton)" && step.type != "Clic Raton") {
        MsgBox("El paso seleccionado (#" . row . " - " . step.type . ") no es un clic de raton o boton.`nSelecciona un paso de tipo 'Clic UIA' o 'Clic Raton' para visualizar donde caera en Xstore.",
            "Mira Visual POS", "Iconi 262144")
        return
    }

    rawX := 0
    rawY := 0
    if RegExMatch(step.val, 'i)Fallback=\s*(-?\d+)\s*,\s*(-?\d+)', &mFb) {
        rawX := Integer(mFb[1])
        rawY := Integer(mFb[2])
    } else if RegExMatch(step.val, '(-?\d+)\s*,\s*(-?\d+)', &mXy) {
        rawX := Integer(mXy[1])
        rawY := Integer(mXy[2])
    }

    if (rawX == 0 && rawY == 0) {
        MsgBox("Este paso no contiene coordenadas para previsualizar.", "Mira Visual POS", "Icon! 262144")
        return
    }

    hwnd := EnsureTargetWindowActive()
    if (!hwnd) {
        MsgBox("No se detecto la ventana de Xstore / POS activa para mostrar la mira.", "Mira Visual POS", "Icon! 262144")
        return
    }

    scaledX := rawX
    scaledY := rawY
    ResolveProportionalCoords(step.val, rawX, rawY, &scaledX, &scaledY)

    wX := 0, wY := 0
    try WinGetPos(&wX, &wY, , , "ahk_id " . hwnd)
    screenX := wX + scaledX
    screenY := wY + scaledY

    desc := GetStepHumanDescription(step.type, step.val)
    ShowClickReticleOverlay(screenX, screenY, "Paso #" . row . ": " . desc . " (" . scaledX . ", " . scaledY . ")")
    UpdateStatus("Mostrando mira en Xstore: (" . scaledX . ", " . scaledY . ") - " . desc)
}

TestSingleSelectedStep(*) {
    global lvSteps, editorSteps, isPlaying, isRecording, mainGui
    if (isPlaying || isRecording)
        return

    row := lvSteps.GetNext()
    if (row <= 0 || row > editorSteps.Length) {
        MsgBox("Selecciona un paso de la lista para probarlo en Xstore.", "Probar Paso", "Icon! 262144")
        return
    }

    hwnd := EnsureTargetWindowActive()
    if (!hwnd) {
        MsgBox("No se encontro la ventana de Xstore / POS para probar el paso.", "Probar Paso", "Iconx 262144")
        return
    }

    step := editorSteps[row]
    singleLine := StepObjectToMacroLine(step)
    desc := GetStepHumanDescription(step.type, step.val)
    UpdateStatus("Probando paso #" . row . ": " . desc)
    try WinSetTransparent(150, mainGui)
    ShowFloatingMiniHUD("[PROBANDO PASO #" . Format("{:02}", row) . "]", desc, "Ejecucion unitaria desde el Editor")

    Sleep(200)
    ExecuteSingleMacroLine(singleLine, "")
    try WinSetTransparent("Off", mainGui)
    SetTimer(HideFloatingMiniHUD, -1200)

    if (row < editorSteps.Length) {
        lvSteps.Modify(row, "-Select")
        lvSteps.Modify(row + 1, "Select Focus Vis")
        OnStepSelected(lvSteps, row + 1)
    }
}

RunMacroFromSelectedStep(*) {
    global lvSteps, editorSteps, currentEditingMacro, macroFolder, ddlMacros
    row := lvSteps.GetNext()
    if (row <= 0 || row > editorSteps.Length) {
        MsgBox("Selecciona el paso desde el cual deseas iniciar la ejecucion.", "Ejecutar Desde Aqui", "Icon! 262144")
        return
    }

    if (currentEditingMacro != "") {
        fullPath := macroFolder . "\" . currentEditingMacro
        fileContent := GenerateMacroFileContent(currentEditingMacro, editorSteps)
        try {
            if FileExist(fullPath)
                FileDelete(fullPath)
            FileAppend(fileContent, fullPath, "UTF-8")
            RefreshMacroList(currentEditingMacro)
            try ddlMacros.Text := currentEditingMacro
        }
    }

    StartAutomation(row)
}

ShowBatchOptimizerDialog(*) {
    global editorSteps, mainGui
    if (editorSteps.Length == 0) {
        MsgBox("Carga primero una macro en el Editor de Pasos.", "Optimizador Masivo", "Icon! 262144")
        return
    }

    optGui := Gui("+Owner" . mainGui.Hwnd . " +AlwaysOnTop -MinimizeBox -MaximizeBox", "Optimizador Masivo de Macro")
    optGui.BackColor := "D9EBF7"
    optGui.SetFont("s9", "Segoe UI")

    optGui.Add("GroupBox", "x16 y12 w368 h105", "1. Buscar y Reemplazar SKU / Texto en toda la Macro")
    optGui.Add("Text", "x28 y38 w90 h20 c153858", "Buscar valor:")
    edtFind := optGui.Add("Edit", "x122 y35 w246 h23 BackgroundFFFFFF", "100000046")
    optGui.Add("Text", "x28 y68 w90 h20 c153858", "Reemplazar por:")
    edtRep := optGui.Add("Edit", "x122 y65 w150 h23 BackgroundFFFFFF", "")
    btnDoReplace := optGui.Add("Button", "x278 y64 w90 h25", "Reemplazar")

    optGui.Add("GroupBox", "x16 y126 w368 h90", "2. Optimizar Pausas Excesivas (Sleep)")
    optGui.Add("Text", "x28 y150 w235 h20 c153858", "Limitar cualquier pausa mayor a (ms):")
    edtMaxSleep := optGui.Add("Edit", "x265 y147 w103 h23 Number Center BackgroundFFFFFF", "2000")
    btnCapSleeps := optGui.Add("Button", "x28 y178 w340 h28", "Recortar Pausas Largas Ahora")

    btnCloseOpt := optGui.Add("Button", "x130 y226 w140 h32", "Cerrar")

    btnDoReplace.OnEvent("Click", (*) => ApplyBatchSkuReplace(edtFind.Text, edtRep.Text, optGui))
    btnCapSleeps.OnEvent("Click", (*) => ApplyBatchSleepCap(edtMaxSleep.Text, optGui))
    btnCloseOpt.OnEvent("Click", (*) => optGui.Destroy())

    optGui.Show("w400 h270")
}

ApplyBatchSkuReplace(findStr, repStr, parentModal) {
    global editorSteps
    findStr := Trim(findStr)
    repStr := Trim(repStr)
    if (findStr == "") {
        MsgBox("Ingresa el SKU o texto a buscar.", "Reemplazo Masivo", "Icon! 262144")
        return
    }
    count := 0
    for idx, step in editorSteps {
        if InStr(step.val, findStr) {
            step.val := StrReplace(step.val, findStr, repStr)
            count++
        }
    }
    RefreshStepListView(1)
    parentModal.Destroy()
    MsgBox("Se actualizaron " . count . " paso(s) reemplazando '" . findStr . "' por '" . repStr . "'.`nRecuerda presionar 'GUARDAR CAMBIOS' para persistir el archivo.",
        "Reemplazo Masivo", "Iconi 262144")
}

ApplyBatchSleepCap(maxSleepStr, parentModal) {
    global editorSteps
    maxMs := Integer(RegExReplace(maxSleepStr, "[^\d]", ""))
    if (maxMs < 100)
        maxMs := 100
    count := 0
    for idx, step in editorSteps {
        if (step.type == "Pausa (ms)") {
            if RegExMatch(step.val, "^(\d+)(.*)$", &m) {
                curMs := Integer(m[1])
                rest := m[2]
                if (curMs > maxMs) {
                    step.val := maxMs . rest
                    count++
                }
            }
        }
    }
    RefreshStepListView(1)
    parentModal.Destroy()
    MsgBox("Se optimizaron " . count . " pausa(s) limitandolas a un maximo de " . maxMs . " ms.`nRecuerda presionar 'GUARDAR CAMBIOS' para persistir el archivo.",
        "Optimizador de Pausas", "Iconi 262144")
}

SaveMacroChanges(*) {
    global editorSteps, currentEditingMacro, macroFolder, ddlMacros, lvSteps, ddlStepType, edtStepVal
    if (currentEditingMacro == "") {
        MsgBox("No hay ninguna macro cargada en el editor.", "Editor de Pasos", "Icon! 262144")
        return
    }

    row := lvSteps.GetNext()
    if (row > 0 && row <= editorSteps.Length && Trim(edtStepVal.Text) != "") {
        newVal := Trim(edtStepVal.Text)
        newType := ddlStepType.Text
        if (newType == "Tecla Especial" && !RegExMatch(newVal, "^\{.+\}$"))
            newVal := "{" . newVal . "}"
        else if (newType == "Pausa (ms)" && !InStr(newVal, "WaitPrompt=")) {
            newVal := RegExReplace(newVal, "[^\d]", "")
            if (newVal == "")
                newVal := "100"
        }
        editorSteps[row].type := newType
        editorSteps[row].val := newVal
        desc := GetStepHumanDescription(newType, newVal)
        lvSteps.Modify(row, "", Format("{:02}", row), newType, desc, newVal)
    }

    if (editorSteps.Length == 0) {
        MsgBox("La macro no contiene ningun paso.", "Editor de Pasos", "Icon! 262144")
        return
    }

    fullPath := macroFolder . "\" . currentEditingMacro
    fileContent := GenerateMacroFileContent(currentEditingMacro, editorSteps)

    try {
        if FileExist(fullPath)
            FileDelete(fullPath)
        FileAppend(fileContent, fullPath, "UTF-8")
        RefreshMacroList(currentEditingMacro)
        try ddlMacros.Text := currentEditingMacro
        UpdateStatus("Macro guardada con exito: " . currentEditingMacro)
        MsgBox("¡Cambios guardados exitosamente!`n`nArchivo: " . currentEditingMacro . "`nPasos: " . editorSteps.Length . "`n`nLa macro editada ya se encuentra seleccionada en la pestaña 'Automatizar'.",
            "Editor de Pasos", "Iconi 262144")
    } catch Error as err {
        MsgBox("Error al guardar la macro: " . err.Message, "Editor de Pasos", "Iconx 262144")
    }
}

SaveAsMacro(*) {
    global editorSteps, currentEditingMacro, macroFolder, ddlMacros, lvSteps, ddlStepType, edtStepVal
    row := lvSteps.GetNext()
    if (row > 0 && row <= editorSteps.Length && Trim(edtStepVal.Text) != "") {
        newVal := Trim(edtStepVal.Text)
        newType := ddlStepType.Text
        if (newType == "Tecla Especial" && !RegExMatch(newVal, "^\{.+\}$"))
            newVal := "{" . newVal . "}"
        else if (newType == "Pausa (ms)" && !InStr(newVal, "WaitPrompt=")) {
            newVal := RegExReplace(newVal, "[^\d]", "")
            if (newVal == "")
                newVal := "100"
        }
        editorSteps[row].type := newType
        editorSteps[row].val := newVal
        desc := GetStepHumanDescription(newType, newVal)
        lvSteps.Modify(row, "", Format("{:02}", row), newType, desc, newVal)
    }

    if (editorSteps.Length == 0) {
        MsgBox("No hay pasos para guardar.", "Editor de Pasos", "Icon! 262144")
        return
    }

    suggested := RegExReplace(currentEditingMacro, "\.txt$", "") . "_v2.txt"
    if (suggested == "_v2.txt" || suggested == "")
        suggested := "Transaccion_Editada_" . FormatTime(, "yyyyMMdd_HHmmss") . ".txt"

    ib := InputBox("Ingresa el nombre para la nueva macro:", "Guardar Macro Como", , suggested)
    if (ib.Result != "OK" || Trim(ib.Value) == "")
        return

    newName := Trim(ib.Value)
    if (!RegExMatch(newName, "\.txt$"))
        newName .= ".txt"

    fullPath := macroFolder . "\" . newName
    fileContent := GenerateMacroFileContent(newName, editorSteps)

    try {
        if FileExist(fullPath)
            FileDelete(fullPath)
        FileAppend(fileContent, fullPath, "UTF-8")
        currentEditingMacro := newName
        RefreshMacroList(newName)
        try ddlMacros.Text := newName
        UpdateStatus("Nueva macro guardada: " . newName)
        MsgBox("¡Nueva macro creada exitosamente!`n`nArchivo: " . newName . "`nPasos: " . editorSteps.Length . "`n`nYa se encuentra seleccionada en la pestaña 'Automatizar'.",
            "Editor de Pasos", "Iconi 262144")
    } catch Error as err {
        MsgBox("Error al guardar nueva macro: " . err.Message, "Editor de Pasos", "Iconx 262144")
    }
}

StepObjectToMacroLine(step) {
    if (step.type == "Pausa (ms)")
        return "Sleep, " . step.val
    else if (step.type == "Esperar Prompt (Log)") {
        val := step.val
        if (SubStr(val, 1, 11) == "WaitPrompt," || SubStr(val, 1, 8) == "WaitLog,")
            return val
        return "WaitPrompt, " . val
    } else if (step.type == "Tecla Especial") {
        k := step.val
        if (!RegExMatch(k, "^\{.+\}$"))
            k := "{" . k . "}"
        return "Send, " . k
    } else if (step.type == "Clic UIA (Boton)") {
        val := step.val
        if (SubStr(val, 1, 10) == "UIA_Click,")
            return val
        return "UIA_Click, " . val
    } else if (step.type == "Clic Raton") {
        val := step.val
        if (SubStr(val, 1, 11) == "MouseClick," || SubStr(val, 1, 6) == "Click,")
            return val
        return "MouseClick, " . val
    } else if (step.type == "Comando") {
        return step.val
    }
    return "Send, " . step.val
}

GenerateMacroFileContent(name, steps) {
    out := "; Macro de Transaccion para Terminal POS`n"
    out .= "; Archivo: " . name . "`n"
    out .= "; Fecha de Edicion: " . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "`n`n"
    for step in steps {
        out .= StepObjectToMacroLine(step) . "`n"
    }
    return out
}

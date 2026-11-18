; ==============================================================================
; MODULE: src\Core\Updater.ahk
; PURPOSE: Gestor de actualizaciones automáticas vía GitHub Releases API
; ==============================================================================

CleanJSONString(str) {
    str := StrReplace(str, "\r\n", "`r`n")
    str := StrReplace(str, "\n", "`r`n")
    str := StrReplace(str, "\t", "    ")
    str := StrReplace(str, '\"', '"')
    str := StrReplace(str, "\\", "\")
    return str
}

CompareVersions(v1, v2) {
    v1 := RegExReplace(v1, "^v", "")
    v2 := RegExReplace(v2, "^v", "")
    p1 := StrSplit(v1, ".")
    p2 := StrSplit(v2, ".")
    loop 3 {
        n1 := (p1.Length >= A_Index) ? Integer(p1[A_Index]) : 0
        n2 := (p2.Length >= A_Index) ? Integer(p2[A_Index]) : 0
        if (n1 > n2)
            return 1
        if (n1 < n2)
            return -1
    }
    return 0
}

CheckForUpdates(showFeedback := true) {
    global appVersion, latestReleaseUrl, latestZipDownloadUrl
    global txtRemoteVer, txtUpdateState, edtReleaseNotes, btnDownloadZip, btnHeaderUpdate

    txtUpdateState.Text := "Consultando API de GitHub Releases..."
    try {
        req := ComObject("Msxml2.ServerXMLHTTP.6.0")
        req.setTimeouts(3000, 3000, 3000, 5000)
        req.Open("GET", "https://api.github.com/repos/EfrainSN/QA-POS-Automation-Macro/releases/latest", false)
        req.SetRequestHeader("User-Agent", "QA-POS-Automation-Macro")
        req.SetRequestHeader("Accept", "application/vnd.github.v3+json")
        req.Send()

        if (req.Status != 200) {
            txtUpdateState.Text := "Error de servidor HTTP " . req.Status
            if (showFeedback)
                MsgBox("No se pudo verificar actualizaciones (HTTP " . req.Status . ").", "Actualizaciones", "Icon! 262144")
            return
        }

        resp := req.ResponseText
        remoteTag := ""
        if RegExMatch(resp, '\"tag_name\":\s*\"([^\"]+)\"', &mTag)
            remoteTag := mTag[1]

        releaseTitle := ""
        if RegExMatch(resp, '\"name\":\s*\"([^\"]+)\"', &mName)
            releaseTitle := CleanJSONString(mName[1])

        releaseUrl := ""
        if RegExMatch(resp, '\"html_url\":\s*\"([^\"]+)\"', &mUrl)
            releaseUrl := mUrl[1]
        if (releaseUrl != "")
            latestReleaseUrl := releaseUrl

        bodyText := ""
        if RegExMatch(resp, '\"body\":\s*\"(.*?)(?<!\\)\"', &mBody)
            bodyText := CleanJSONString(mBody[1])

        zipUrl := ""
        if RegExMatch(resp, '\"browser_download_url\":\s*\"([^\"]+Portable\.zip)\"', &mZip)
            zipUrl := mZip[1]
        latestZipDownloadUrl := zipUrl

        comp := CompareVersions(remoteTag, appVersion)
        if (comp > 0) {
            txtRemoteVer.Text := remoteTag . " (Nueva Version Disponible)"
            txtUpdateState.Text := "Existe una nueva version disponible para descargar."
            btnHeaderUpdate.Text := "Nueva Version!"
            btnDownloadZip.Enabled := (latestZipDownloadUrl != "")
            if (showFeedback) {
                MsgBox("Hay una nueva version disponible en GitHub:`n`nInstalada: v" . appVersion . "`nDisponible: " . remoteTag .
                    "`n`nPuedes revisar las novedades o descargar el paquete portable.", "Actualizaciones", "Iconi 262144")
            }
        } else {
            txtRemoteVer.Text := remoteTag . " (Al dia)"
            txtUpdateState.Text := "Tu aplicacion esta actualizada a la version mas reciente."
            btnHeaderUpdate.Text := "v" . appVersion . " (Al dia)"
            btnDownloadZip.Enabled := (latestZipDownloadUrl != "")
            if (showFeedback) {
                MsgBox("Tu version (v" . appVersion . ") esta completamente actualizada.`nNo hay nuevas versiones pendientes.",
                    "Actualizaciones", "Iconi 262144")
            }
        }

        displayText := "VERSION EN GITHUB: " . remoteTag . "`r`n"
        displayText .= "TITULO: " . releaseTitle . "`r`n"
        displayText .= "ENLACE: " . latestReleaseUrl . "`r`n`r`n"
        displayText .= "--- NOVEDADES Y NOTAS DE LA VERSION ---`r`n"
        displayText .= (bodyText != "") ? bodyText : "(Sin notas de version declaradas)"
        edtReleaseNotes.Text := displayText

    } catch Error as err {
        txtUpdateState.Text := "No se pudo conectar a GitHub (Modo offline)."
        if (showFeedback) {
            MsgBox("No se pudo conectar con GitHub.`nTerminal sin conexion a internet o bloqueada por firewall.`n`nDetalle: " . err.Message,
                "Actualizaciones", "Icon! 262144")
        }
    }
}

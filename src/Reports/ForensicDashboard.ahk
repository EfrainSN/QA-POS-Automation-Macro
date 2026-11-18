; ==============================================================================
; MODULE: src\Reports\ForensicDashboard.ahk
; PURPOSE: Telemetria en tiempo real, gestion de Biblioteca de Transacciones,
;          visor de Comprobantes (PosLog/FEL) y Dashboard Analitico HTML
; ==============================================================================

UpdateLiveMetricsHUD() {
    global isPlaying, autoTotalCycles, autoCurrentCycle, autoSuccessCount, autoFailCount, autoStartTime, chkInfinite
    global progBar, txtProgress, txtMetricsA, txtMetricsC

    elapsedSec := Round((A_TickCount - autoStartTime) / 1000)
    hours := Format("{:02}", elapsedSec // 3600)
    minutes := Format("{:02}", Mod(elapsedSec, 3600) // 60)
    seconds := Format("{:02}", Mod(elapsedSec, 60))
    timeFormatted := hours . ":" . minutes . ":" . seconds

    if (chkInfinite.Value == 1) {
        progBar.Value := 100
        txtProgress.Text := "Transaccion " . autoCurrentCycle . " (Modo Continuo)"
    } else {
        pct := (autoTotalCycles > 0) ? Integer((autoCurrentCycle / autoTotalCycles) * 100) : 0
        progBar.Value := pct
        txtProgress.Text := "Transaccion: " . autoCurrentCycle . " de " . autoTotalCycles . " (" . pct . "%)"
    }

    txtMetricsA.Text := "Tiempo: " . timeFormatted
    txtMetricsC.Text := "Completadas: " . autoSuccessCount
}

ReloadLibraryTransactionsFromPosLog(*) {
    global autoAuditRecords, libraryTransactions
    if (autoAuditRecords.Length > 0) {
        libraryTransactions := autoAuditRecords
    } else {
        libraryTransactions := LoadTransactionsFromPosLogFile(50)
    }
    RefreshLibraryTransactionsView()
}

RefreshLibraryTransactionsView() {
    global lvLibTrans, libraryTransactions, autoAuditRecords, posLogPath
    global txtRepInfo1, txtRepInfo2, txtRepInfo3, txtRepInfo4, txtRepInfo5

    if (!IsObject(lvLibTrans))
        return

    records := (autoAuditRecords.Length > 0) ? autoAuditRecords : libraryTransactions
    lvLibTrans.Delete()

    okCount := 0
    failCount := 0
    recovCount := 0
    totalSec := 0.0
    totalAmount := 0.0
    certifiedTickets := 0
    currencyCode := "GTQ"

    for idx, rec in records {
        if (rec.status == "COMPLETADO")
            okCount++
        else if InStr(rec.status, "RECUPERADO") {
            recovCount++
            failCount++
        } else {
            failCount++
        }

        totalSec += rec.durationSec

        tSeq := "--"
        docType := "--"
        custInfo := "--"
        tenderInfo := "--"
        totStr := "--"

        if (rec.HasOwnProp("ticket") && IsObject(rec.ticket)) {
            tk := rec.ticket
            if (tk.transSeq != "") {
                tSeq := "#" . tk.transSeq
                certifiedTickets++
            }
            if (tk.docType != "")
                docType := tk.docType
            if (tk.currency != "")
                currencyCode := tk.currency

            if (tk.customerDocNumber != "" && tk.customerName != "")
                custInfo := tk.customerDocNumber . " - " . SubStr(tk.customerName, 1, 18)
            else if (tk.customerName != "")
                custInfo := SubStr(tk.customerName, 1, 22)
            else if (tk.customerDocNumber != "")
                custInfo := "NIT: " . tk.customerDocNumber

            if (tk.primaryTender != "") {
                tenderInfo := StrReplace(tk.primaryTender, "TARJETA_", "")
                if (tk.vtolAuthCode != "")
                    tenderInfo .= " [" . tk.vtolAuthCode . "]"
            }

            totalAmount += tk.grandTotal
            totStr := tk.currency . " " . Format("{:.2f}", tk.grandTotal)
        } else if (rec.reason != "") {
            docType := rec.reason
            custInfo := SubStr(rec.detail, 1, 26)
        }

        lvLibTrans.Add("", Format("{:02}", rec.cycle), tSeq, docType, custInfo, tenderInfo, totStr, rec.durationSec . "s", rec.status)
    }

    if (records.Length > 0) {
        lvLibTrans.Modify(records.Length, "Select Focus Vis")
    }

    totalRuns := records.Length
    avgSec := (totalRuns > 0) ? Round(totalSec / totalRuns, 2) : 0.0
    rate := (totalRuns > 0) ? Round((okCount / totalRuns) * 100, 1) : 100.0

    if IsObject(txtRepInfo1) {
        srcLabel := (autoAuditRecords.Length > 0) ? "Sesion Activa de Automatizacion" : ("PosLog (" . posLogPath . ")")
        txtRepInfo1.Text := "Fuente: " . srcLabel
        txtRepInfo2.Text := "Transacciones: " . totalRuns . " (" . okCount . " OK / " . failCount . " Err)"
        txtRepInfo3.Text := "Volumen: " . currencyCode . " " . Format("{:.2f}", totalAmount)
        txtRepInfo4.Text := "Latencia Media: " . avgSec . "s | Total: " . Round(totalSec, 1) . "s"
        txtRepInfo5.Text := "Exito: " . rate . "% | Tickets: " . certifiedTickets
    }
}

UpdateReportsTabSummary() {
    global autoAuditRecords, libraryTransactions
    if (autoAuditRecords.Length > 0)
        libraryTransactions := autoAuditRecords
    RefreshLibraryTransactionsView()
}

ViewSelectedTransactionTicket(*) {
    global lvLibTrans, libraryTransactions, autoAuditRecords, ticketsFolder
    records := (autoAuditRecords.Length > 0) ? autoAuditRecords : libraryTransactions
    if (records.Length == 0) {
        ReloadLibraryTransactionsFromPosLog()
        records := (autoAuditRecords.Length > 0) ? autoAuditRecords : libraryTransactions
    }

    if (records.Length == 0) {
        MsgBox("No hay transacciones cargadas en la Biblioteca.`nEjecuta una macro o configura la ruta de PosLog.xml.", "Comprobante POS", "Iconi 262144")
        return
    }

    row := IsObject(lvLibTrans) ? lvLibTrans.GetNext() : 0
    if (row <= 0 || row > records.Length)
        row := records.Length

    rec := records[row]
    EnsureRequiredDirectories()
    seqTag := (rec.HasOwnProp("ticket") && IsObject(rec.ticket) && rec.ticket.transSeq != "") ? rec.ticket.transSeq : ("Ciclo_" . rec.cycle)
    outFile := ticketsFolder . "\Comprobante_Trans_" . seqTag . ".html"
    html := BuildStandaloneTicketDocumentHTML(rec)

    try {
        if FileExist(outFile)
            FileDelete(outFile)
        FileAppend(html, outFile, "UTF-8")
        Run(outFile)
    } catch Error as err {
        MsgBox("No se pudo generar el comprobante HTML: " . err.Message, "Comprobante POS", "Iconx 262144")
    }
}

OpenLastCSVReport(*) {
    global autoCurrentCSV, reportsFolder
    EnsureRequiredDirectories()
    if (autoCurrentCSV != "" && FileExist(autoCurrentCSV)) {
        Run(autoCurrentCSV)
    } else {
        latestFile := ""
        latestTime := ""
        loop files, reportsFolder . "\*.csv" {
            if (A_LoopFileTimeModified > latestTime) {
                latestTime := A_LoopFileTimeModified
                latestFile := A_LoopFileFullPath
            }
        }
        if (latestFile != "")
            Run(latestFile)
        else
            MsgBox("Aun no se han generado registros CSV de transacciones.", "QA POS Automation", "Iconi 262144")
    }
}

OpenLastHTMLDashboard(*) {
    global autoCurrentHTML, autoAuditRecords, libraryTransactions, reportsFolder
    EnsureRequiredDirectories()

    if (autoCurrentHTML != "" && FileExist(autoCurrentHTML)) {
        Run(autoCurrentHTML)
        return
    }

    ; Si no se ha corrido una macro en esta sesion pero hay PosLog.xml, generar Dashboard desde PosLog.xml
    if (autoAuditRecords.Length == 0) {
        if (libraryTransactions.Length == 0)
            ReloadLibraryTransactionsFromPosLog()
        if (libraryTransactions.Length > 0) {
            autoCurrentHTML := reportsFolder . "\Reporte_Dashboard_PosLog_" . FormatTime(, "yyyyMMdd_HHmmss") . ".html"
            GenerateHTMLDashboardReport("Auditoria_PosLog.xml", libraryTransactions)
            if FileExist(autoCurrentHTML) {
                Run(autoCurrentHTML)
                return
            }
        }
    }

    latestFile := ""
    latestTime := ""
    loop files, reportsFolder . "\*.html" {
        if (A_LoopFileTimeModified > latestTime) {
            latestTime := A_LoopFileTimeModified
            latestFile := A_LoopFileFullPath
        }
    }
    if (latestFile != "")
        Run(latestFile)
    else
        MsgBox("No se encontraron reportes HTML previos ni transacciones en PosLog.xml.", "Dashboard Forense", "Iconi 262144")
}

EscapeHTML(str) {
    str := StrReplace(String(str), "&", "&amp;")
    str := StrReplace(str, "<", "&lt;")
    str := StrReplace(str, ">", "&gt;")
    str := StrReplace(str, '"', "&quot;")
    return str
}

BuildTicketReceiptCardHTML(rec) {
    if (!rec.HasOwnProp("ticket") || !IsObject(rec.ticket)) {
        return "<div class='empty-ticket'>Sin comprobante PosLog/FEL asociado para este ciclo (Transaccion abortada o sin registro XML).</div>"
    }

    tk := rec.ticket
    h := "<div class='receipt-grid'>"
    h .= "<div class='receipt-paper'>"
    h .= "<div class='rcpt-header'>"
    h .= "<div class='rcpt-brand'>COMPROBANTE TRANSACCIONAL XSTORE POS</div>"
    h .= "<div class='rcpt-sub'>TIENDA: " . EscapeHTML(tk.storeId != "" ? tk.storeId : "N/D")
        . " &nbsp;|&nbsp; CAJA: " . EscapeHTML(tk.wkstnId != "" ? tk.wkstnId : "1")
        . " &nbsp;|&nbsp; CAJERO: " . EscapeHTML(tk.operatorId != "" ? tk.operatorId : "N/D") . "</div>"
    h .= "<div class='rcpt-sub'>TRANS_SEQ: <b>#" . EscapeHTML(tk.transSeq) . "</b> &nbsp;|&nbsp; FECHA: " . EscapeHTML(tk.endTime != "" ? tk.endTime : tk.businessDate) . "</div>"
    h .= "</div>"

    h .= "<div class='rcpt-section'>"
    h .= "<div class='rcpt-row'><span>TIPO DOCUMENTO:</span><strong>" . EscapeHTML(tk.docType) . "</strong></div>"
    if (tk.t2aDocType != "")
        h .= "<div class='rcpt-row'><span>PROPIEDAD T2A:</span><strong>" . EscapeHTML(tk.t2aDocType) . "</strong></div>"
    if (tk.customerName != "")
        h .= "<div class='rcpt-row'><span>CLIENTE:</span><strong>" . EscapeHTML(tk.customerName) . "</strong></div>"
    if (tk.customerDocNumber != "")
        h .= "<div class='rcpt-row'><span>DOC / NIT:</span><strong>" . EscapeHTML(tk.customerDocNumber) . "</strong></div>"
    if (tk.customerAccount != "")
        h .= "<div class='rcpt-row'><span>CUENTA CLIENTE:</span><strong>" . EscapeHTML(tk.customerAccount) . "</strong></div>"
    if (tk.invoiceSeries != "" || tk.invoicePreimpreso != "")
        h .= "<div class='rcpt-row'><span>SERIE / PREIMPRESO:</span><strong>" . EscapeHTML(tk.invoiceSeries) . " - " . EscapeHTML(tk.invoicePreimpreso) . "</strong></div>"
    if (tk.invoiceControlNumber != "")
        h .= "<div class='rcpt-row'><span>NUMERO CONTROL DTE:</span><strong>" . EscapeHTML(tk.invoiceControlNumber) . "</strong></div>"
    if (tk.invoiceUuid != "")
        h .= "<div class='rcpt-row'><span>UUID / AUTORIZACION:</span><strong class='mono-sm'>" . EscapeHTML(tk.invoiceUuid) . "</strong></div>"
    if (tk.invoiceReference != "")
        h .= "<div class='rcpt-row'><span>REFERENCIA INTERNA:</span><strong class='mono-sm'>" . EscapeHTML(tk.invoiceReference) . "</strong></div>"
    h .= "</div>"

    h .= "<table class='rcpt-table'><thead><tr><th>SKU / CODIGO</th><th>DESCRIPCION</th><th class='num'>CANT</th><th class='num'>PRECIO</th><th class='num'>IVA</th><th class='num'>SUBTOTAL</th></tr></thead><tbody>"
    if (tk.items.Length > 0) {
        for itm in tk.items {
            h .= "<tr><td class='mono'>" . EscapeHTML(itm.itemId) . "</td>"
            h .= "<td>" . EscapeHTML(itm.description) . " <span class='tag-mini'>" . EscapeHTML(itm.lineType) . "</span></td>"
            h .= "<td class='num'>" . itm.qty . "</td>"
            h .= "<td class='num'>" . Format("{:.2f}", itm.unitPrice) . "</td>"
            h .= "<td class='num'>" . Format("{:.2f}", itm.taxAmount) . "</td>"
            h .= "<td class='num'><strong>" . Format("{:.2f}", itm.extendedAmount) . "</strong></td></tr>"
        }
    } else {
        h .= "<tr><td colspan='6' style='text-align:center;color:#64748B'>Sin desglose de lineas de articulos</td></tr>"
    }
    h .= "</tbody></table>"

    h .= "<div class='rcpt-totals'>"
    netWithoutTax := tk.grandTotal - tk.taxTotal
    h .= "<div class='rcpt-row'><span>MONTO BASE SIN IVA:</span><span>" . EscapeHTML(tk.currency) . " " . Format("{:.2f}", netWithoutTax) . "</span></div>"
    h .= "<div class='rcpt-row'><span>IMPUESTO (IVA):</span><span>" . EscapeHTML(tk.currency) . " " . Format("{:.2f}", tk.taxTotal) . "</span></div>"
    h .= "<div class='rcpt-row rcpt-grand'><span>TOTAL TRANSACCION:</span><span>" . EscapeHTML(tk.currency) . " " . Format("{:.2f}", tk.grandTotal) . "</span></div>"
    h .= "</div>"

    if (tk.tenders.Length > 0) {
        h .= "<div class='rcpt-section'>"
        h .= "<div class='rcpt-sec-title'>LIQUIDACION Y MEDIOS DE PAGO (VTOL / CAJA)</div>"
        for tnd in tk.tenders {
            extraVtol := ""
            if (tnd.authCode != "")
                extraVtol .= " | AUT: " . tnd.authCode
            if (tnd.vtolTicket != "")
                extraVtol .= " | TKT: " . tnd.vtolTicket
            if (tnd.cardSeries != "")
                extraVtol .= " | SERIE: " . tnd.cardSeries
            if (tnd.onlineMode != "")
                extraVtol .= " | " . tnd.onlineMode
            if (tnd.vtolStatus != "")
                extraVtol .= " [" . tnd.vtolStatus . "]"

            h .= "<div class='rcpt-row'><span>" . EscapeHTML(tnd.tenderId) . EscapeHTML(extraVtol) . "</span><strong>" . EscapeHTML(tk.currency) . " " . Format("{:.2f}", tnd.amount) . "</strong></div>"
        }
        h .= "</div>"
    }

    if (tk.pdfUrl != "") {
        h .= "<div style='margin-top:12px'><a class='btn-link' href='" . EscapeHTML(tk.pdfUrl) . "' target='_blank'>ABRIR PDF FISCAL CERTIFICADO (INFILE DTE)</a></div>"
    }
    h .= "</div>"

    h .= "<div class='receipt-raw'>"
    h .= "<div class='raw-title'>FUENTE CRUDA (" . EscapeHTML(tk.sourceType) . " - TRANS #" . EscapeHTML(tk.transSeq) . ")</div>"
    h .= "<pre class='raw-pre'>" . EscapeHTML(tk.rawContent) . "</pre>"
    h .= "</div>"
    h .= "</div>"
    return h
}

GetDashboardSharedCSS() {
    css := "
    (
    * { box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: #F1F5F9; color: #0F172A; margin: 0; padding: 0; font-size: 13px; line-height: 1.45; }
    .mono, .num, .kpi-val, .badge, pre, code { font-family: 'Consolas', 'SFMono-Regular', 'Menlo', monospace; font-variant-numeric: tabular-nums; }
    .topbar { background: #0F172A; color: #F8FAFC; padding: 16px 28px; border-bottom: 2px solid #0284C7; display: flex; justify-content: space-between; align-items: center; }
    .topbar-title { font-size: 16px; font-weight: 700; letter-spacing: 0.4px; text-transform: uppercase; color: #F8FAFC; margin: 0; }
    .topbar-meta { font-size: 12px; color: #94A3B8; margin-top: 4px; font-family: 'Consolas', monospace; }
    .topbar-right { text-align: right; font-family: 'Consolas', monospace; font-size: 12px; color: #38BDF8; }
    .container { max-width: 1440px; margin: 0 auto; padding: 20px 28px 40px 28px; }
    .kpi-strip { display: grid; grid-template-columns: repeat(6, 1fr); gap: 12px; margin-bottom: 20px; }
    .kpi-box { background: #FFFFFF; border: 1px solid #CBD5E1; border-top: 3px solid #0F172A; padding: 12px 14px; }
    .kpi-box.ok { border-top-color: #0F766E; }
    .kpi-box.err { border-top-color: #B91C1C; }
    .kpi-box.warn { border-top-color: #B45309; }
    .kpi-box.info { border-top-color: #0284C7; }
    .kpi-lbl { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: #475569; }
    .kpi-val { font-size: 22px; font-weight: 700; color: #0F172A; margin: 6px 0 4px 0; }
    .kpi-sub { font-size: 11px; color: #64748B; font-family: 'Consolas', monospace; }
    .charts-grid { display: grid; grid-template-columns: 1.75fr 1fr; gap: 16px; margin-bottom: 20px; }
    .panel { background: #FFFFFF; border: 1px solid #CBD5E1; margin-bottom: 20px; }
    .panel-hdr { background: #F8FAFC; border-bottom: 1px solid #CBD5E1; padding: 10px 16px; display: flex; justify-content: space-between; align-items: center; }
    .panel-title { font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: #1E293B; margin: 0; }
    .panel-subtitle { font-size: 11px; color: #64748B; font-family: 'Consolas', monospace; }
    .panel-body { padding: 16px; }
    table.data-table { width: 100%; border-collapse: collapse; font-size: 12px; }
    table.data-table th { background: #1E293B; color: #F8FAFC; text-align: left; padding: 9px 10px; font-size: 11px; text-transform: uppercase; letter-spacing: 0.4px; border: 1px solid #1E293B; }
    table.data-table td { padding: 8px 10px; border-bottom: 1px solid #E2E8F0; color: #0F172A; vertical-align: middle; }
    table.data-table tr.main-row:hover { background: #F8FAFC; }
    .num { text-align: right; }
    .badge { display: inline-block; padding: 2px 8px; font-size: 11px; font-weight: 700; border: 1px solid transparent; }
    .badge-ok { background: #F0FDFA; color: #0F766E; border-color: #99F6E4; }
    .badge-heal { background: #FFFBEB; color: #B45309; border-color: #FDE68A; }
    .badge-err { background: #FEF2F2; color: #B91C1C; border-color: #FECACA; }
    .btn-action { background: #0F172A; color: #F8FAFC; border: 1px solid #0F172A; padding: 4px 10px; font-size: 11px; font-family: 'Consolas', monospace; font-weight: 600; cursor: pointer; text-decoration: none; display: inline-block; }
    .btn-action:hover { background: #0284C7; border-color: #0284C7; }
    .btn-link { background: #0284C7; color: #FFFFFF; padding: 6px 12px; font-size: 11px; font-weight: 700; text-decoration: none; display: inline-block; font-family: 'Consolas', monospace; }
    .detail-row { display: none; background: #F8FAFC; }
    .detail-row.open { display: table-row; }
    .detail-cell { padding: 16px !important; border-bottom: 2px solid #94A3B8 !important; }
    .receipt-grid { display: grid; grid-template-columns: 460px 1fr; gap: 16px; align-items: start; }
    .receipt-paper { background: #FFFFFF; border: 1px solid #94A3B8; border-top: 4px solid #0F172A; padding: 16px; font-family: 'Consolas', monospace; font-size: 12px; }
    .rcpt-header { border-bottom: 1px dashed #94A3B8; padding-bottom: 10px; margin-bottom: 10px; text-align: center; }
    .rcpt-brand { font-size: 13px; font-weight: 700; color: #0F172A; }
    .rcpt-sub { font-size: 11px; color: #475569; margin-top: 3px; }
    .rcpt-section { border-bottom: 1px dashed #CBD5E1; padding-bottom: 8px; margin-bottom: 10px; }
    .rcpt-sec-title { font-size: 11px; font-weight: 700; color: #334155; margin-bottom: 6px; text-transform: uppercase; }
    .rcpt-row { display: flex; justify-content: space-between; margin-bottom: 3px; font-size: 11px; }
    .rcpt-totals { border-top: 1px solid #0F172A; border-bottom: 1px dashed #94A3B8; padding: 8px 0; margin: 10px 0; }
    .rcpt-grand { font-size: 13px; font-weight: 700; color: #0F172A; margin-top: 4px; }
    table.rcpt-table { width: 100%; border-collapse: collapse; font-size: 11px; margin: 8px 0; }
    table.rcpt-table th { border-bottom: 1px solid #0F172A; text-align: left; padding: 4px; color: #334155; }
    table.rcpt-table td { padding: 4px; border-bottom: 1px dotted #E2E8F0; }
    .tag-mini { background: #E2E8F0; color: #334155; padding: 1px 4px; font-size: 9px; font-weight: 700; }
    .mono-sm { font-size: 10px; word-break: break-all; }
    .receipt-raw { background: #0F172A; border: 1px solid #334155; padding: 12px; }
    .raw-title { color: #38BDF8; font-family: 'Consolas', monospace; font-size: 11px; font-weight: 700; margin-bottom: 8px; text-transform: uppercase; }
    pre.raw-pre { margin: 0; max-height: 360px; overflow: auto; color: #E2E8F0; font-size: 11px; line-height: 1.4; white-space: pre-wrap; word-break: break-all; }
    .forensic-alert { background: #FEF2F2; border: 1px solid #FECACA; border-left: 4px solid #B91C1C; padding: 12px; margin-bottom: 12px; }
    .forensic-title { font-weight: 700; color: #991B1B; font-size: 12px; margin-bottom: 6px; font-family: 'Consolas', monospace; }
    .shot-img { max-width: 100%; max-height: 380px; border: 1px solid #94A3B8; margin-top: 8px; }
    .dist-row { margin-bottom: 10px; }
    .dist-hdr { display: flex; justify-content: space-between; font-size: 11px; font-family: 'Consolas', monospace; margin-bottom: 3px; }
    .dist-track { background: #E2E8F0; height: 8px; width: 100%; overflow: hidden; }
    .dist-fill { background: #0284C7; height: 100%; }
    )"
    return css
}

BuildStandaloneTicketDocumentHTML(rec) {
    global appVersion
    seqStr := (rec.HasOwnProp("ticket") && IsObject(rec.ticket) && rec.ticket.transSeq != "") ? ("#" . rec.ticket.transSeq) : ("Ciclo #" . rec.cycle)
    html := "<!DOCTYPE html>`n<html lang='es'>`n<head>`n<meta charset='UTF-8'>`n"
    html .= "<title>Comprobante POS " . EscapeHTML(seqStr) . "</title>`n"
    html .= "<style>" . GetDashboardSharedCSS() . "</style>`n</head>`n<body>`n"
    html .= "<div class='topbar'><div><div class='topbar-title'>VISOR DE COMPROBANTE TRANSACCIONAL POSLOG / FEL</div>"
    html .= "<div class='topbar-meta'>TRANSACCION: " . EscapeHTML(seqStr) . " &nbsp;|&nbsp; ESTADO: " . EscapeHTML(rec.status) . "</div></div>"
    html .= "<div class='topbar-right'>QA POS AUTOMATION v" . EscapeHTML(appVersion) . "</div></div>`n"
    html .= "<div class='container'>`n"
    html .= "<div class='panel'><div class='panel-hdr'><div class='panel-title'>DETALLE INTEGRAL DEL COMPROBANTE</div>"
    html .= "<div class='panel-subtitle'>DURACION: " . rec.durationSec . "s (" . rec.durationMs . " ms)</div></div>"
    html .= "<div class='panel-body'>" . BuildTicketReceiptCardHTML(rec) . "</div></div>`n"
    html .= "</div></body></html>"
    return html
}

BuildLatencySvgChart(records, avgSec) {
    if (records.Length == 0)
        return "<div style='color:#64748B'>Sin datos de latencia disponibles.</div>"

    svgW := 760
    svgH := 210
    padL := 44
    padR := 20
    padT := 24
    padB := 38
    plotW := svgW - padL - padR
    plotH := svgH - padT - padB

    maxVal := 1.0
    for rec in records {
        if (rec.durationSec > maxVal)
            maxVal := rec.durationSec
    }
    maxVal := Max(maxVal * 1.15, 5.0)

    svg := "<svg viewBox='0 0 " . svgW . " " . svgH . "' width='100%' height='210' xmlns='http://www.w3.org/2000/svg'>"
    ; Lineas guia horizontales
    loop 4 {
        frac := (A_Index - 1) / 3.0
        yPos := Round(padT + plotH - (frac * plotH))
        valLbl := Round(frac * maxVal, 1) . "s"
        svg .= "<line x1='" . padL . "' y1='" . yPos . "' x2='" . (svgW - padR) . "' y2='" . yPos . "' stroke='#E2E8F0' stroke-width='1'/>"
        svg .= "<text x='" . (padL - 6) . "' y='" . (yPos + 4) . "' text-anchor='end' fill='#64748B' font-family='Consolas, monospace' font-size='10'>" . valLbl . "</text>"
    }

    count := records.Length
    slotW := plotW / Max(count, 1)
    barW := Max(8, Min(38, Round(slotW * 0.66)))

    for idx, rec in records {
        barH := Max(3, Round((rec.durationSec / maxVal) * plotH))
        xPos := Round(padL + ((idx - 1) * slotW) + ((slotW - barW) / 2))
        yPos := padT + plotH - barH

        fillCol := "#0F766E"
        if InStr(rec.status, "RECUPERADO")
            fillCol := "#B45309"
        else if (rec.status != "COMPLETADO")
            fillCol := "#B91C1C"

        lblX := Round(xPos + (barW / 2))
        seqLbl := (rec.HasOwnProp("ticket") && IsObject(rec.ticket) && rec.ticket.transSeq != "") ? ("#" . rec.ticket.transSeq) : ("C" . rec.cycle)

        svg .= "<rect x='" . xPos . "' y='" . yPos . "' width='" . barW . "' height='" . barH . "' fill='" . fillCol . "'/>"
        if (count <= 24) {
            svg .= "<text x='" . lblX . "' y='" . (yPos - 5) . "' text-anchor='middle' fill='#0F172A' font-family='Consolas, monospace' font-size='9' font-weight='bold'>" . rec.durationSec . "s</text>"
        }
        if (count <= 28 || Mod(idx, 2) == 1) {
            svg .= "<text x='" . lblX . "' y='" . (padT + plotH + 15) . "' text-anchor='middle' fill='#334155' font-family='Consolas, monospace' font-size='9'>" . EscapeHTML(seqLbl) . "</text>"
        }
    }

    ; Linea de promedio
    if (avgSec > 0 && avgSec <= maxVal) {
        avgY := Round(padT + plotH - ((avgSec / maxVal) * plotH))
        svg .= "<line x1='" . padL . "' y1='" . avgY . "' x2='" . (svgW - padR) . "' y2='" . avgY . "' stroke='#0284C7' stroke-width='1.5' stroke-dasharray='4,4'/>"
        svg .= "<text x='" . (svgW - padR - 4) . "' y='" . (avgY - 4) . "' text-anchor='end' fill='#0284C7' font-family='Consolas, monospace' font-size='10' font-weight='bold'>MEDIA: " . avgSec . "s</text>"
    }

    svg .= "</svg>"
    return svg
}

GenerateHTMLDashboardReport(macroName, customRecords := "") {
    global appVersion, autoCurrentHTML, autoAuditRecords, targetWinTitle, posLogPath, xstoreLogPath

    records := (IsObject(customRecords) && customRecords.Length > 0) ? customRecords : autoAuditRecords
    if (autoCurrentHTML == "" || records.Length == 0)
        return

    totalRuns := records.Length
    okCount := 0
    failCount := 0
    recovCount := 0
    totalSec := 0.0
    minSec := 999999.0
    maxSec := 0.0
    durations := []
    totalGrossAmount := 0.0
    totalTaxAmount := 0.0
    certifiedCount := 0
    vtolErrorCount := 0
    currencyCode := "GTQ"
    storeDetected := "N/D"
    wkstnDetected := "1"

    tenderCounts := Map()
    tenderAmounts := Map()
    docCounts := Map()

    for rec in records {
        d := rec.durationSec
        durations.Push(d)
        totalSec += d
        if (d < minSec)
            minSec := d
        if (d > maxSec)
            maxSec := d

        if (rec.status == "COMPLETADO")
            okCount++
        else if InStr(rec.status, "RECUPERADO") {
            recovCount++
            failCount++
        } else {
            failCount++
        }

        if InStr(rec.status, "VTOL") || InStr(rec.reason, "VTOL") || InStr(rec.reason, "CARD")
            vtolErrorCount++

        if (rec.HasOwnProp("ticket") && IsObject(rec.ticket)) {
            tk := rec.ticket
            if (tk.currency != "")
                currencyCode := tk.currency
            if (tk.storeId != "")
                storeDetected := tk.storeId
            if (tk.wkstnId != "")
                wkstnDetected := tk.wkstnId

            totalGrossAmount += tk.grandTotal
            totalTaxAmount += tk.taxTotal
            if (tk.invoiceUuid != "" || tk.invoiceControlNumber != "" || tk.transSeq != "")
                certifiedCount++

            tKey := (tk.primaryTender != "") ? tk.primaryTender : "SIN_MEDIO"
            tenderCounts[tKey] := (tenderCounts.Has(tKey) ? tenderCounts[tKey] : 0) + 1
            tenderAmounts[tKey] := (tenderAmounts.Has(tKey) ? tenderAmounts[tKey] : 0.0) + tk.grandTotal

            dKey := (tk.docType != "") ? tk.docType : "BILLING"
            docCounts[dKey] := (docCounts.Has(dKey) ? docCounts[dKey] : 0) + 1
        }
    }

    if (minSec == 999999.0)
        minSec := 0.0
    avgSec := (totalRuns > 0) ? Round(totalSec / totalRuns, 2) : 0.0
    rate := (totalRuns > 0) ? Round((okCount / totalRuns) * 100, 1) : 100.0

    ; Calcular P95 aproximado ordenando duraciones
    if (durations.Length > 1) {
        loop durations.Length - 1 {
            i := A_Index
            loop durations.Length - i {
                j := A_Index
                if (durations[j] > durations[j + 1]) {
                    tmp := durations[j]
                    durations[j] := durations[j + 1]
                    durations[j + 1] := tmp
                }
            }
        }
    }
    p95Idx := Max(1, Ceil(durations.Length * 0.95))
    p95Sec := (durations.Length >= p95Idx) ? durations[p95Idx] : maxSec

    genDate := FormatTime(, "yyyy-MM-dd HH:mm:ss")

    html := "<!DOCTYPE html>`n<html lang='es'>`n<head>`n<meta charset='UTF-8'>`n"
    html .= "<title>Reporte de Telemetria y Auditoria POS - " . EscapeHTML(macroName) . "</title>`n"
    html .= "<style>`n" . GetDashboardSharedCSS() . "`n</style>`n"
    html .= "<script>`n"
    html .= "function toggleRow(id) { var el = document.getElementById(id); if (el) { el.classList.toggle('open'); } }`n"
    html .= "</script>`n</head>`n<body>`n"

    html .= "<div class='topbar'>`n"
    html .= "<div><div class='topbar-title'>QA POS AUTOMATION TELEMETRY &amp; POSLOG AUDITOR v" . EscapeHTML(appVersion) . "</div>`n"
    html .= "<div class='topbar-meta'>ESCENARIO: " . EscapeHTML(macroName) . " &nbsp;|&nbsp; TIENDA: " . EscapeHTML(storeDetected) . " &nbsp;|&nbsp; CAJA: " . EscapeHTML(wkstnDetected) . " &nbsp;|&nbsp; TERMINAL: " . EscapeHTML(targetWinTitle) . "</div></div>`n"
    html .= "<div class='topbar-right'>GENERADO: " . genDate . "<br>POSLOG: " . EscapeHTML(posLogPath) . "</div>`n"
    html .= "</div>`n"

    html .= "<div class='container'>`n"

    ; 1. Banda de 6 KPIs de precision
    html .= "<div class='kpi-strip'>`n"
    html .= "<div class='kpi-box'><div class='kpi-lbl'>CICLOS PROCESADOS</div><div class='kpi-val'>" . totalRuns . "</div><div class='kpi-sub'>OK: " . okCount . " | FALLOS: " . failCount . "</div></div>`n"
    html .= "<div class='kpi-box ok'><div class='kpi-lbl'>TASA DE EXITO</div><div class='kpi-val' style='color:#0F766E'>" . rate . "%</div><div class='kpi-sub'>AUTO-RECUP: " . recovCount . "</div></div>`n"
    html .= "<div class='kpi-box info'><div class='kpi-lbl'>LATENCIA MEDIA / P95</div><div class='kpi-val'>" . avgSec . "s</div><div class='kpi-sub'>MIN: " . minSec . "s | P95: " . p95Sec . "s | MAX: " . maxSec . "s</div></div>`n"
    html .= "<div class='kpi-box info'><div class='kpi-lbl'>VOLUMEN TRANSACCIONADO</div><div class='kpi-val'>" . EscapeHTML(currencyCode) . " " . Format("{:.2f}", totalGrossAmount) . "</div><div class='kpi-sub'>IVA ACUMULADO: " . EscapeHTML(currencyCode) . " " . Format("{:.2f}", totalTaxAmount) . "</div></div>`n"
    html .= "<div class='kpi-box ok'><div class='kpi-lbl'>COMPROBANTES EXTRAIDOS</div><div class='kpi-val'>" . certifiedCount . " / " . totalRuns . "</div><div class='kpi-sub'>POSLOG XML + FEL JSON</div></div>`n"
    errColor := (failCount > 0) ? "#B91C1C" : "#0F766E"
    html .= "<div class='kpi-box err'><div class='kpi-lbl'>ALERTAS CENTINELA / VTOL</div><div class='kpi-val' style='color:" . errColor . "'>" . failCount . "</div><div class='kpi-sub'>RECHAZOS VTOL: " . vtolErrorCount . "</div></div>`n"
    html .= "</div>`n"

    ; 2. Seccion de Graficos SVG Analiticos
    html .= "<div class='charts-grid'>`n"
    html .= "<div class='panel' style='margin-bottom:0'><div class='panel-hdr'><div class='panel-title'>1. PERFIL DE LATENCIA Y TIEMPO DE RESPUESTA POR TRANSACCION (SEGUNDOS)</div>"
    html .= "<div class='panel-subtitle'>BARRAS: DURACION REAL | LINEA PUNTEADA: MEDIA (" . avgSec . "s)</div></div>`n"
    html .= "<div class='panel-body'>" . BuildLatencySvgChart(records, avgSec) . "</div></div>`n"

    html .= "<div class='panel' style='margin-bottom:0'><div class='panel-hdr'><div class='panel-title'>2. DESGLOSE POR MEDIO DE PAGO Y DOCUMENTO</div>"
    html .= "<div class='panel-subtitle'>DISTRIBUCION POSLOG</div></div>`n"
    html .= "<div class='panel-body'>"

    if (tenderCounts.Count > 0) {
        html .= "<div style='font-size:11px;font-weight:700;color:#475569;margin-bottom:8px;text-transform:uppercase'>MEDIOS DE PAGO UTILIZADOS</div>"
        for tName, tCnt in tenderCounts {
            pctT := Round((tCnt / totalRuns) * 100, 1)
            amtT := tenderAmounts.Has(tName) ? tenderAmounts[tName] : 0.0
            html .= "<div class='dist-row'><div class='dist-hdr'><span><b>" . EscapeHTML(tName) . "</b> (" . tCnt . " trans)</span><span>" . EscapeHTML(currencyCode) . " " . Format("{:.2f}", amtT) . " (" . pctT . "%)</span></div>"
            html .= "<div class='dist-track'><div class='dist-fill' style='width:" . pctT . "%'></div></div></div>"
        }
    }

    if (docCounts.Count > 0) {
        html .= "<div style='font-size:11px;font-weight:700;color:#475569;margin:14px 0 8px 0;text-transform:uppercase'>TIPOS DE DOCUMENTO FISCAL (T2A / FEL)</div>"
        for dName, dCnt in docCounts {
            pctD := Round((dCnt / totalRuns) * 100, 1)
            html .= "<div class='dist-row'><div class='dist-hdr'><span><b>" . EscapeHTML(dName) . "</b></span><span>" . dCnt . " (" . pctD . "%)</span></div>"
            html .= "<div class='dist-track'><div class='dist-fill' style='background:#0F766E;width:" . pctD . "%'></div></div></div>"
        }
    }

    if (tenderCounts.Count == 0 && docCounts.Count == 0) {
        html .= "<div style='color:#64748B;font-size:12px'>Sin desglose de medios de pago en esta sesion.</div>"
    }
    html .= "</div></div>`n</div>`n"

    ; 3. Tabla Maestra de Transacciones con Comprobantes Desplegables
    html .= "<div class='panel'>`n<div class='panel-hdr'><div class='panel-title'>3. REGISTRO DETALLADO DE TRANSACCIONES Y COMPROBANTES FISCALES</div>"
    html .= "<div class='panel-subtitle'>HAZ CLIC EN 'VER COMPROBANTE' PARA DESPLEGAR EL TICKET Y EL XML</div></div>`n"
    html .= "<div class='panel-body' style='padding:0'>`n"
    html .= "<table class='data-table'><thead><tr>"
    html .= "<th>CICLO</th><th>TRANS #</th><th>TIENDA/CAJA</th><th>DOCUMENTO / T2A</th><th>CLIENTE / NIT</th><th>SKUS</th><th>MEDIO PAGO / AUT</th><th class='num'>TOTAL</th><th class='num'>DURACION</th><th>ESTADO</th><th>COMPROBANTE / EVIDENCIA</th>"
    html .= "</tr></thead><tbody>`n"

    for idx, rec in records {
        badgeClass := "badge-ok"
        if InStr(rec.status, "RECUPERADO")
            badgeClass := "badge-heal"
        else if (rec.status != "COMPLETADO")
            badgeClass := "badge-err"

        tSeq := "--"
        storeWk := "--"
        docType := "--"
        custStr := "--"
        skuStr := "--"
        tenderStr := "--"
        totStr := "--"

        if (rec.HasOwnProp("ticket") && IsObject(rec.ticket)) {
            tk := rec.ticket
            if (tk.transSeq != "")
                tSeq := "#" . tk.transSeq
            if (tk.storeId != "")
                storeWk := tk.storeId . " / C" . (tk.wkstnId != "" ? tk.wkstnId : "1")
            if (tk.docType != "")
                docType := tk.docType
            if (tk.customerDocNumber != "" || tk.customerName != "")
                custStr := (tk.customerDocNumber != "" ? ("[" . tk.customerDocNumber . "] ") : "") . SubStr(tk.customerName, 1, 24)

            if (tk.items.Length > 0) {
                firstSku := tk.items[1].itemId
                skuStr := firstSku . (tk.items.Length > 1 ? (" (+" . (tk.items.Length - 1) . ")") : "")
            }

            if (tk.primaryTender != "") {
                tenderStr := tk.primaryTender
                if (tk.vtolAuthCode != "")
                    tenderStr .= " [AUT:" . tk.vtolAuthCode . "]"
            }

            totStr := tk.currency . " " . Format("{:.2f}", tk.grandTotal)
        } else if (rec.reason != "") {
            docType := rec.reason
            custStr := rec.detail
        }

        detailRowId := "det-row-" . idx

        html .= "<tr class='main-row'>"
        html .= "<td class='mono'><b>#" . Format("{:02}", rec.cycle) . "</b></td>"
        html .= "<td class='mono'><b>" . EscapeHTML(tSeq) . "</b></td>"
        html .= "<td class='mono'>" . EscapeHTML(storeWk) . "</td>"
        html .= "<td class='mono'>" . EscapeHTML(docType) . "</td>"
        html .= "<td>" . EscapeHTML(custStr) . "</td>"
        html .= "<td class='mono'>" . EscapeHTML(skuStr) . "</td>"
        html .= "<td class='mono'>" . EscapeHTML(tenderStr) . "</td>"
        html .= "<td class='num'><b>" . EscapeHTML(totStr) . "</b></td>"
        html .= "<td class='num'>" . rec.durationSec . "s <span style='color:#64748B'>(" . rec.durationMs . "ms)</span></td>"
        html .= "<td><span class='badge " . badgeClass . "'>" . EscapeHTML(rec.status) . "</span></td>"
        html .= "<td><button class='btn-action' onclick=`"toggleRow('" . detailRowId . "')`">VER COMPROBANTE</button></td>"
        html .= "</tr>`n"

        html .= "<tr id='" . detailRowId . "' class='detail-row'><td colspan='11' class='detail-cell'>"
        if (rec.reason != "" || rec.logSnippet != "" || rec.screenshot != "") {
            html .= "<div class='forensic-alert'>"
            html .= "<div class='forensic-title'>DIAGNOSTICO FORENSE CENTINELA XSTORE — " . EscapeHTML(rec.reason) . ": " . EscapeHTML(rec.detail) . "</div>"
            if (rec.logSnippet != "") {
                html .= "<pre class='raw-pre' style='background:#1E293B;padding:10px;margin-top:6px'>" . EscapeHTML(rec.logSnippet) . "</pre>"
            }
            if (rec.screenshot != "") {
                SplitPath(rec.screenshot, &shotFileName)
                relShot := "Screenshots/" . shotFileName
                html .= "<div style='margin-top:8px'><a href='" . EscapeHTML(relShot) . "' target='_blank'><img class='shot-img' src='" . EscapeHTML(relShot) . "' alt='Captura Error'></a></div>"
            }
            html .= "</div>"
        }
        html .= BuildTicketReceiptCardHTML(rec)
        html .= "</td></tr>`n"
    }

    html .= "</tbody></table>`n</div></div>`n</div></body></html>"

    try {
        if FileExist(autoCurrentHTML)
            FileDelete(autoCurrentHTML)
        FileAppend(html, autoCurrentHTML, "UTF-8")
    }
}

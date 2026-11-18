; ==============================================================================
; MODULE: src\POS\PosLogParser.ahk
; PURPOSE: Extractor dual de transacciones y comprobantes fiscales desde
;          PosLog.xml (estandar ARTS/IXRetail) y xstore.log (FEL / Replicacion)
; ==============================================================================

DetectDefaultPosLogPath() {
    global posLogPath
    candidates := [
        "C:\xstore\log\PosLog.xml",
        "C:\xstore\log\poslog.xml",
        "C:\xstore\log\poslog.log",
        "D:\xstore\log\PosLog.xml",
        A_ScriptDir . "\PosLog.xml",
        A_ScriptDir . "\poslog.xml"
    ]
    for cand in candidates {
        if FileExist(cand) {
            posLogPath := cand
            return cand
        }
    }
    return posLogPath
}

UpdatePosLogStatus() {
    global posLogPath, txtPosLogStatus
    if (!IsObject(txtPosLogStatus))
        return

    if (posLogPath != "" && FileExist(posLogPath)) {
        txtPosLogStatus.Text := "[PosLog Activo]"
        txtPosLogStatus.SetFont("c0E7D42")
    } else {
        txtPosLogStatus.Text := "[Sin PosLog]"
        txtPosLogStatus.SetFont("c888888")
    }
}

ConfigurePosLogPath(*) {
    global posLogPath
    selectedFile := FileSelect(3, posLogPath, "Seleccionar archivo PosLog.xml de Xstore", "Archivos PosLog (*.xml; *.log)")
    if (selectedFile != "") {
        posLogPath := selectedFile
        UpdatePosLogStatus()
        SaveSettings()
        ReloadLibraryTransactionsFromPosLog()
        MsgBox("Ruta de PosLog configurada:`n`n" . posLogPath, "Configuracion PosLog", "Iconi 262144")
    }
}

ExtractXmlTagValue(xmlText, tagName) {
    pattern := "s)<(?:\w+:)?\Q" . tagName . "\E[^>]*>\s*(?:<!\[CDATA\[(.*?)\]\]>|([^<]*))\s*</(?:\w+:)?\Q" . tagName . "\E>"
    if RegExMatch(xmlText, pattern, &m) {
        return Trim(m[1] != "" ? m[1] : m[2])
    }
    return ""
}

ParseIsoTimestampToMs(isoStr, &formattedOut := "") {
    formattedOut := isoStr
    if RegExMatch(isoStr, "^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?", &m) {
        formattedOut := m[1] . "-" . m[2] . "-" . m[3] . " " . m[4] . ":" . m[5] . ":" . m[6]
        secOfDay := (Integer(m[4]) * 3600) + (Integer(m[5]) * 60) + Integer(m[6])
        msPart := (m.Count >= 7 && m[7] != "") ? Integer(SubStr(m[7] . "000", 1, 3)) : 0
        return (secOfDay * 1000) + msPart
    }
    return 0
}

CreateEmptyTicketObject() {
    return {
        transSeq: "",
        transType: "RETAIL_SALE",
        docType: "",
        t2aDocType: "",
        storeId: "",
        wkstnId: "",
        tillId: "",
        operatorId: "",
        businessDate: "",
        beginTime: "",
        endTime: "",
        durationSec: 0.0,
        durationMs: 0,
        currency: "USD",
        customerName: "",
        customerDocType: "",
        customerDocNumber: "",
        customerAccount: "",
        customerAddress: "",
        customerEmail: "",
        invoiceUuid: "",
        invoiceSeries: "",
        invoicePreimpreso: "",
        invoiceControlNumber: "",
        invoiceReference: "",
        invoiceStatusMsg: "",
        pdfUrl: "",
        inventorySuccess: "",
        subtotal: 0.0,
        taxTotal: 0.0,
        grandTotal: 0.0,
        primaryTender: "",
        vtolAuthCode: "",
        vtolTicket: "",
        vtolStatus: "",
        vtolOnline: "",
        items: [],
        tenders: [],
        sourceType: "",
        rawContent: ""
    }
}

ParsePosLogTransactionBlock(xmlBlock) {
    t := CreateEmptyTicketObject()
    t.sourceType := "POSLog XML"
    t.rawContent := Trim(xmlBlock)

    if RegExMatch(xmlBlock, 'dtv:TransactionType="([^"]+)"', &mType)
        t.transType := mType[1]

    t.transSeq := ExtractXmlTagValue(xmlBlock, "SequenceNumber")
    t.storeId := ExtractXmlTagValue(xmlBlock, "RetailStoreID")
    t.wkstnId := ExtractXmlTagValue(xmlBlock, "WorkstationID")
    t.tillId := ExtractXmlTagValue(xmlBlock, "TillID")
    t.operatorId := ExtractXmlTagValue(xmlBlock, "OperatorID")
    t.businessDate := ExtractXmlTagValue(xmlBlock, "BusinessDayDate")
    cur := ExtractXmlTagValue(xmlBlock, "CurrencyCode")
    if (cur != "")
        t.currency := cur

    rawBegin := ExtractXmlTagValue(xmlBlock, "BeginDateTime")
    rawEnd := ExtractXmlTagValue(xmlBlock, "EndDateTime")
    fmtBegin := "", fmtEnd := ""
    msBegin := ParseIsoTimestampToMs(rawBegin, &fmtBegin)
    msEnd := ParseIsoTimestampToMs(rawEnd, &fmtEnd)
    t.beginTime := fmtBegin
    t.endTime := fmtEnd
    if (msEnd >= msBegin && msBegin > 0) {
        t.durationMs := msEnd - msBegin
        t.durationSec := Round(t.durationMs / 1000, 2)
    }

    ; Propiedades de transaccion (<dtv:PosTransactionProperties>)
    pos := 1
    while RegExMatch(xmlBlock, "s)<dtv:PosTransactionProperties>(.*?)</dtv:PosTransactionProperties>", &mProp, pos) {
        pBlock := mProp[1]
        pCode := ExtractXmlTagValue(pBlock, "PosTransactionPropertyCode")
        pVal := ExtractXmlTagValue(pBlock, "PosTransactionPropertyValue")
        if (pVal == "")
            pVal := ExtractXmlTagValue(pBlock, "PosTransactionPropertyDecimal")

        switch pCode {
            case "INVOICE_TRANSACTION_TYPE":
                t.docType := pVal
            case "SMN_T2A_DOCUMENT_TYPE":
                t.t2aDocType := pVal
            case "INVOICE_DOCUMENT_TYPE":
                t.customerDocType := pVal
            case "INVOICE_DOCUMENT_TYPE_CODE":
                t.customerDocNumber := pVal
            case "INVOICE_NUMERO_AUTORIZACION", "SMN_INVOICE_UUID":
                t.invoiceUuid := pVal
            case "INVOICE_NUMERO_SERIE":
                t.invoiceSeries := pVal
            case "INVOICE_NUMERO_PREIMPRESO":
                t.invoicePreimpreso := pVal
            case "SMN_INVOICE_CONTROL_NUMBER":
                t.invoiceControlNumber := pVal
            case "INVOICE_NUMERO_REFERENCIA", "SMN_INVOICE_ACCESS_CODE":
                t.invoiceReference := pVal
            case "SMN_NAME_FROM_GUATEFACTURAS":
                if (t.customerName == "")
                    t.customerName := pVal
            case "SMN_INVOICE_MSG_DESC":
                t.invoiceStatusMsg := pVal
            case "SMN_INVOICE_QR":
                t.pdfUrl := pVal
            case "TransactionNetAmount":
                try t.subtotal := Float(pVal)
            case "TransactionTaxAmount":
                try t.taxTotal := Float(pVal)
            case "INVENTORY_MOVEMENT_SUCCESS":
                t.inventorySuccess := pVal
        }
        pos := mProp.Pos + mProp.Len
    }

    ; Datos de Cliente (<Customer>)
    if RegExMatch(xmlBlock, "s)<Customer>(.*?)</Customer>", &mCust) {
        cBlock := mCust[1]
        cName := ExtractXmlTagValue(cBlock, "Name")
        if (cName != "")
            t.customerName := cName
        t.customerAccount := ExtractXmlTagValue(cBlock, "AccountNumber")
        t.customerAddress := ExtractXmlTagValue(cBlock, "AddressLine")
        t.customerEmail := ExtractXmlTagValue(cBlock, "eMail")
        if (t.customerDocNumber == "") {
            if RegExMatch(cBlock, 's)<AlternateKey\s+TypeCode="NIT_CODE">\s*<AlternateID><!\[CDATA\[(.*?)\]\]></AlternateID>', &mNit)
                t.customerDocNumber := Trim(mNit[1])
        }
    }

    ; Lineas de Articulos y Formas de Pago (<LineItem>)
    pos := 1
    while RegExMatch(xmlBlock, "s)<LineItem([^>]*)>(.*?)</LineItem>", &mLine, pos) {
        lineAttrs := mLine[1]
        lineBody := mLine[2]
        pos := mLine.Pos + mLine.Len

        if InStr(lineAttrs, 'VoidFlag="true"')
            continue

        if (InStr(lineBody, "<Sale ") || InStr(lineBody, "<Return ")) {
            isReturn := InStr(lineBody, "<Return ")
            tagType := isReturn ? "Return" : "Sale"
            if RegExMatch(lineBody, "s)<" . tagType . "[^>]*>(.*?)</" . tagType . ">", &mSale) {
                sBody := mSale[1]
                itmId := ExtractXmlTagValue(sBody, "ItemID")
                desc := ExtractXmlTagValue(sBody, "Description")
                if (SubStr(desc, 1, 6) == "+item:")
                    desc := "SKU " . itmId
                qtyStr := ExtractXmlTagValue(sBody, "Quantity")
                unitStr := ExtractXmlTagValue(sBody, "ActualSalesUnitPrice")
                if (unitStr == "")
                    unitStr := ExtractXmlTagValue(sBody, "RegularSalesUnitPrice")
                extStr := ExtractXmlTagValue(sBody, "ExtendedAmount")

                taxAmt := 0.0
                taxPct := 0.0
                if RegExMatch(sBody, "s)<Tax[^>]*>(.*?)</Tax>", &mTax) {
                    tAmtStr := ExtractXmlTagValue(mTax[1], "Amount")
                    tPctStr := ExtractXmlTagValue(mTax[1], "Percent")
                    try taxAmt := Round(Float(tAmtStr), 2)
                    try taxPct := Round(Float(tPctStr) * 100, 1)
                }

                qtyVal := 1
                unitVal := 0.0
                extVal := 0.0
                try qtyVal := Integer(Float(qtyStr))
                try unitVal := Round(Float(unitStr), 2)
                try extVal := Round(Float(extStr), 2)

                t.items.Push({
                    lineType: isReturn ? "DEVOLUCION" : "VENTA",
                    itemId: itmId,
                    description: desc,
                    qty: qtyVal,
                    unitPrice: unitVal,
                    extendedAmount: extVal,
                    taxAmount: taxAmt,
                    taxPercent: taxPct
                })
            }
        } else if InStr(lineBody, "<Tender ") {
            if RegExMatch(lineBody, "s)<Tender([^>]*)>(.*?)</Tender>", &mTnd) {
                tBody := mTnd[2]
                tId := ExtractXmlTagValue(tBody, "TenderID")
                tAmtStr := ExtractXmlTagValue(tBody, "Amount")
                tAmt := 0.0
                try tAmt := Round(Float(tAmtStr), 2)

                authCode := ""
                vtolTicket := ""
                vtolStatus := ""
                payPlan := ""
                cardSeries := ""
                onlineMode := ""

                pPos := 1
                while RegExMatch(tBody, "s)<dtv:LineItemProperty>(.*?)</dtv:LineItemProperty>", &mLp, pPos) {
                    lpBody := mLp[1]
                    lpCode := ExtractXmlTagValue(lpBody, "LineItemPropertyCode")
                    lpVal := ExtractXmlTagValue(lpBody, "LineItemPropertyValue")
                    if (lpVal == "")
                        lpVal := ExtractXmlTagValue(lpBody, "LineItemPropertyDecimal")

                    switch lpCode {
                        case "SMN_VTOL_AUTHO_CODE": authCode := lpVal
                        case "SMN_VTOL_TICKET": vtolTicket := lpVal
                        case "SMN_VTOL_RESPONSE_MESSAGE": vtolStatus := lpVal
                        case "SMN_PAY_PLAN_CODE": payPlan := lpVal
                        case "SMN_INT_CARD_SERIES": cardSeries := lpVal
                        case "SMN_VTOL_ONLINE_TRAN":
                            onlineMode := (lpVal == "1" || lpVal == "1.000000" || lpVal == "true") ? "ONLINE" : "OFFLINE"
                    }
                    pPos := mLp.Pos + mLp.Len
                }

                if (tId == "NOTA_DE_ABONO" && authCode == "") {
                    authCode := ExtractXmlTagValue(tBody, "SerialNumber")
                }

                t.tenders.Push({
                    tenderId: tId,
                    amount: tAmt,
                    authCode: authCode,
                    vtolTicket: vtolTicket,
                    vtolStatus: vtolStatus,
                    payPlan: payPlan,
                    cardSeries: cardSeries,
                    onlineMode: onlineMode
                })

                if (t.primaryTender == "")
                    t.primaryTender := tId
                if (authCode != "" && t.vtolAuthCode == "")
                    t.vtolAuthCode := authCode
                if (vtolTicket != "" && t.vtolTicket == "")
                    t.vtolTicket := vtolTicket
                if (vtolStatus != "" && t.vtolStatus == "")
                    t.vtolStatus := vtolStatus
                if (onlineMode != "" && t.vtolOnline == "")
                    t.vtolOnline := onlineMode
            }
        }
    }

    if RegExMatch(xmlBlock, 's)<Total\s+TotalType="TransactionGrandAmount">\s*(?:<!\[CDATA\[(.*?)\]\]>|([^<]*))\s*</Total>', &mTot) {
        totStr := Trim(mTot[1] != "" ? mTot[1] : mTot[2])
        try t.grandTotal := Round(Float(totStr), 2)
    }

    if (t.subtotal == 0.0 && t.grandTotal != 0.0)
        t.subtotal := t.grandTotal

    if (t.docType == "")
        t.docType := (t.grandTotal < 0) ? "CREDIT_NOTE" : "BILLING"

    return t
}

ExtractTicketFromXstoreLogChunk(logChunk, preferredSeq := "") {
    if (logChunk == "")
        return ""

    seq := preferredSeq
    if (seq == "") {
        pos := 1
        while RegExMatch(logChunk, "\*\*\s+TRANSACTION\s+\[(\d+)\]\s+COMPLETE\s+\*\*", &mComp, pos) {
            seq := mComp[1]
            pos := mComp.Pos + mComp.Len
        }
    }
    if (seq == "") {
        pos := 1
        while RegExMatch(logChunk, "m)^\s*(?:INFO|ERROR|WARN)\s+\[\s*(\d+)\s*\]", &mSeq, pos) {
            seq := mSeq[1]
            pos := mSeq.Pos + mSeq.Len
        }
    }

    hasFel := InStr(logChunk, "SmnFelCreationServiceHandler.handleService:response")
    hasRep := InStr(logChunk, '"type":"RetailTransaction"')
    if (seq == "" && !hasFel && !hasRep)
        return ""

    t := CreateEmptyTicketObject()
    t.transSeq := seq
    t.sourceType := "xstore.log (FEL / DAO)"

    ; 1. Extraer datos de certificacion electronica Infile FEL si existen en el log
    if RegExMatch(logChunk, "SmnFelCreationServiceHandler\.handleService:response\s+(\{[^\r\n]+)", &mFel) {
        felJson := mFel[1]
        t.rawContent := felJson
        if RegExMatch(felJson, '"pdf_path":"([^"]+)"', &mPdf)
            t.pdfUrl := StrReplace(mPdf[1], "\/", "/")
        if RegExMatch(felJson, '"codigoGeneracion":"([^"]+)"', &mUuid)
            t.invoiceUuid := mUuid[1]
        if RegExMatch(felJson, '"numeroControl":"([^"]+)"', &mCtrl)
            t.invoiceControlNumber := mCtrl[1]
        if RegExMatch(felJson, '"selloRecibido":"([^"]+)"', &mSello)
            t.invoiceReference := mSello[1]
        if RegExMatch(felJson, '"codEstable":"([^"]+)"', &mEst)
            t.storeId := mEst[1]
        if RegExMatch(felJson, '"codPuntoVenta":"([^"]+)"', &mPto)
            t.wkstnId := mPto[1]
        if RegExMatch(felJson, '"fecEmi":"([^"]+)"', &mFec)
            t.businessDate := mFec[1]
        if RegExMatch(felJson, '"fechaEmision":"([^"]+)"', &mFe)
            t.endTime := mFe[1]
        if RegExMatch(felJson, '"tipoMoneda":"([^"]+)"', &mMon)
            t.currency := mMon[1]
        if RegExMatch(felJson, '"totalPagar":([0-9\.]+)', &mTot) {
            try t.grandTotal := Round(Float(mTot[1]), 2)
            t.subtotal := t.grandTotal
        }
        if RegExMatch(felJson, '"totalIva":([0-9\.]+)', &mIva) {
            try t.taxTotal := Round(Float(mIva[1]), 2)
        }
        if RegExMatch(felJson, '"receptor":\{[^\}]*?"nombre":(?:"([^"]+)"|null)', &mRecNom) {
            t.customerName := (mRecNom[1] != "") ? mRecNom[1] : "CONSUMIDOR FINAL"
        }
        if RegExMatch(felJson, '"receptor":\{[^\}]*?"numDocumento":(?:"([^"]+)"|null)', &mRecDoc) {
            t.customerDocNumber := mRecDoc[1]
        }

        ; Extraer items desde cuerpoDocumento del JSON FEL
        if RegExMatch(felJson, '"cuerpoDocumento":\[(.*?)\]', &mItems) {
            itemsJson := mItems[1]
            iPos := 1
            while RegExMatch(itemsJson, '\{([^\}]+)\}', &mItm, iPos) {
                ib := mItm[1]
                sku := RegExMatch(ib, '"codigo":"([^"]+)"', &mC) ? mC[1] : ""
                dsc := RegExMatch(ib, '"descripcion":"([^"]+)"', &mD) ? mD[1] : ("SKU " . sku)
                qty := RegExMatch(ib, '"cantidad":([0-9\.]+)', &mQ) ? Integer(Float(mQ[1])) : 1
                prc := RegExMatch(ib, '"precioUni":([0-9\.]+)', &mP) ? Round(Float(mP[1]), 2) : 0.0
                ext := RegExMatch(ib, '"ventaGravada":([0-9\.]+)', &mE) ? Round(Float(mE[1]), 2) : prc
                iva := RegExMatch(ib, '"ivaItem":([0-9\.]+)', &mIv) ? Round(Float(mIv[1]), 2) : 0.0
                t.items.Push({
                    lineType: "VENTA",
                    itemId: sku,
                    description: dsc,
                    qty: qty,
                    unitPrice: prc,
                    extendedAmount: ext,
                    taxAmount: iva,
                    taxPercent: 13.0
                })
                iPos := mItm.Pos + mItm.Len
            }
        }
    }

    ; 2. Enriquecer con datos de ctl_replication_queue si el log tiene DEBUG activo
    if RegExMatch(logChunk, '\{"persistables":\[\[\{"v":\d+,"type":"RetailTransaction".*?\]\]\}', &mDao) {
        daoJson := mDao[0]
        if (t.rawContent == "")
            t.rawContent := daoJson
        if (t.storeId == "" && RegExMatch(daoJson, '"RetailLocationId":(\d+)', &mRtl))
            t.storeId := mRtl[1]
        if (t.wkstnId == "" && RegExMatch(daoJson, '"WorkstationId":(\d+)', &mWk))
            t.wkstnId := mWk[1]
        if (t.operatorId == "" && RegExMatch(daoJson, '"OperatorPartyId":(\d+)', &mOp))
            t.operatorId := mOp[1]
        if (t.grandTotal == 0.0 && RegExMatch(daoJson, '"Total":([0-9\.-]+)', &mGTot))
            try t.grandTotal := Round(Float(mGTot[1]), 2)
        if (t.taxTotal == 0.0 && RegExMatch(daoJson, '"TaxAmount":([0-9\.-]+)', &mTTax))
            try t.taxTotal := Round(Float(mTTax[1]), 2)
        if RegExMatch(daoJson, '"TenderId":"([^"]+)"', &mTndId) {
            t.primaryTender := mTndId[1]
            if RegExMatch(daoJson, '"PropertyCode":"SMN_VTOL_AUTHO_CODE","Type":"STRING","StringValue":"([^"]+)"', &mAuth)
                t.vtolAuthCode := mAuth[1]
            if RegExMatch(daoJson, '"PropertyCode":"SMN_VTOL_TICKET","Type":"STRING","StringValue":"([^"]+)"', &mVtk)
                t.vtolTicket := mVtk[1]
            t.tenders.Push({
                tenderId: t.primaryTender,
                amount: t.grandTotal,
                authCode: t.vtolAuthCode,
                vtolTicket: t.vtolTicket,
                vtolStatus: "APROBADO",
                payPlan: "",
                cardSeries: "",
                onlineMode: ""
            })
        }
        if RegExMatch(daoJson, '"PropertyCode":"SMN_T2A_DOCUMENT_TYPE","Type":"STRING","StringValue":"([^"]+)"', &mT2a) {
            t.t2aDocType := mT2a[1]
            t.docType := mT2a[1]
        }
    }

    if (t.docType == "")
        t.docType := "BILLING_FINAL_CUSTOMER"

    return t
}

CaptureLatestTransactionTicket(xstoreHandle, xstoreStartPos, posLogFile, posLogStartPos) {
    ticketFromLog := ""
    detectedSeq := ""

    ; 1. Revisar lo escrito en xstore.log durante este ciclo
    if (xstoreHandle && IsObject(xstoreHandle)) {
        try {
            curPos := xstoreHandle.Pos
            totalLen := xstoreHandle.Length
            if (totalLen > xstoreStartPos) {
                readFrom := Max(xstoreStartPos, totalLen - 786432) ; Hasta 768 KB del ciclo
                xstoreHandle.Seek(readFrom, 0)
                cycleChunk := xstoreHandle.Read()
                xstoreHandle.Seek(curPos, 0)
                ticketFromLog := ExtractTicketFromXstoreLogChunk(cycleChunk)
                if IsObject(ticketFromLog)
                    detectedSeq := ticketFromLog.transSeq
            }
        }
    }

    ; 2. Revisar PosLog.xml para extraer el comprobante estructurado
    ticketFromXml := ""
    if (posLogFile != "" && FileExist(posLogFile)) {
        try {
            pf := FileOpen(posLogFile, "r-d", "UTF-8")
            if (pf) {
                pLen := pf.Length
                if (pLen > posLogStartPos && posLogStartPos > 0) {
                    readFrom := Max(0, posLogStartPos - 4096)
                } else {
                    readFrom := Max(0, pLen - 196608) ; Ultimos 192 KB de PosLog.xml
                }
                pf.Seek(readFrom, 0)
                xmlTail := pf.Read()
                pf.Close()

                lastBlock := ""
                matchedBlock := ""
                pos := 1
                while RegExMatch(xmlTail, "s)<Transaction\b[^>]*>.*?</Transaction>", &mTrn, pos) {
                    blk := mTrn[0]
                    if InStr(blk, 'TransactionType="RETAIL_SALE"') || InStr(blk, "<RetailTransaction") {
                        lastBlock := blk
                        if (detectedSeq != "" && InStr(blk, "<SequenceNumber><![CDATA[" . detectedSeq . "]]></SequenceNumber>")) {
                            matchedBlock := blk
                        }
                    }
                    pos := mTrn.Pos + mTrn.Len
                }

                chosenBlock := (matchedBlock != "") ? matchedBlock : ((pLen > posLogStartPos) ? lastBlock : "")
                if (chosenBlock != "")
                    ticketFromXml := ParsePosLogTransactionBlock(chosenBlock)
            }
        }
    }

    ; 3. Combinar ambas fuentes si existen
    if (IsObject(ticketFromXml) && IsObject(ticketFromLog)) {
        if (ticketFromXml.pdfUrl == "" && ticketFromLog.pdfUrl != "")
            ticketFromXml.pdfUrl := ticketFromLog.pdfUrl
        for idx, itm in ticketFromXml.items {
            if (SubStr(itm.description, 1, 4) == "SKU " && idx <= ticketFromLog.items.Length) {
                itm.description := ticketFromLog.items[idx].description
            }
        }
        return ticketFromXml
    }

    if IsObject(ticketFromXml)
        return ticketFromXml
    if IsObject(ticketFromLog)
        return ticketFromLog
    return ""
}

LoadTransactionsFromPosLogFile(maxRecords := 40) {
    global posLogPath
    results := []
    if (posLogPath == "" || !FileExist(posLogPath))
        return results

    try {
        pf := FileOpen(posLogPath, "r-d", "UTF-8")
        if (!pf)
            return results

        readBytes := Min(pf.Length, 1048576) ; Leer hasta el ultimo 1 MB de PosLog.xml
        pf.Seek(pf.Length - readBytes, 0)
        xmlContent := pf.Read()
        pf.Close()

        blocks := []
        pos := 1
        while RegExMatch(xmlContent, "s)<Transaction\b[^>]*>.*?</Transaction>", &mTrn, pos) {
            blk := mTrn[0]
            if InStr(blk, 'TransactionType="RETAIL_SALE"') || InStr(blk, "<RetailTransaction") {
                blocks.Push(blk)
            }
            pos := mTrn.Pos + mTrn.Len
        }

        startIdx := Max(1, blocks.Length - maxRecords + 1)
        cycleCounter := 0
        loop (blocks.Length - startIdx + 1) {
            idx := startIdx + A_Index - 1
            tObj := ParsePosLogTransactionBlock(blocks[idx])
            if (tObj.transSeq != "") {
                cycleCounter++
                results.Push({
                    cycle: cycleCounter,
                    startTime: (tObj.beginTime != "" ? tObj.beginTime : tObj.businessDate),
                    endTime: (tObj.endTime != "" ? tObj.endTime : tObj.businessDate),
                    durationSec: tObj.durationSec,
                    durationMs: tObj.durationMs,
                    status: "COMPLETADO",
                    macro: "PosLog.xml",
                    screenshot: "",
                    reason: "",
                    detail: "",
                    logSnippet: "",
                    ticket: tObj
                })
            }
        }
    }
    return results
}

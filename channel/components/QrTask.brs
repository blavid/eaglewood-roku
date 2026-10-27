sub init()
    m.top.functionName = "fetchQrs"
end sub

' Public QR PNGs. Same download as wifi.png: AsyncGetToFile, then a local file for Poster.
sub fetchQrs()
    if m.top.doCleanup = true
        busy = ""
        if m.top.busyPaths <> invalid then busy = m.top.busyPaths
        try
            ClearStaleQrCache(busy)
        catch err
            print "Eaglewood: qr cache error="; TaskErrorText(err)
        end try
    end if
    generation = ReadQrGeneration()
    FetchQr("badge", m.top.badgeUrl, generation)
    FetchQr("book", m.top.bookUrl, generation)
    FetchQr("detail", m.top.detailUrl, generation)
end sub

sub FetchQr(slot as string, url as string, generation as integer)
    try
        FetchQrBody(slot, url, generation)
    catch err
        print "Eaglewood: qr "; slot; " error="; TaskErrorText(err)
        PublishQr(slot, generation, url, 0, FailQr("commit"), "", 0)
        print "Eaglewood: qr "; slot; " final uri=none"
    end try
end sub

function TaskErrorText(err as object) as string
    if err = invalid then return "failed"
    kind = type(err)
    if kind = "String" or kind = "roString" then return err
    if kind = "roAssociativeArray"
        message = err.Lookup("message")
        if message <> invalid and message <> "" then return message
    end if
    return "failed"
end function

sub FetchQrBody(slot as string, url as string, generation as integer)
    if url = invalid then url = ""
    if slot = invalid or slot = "" or url = "" then return
    code = 0
    prepared = invalid
    finalUri = CachedContentPath(slot, url)
    busy = ""
    if m.top.busyPaths <> invalid then busy = m.top.busyPaths
    if finalUri <> ""
        wrapped = ReadFileBytes(finalUri)
        prepared = ExpandPngBytes(wrapped)
        if prepared <> invalid and prepared.converted = true
            bytes = CopyToByteArray(prepared.bytes)
            if bytes <> invalid then finalUri = CommitQrBytes(slot, bytes, busy)
        else if prepared <> invalid
            prepared.path = finalUri
        end if
        readBack = QrReadLength(finalUri)
        print "Eaglewood: qr "; slot; " file bytes="; readBack; " read="; readBack
    else
        print "Eaglewood: qr "; slot; " request sent"
        incoming = "cachefs:/eaglewood/qr-" + slot + "-" + generation.ToStr() + "-incoming.tmp"
        code = DownloadQr(url, incoming)
        print "Eaglewood: qr "; slot; " response code="; code
        if code <> 200
            DeleteQrFile(incoming)
            PublishQr(slot, generation, url, code, FailQr("http"), "", 0)
            print "Eaglewood: qr "; slot; " final uri=none"
            return
        end if
        raw = CreateObject("roByteArray")
        if raw = invalid or raw.ReadFile(incoming) <> true
            DeleteQrFile(incoming)
            PublishQr(slot, generation, url, code, FailQr("bad-png"), "", 0)
            print "Eaglewood: qr "; slot; " final uri=none"
            return
        end if
        prepared = ExpandPngBytes(AsBuf(raw))
        bytes = raw
        if prepared <> invalid and prepared.converted = true
            bytes = CopyToByteArray(prepared.bytes)
        end if
        if prepared = invalid or prepared.ok <> true or bytes = invalid
            DeleteQrFile(incoming)
            PublishQr(slot, generation, url, code, prepared, "", 0)
            print "Eaglewood: qr "; slot; " final uri=none"
            return
        end if
        finalUri = CommitQrBytes(slot, bytes, busy)
        DeleteQrFile(incoming)
        if prepared <> invalid then prepared.path = finalUri
    end if
    LogQrFormat(slot, prepared)
    if LocalPosterPath(finalUri) <> true then finalUri = ""
    byteCount = 0
    if finalUri <> ""
        byteCount = QrReadLength(finalUri)
        if prepared <> invalid and prepared.ok = true
            WriteAsciiFile(QrNotePath(slot), url)
            WriteAsciiFile(QrPathNote(slot), finalUri)
        end if
    end if
    if finalUri = ""
        print "Eaglewood: qr "; slot; " final uri=none"
    else
        print "Eaglewood: qr "; slot; " final uri="; finalUri
    end if
    PublishQr(slot, generation, url, code, prepared, finalUri, byteCount)
end sub

function LocalPosterPath(path as string) as boolean
    if path = invalid or path = "" then return false
    if Left(path, 8) = "cachefs:" then return true
    if Left(path, 4) = "tmp:" then return true
    return false
end function

function CachedContentPath(slot as string, url as string) as string
    notePath = QrNotePath(slot)
    pathNote = QrPathNote(slot)
    if FsExists(notePath) <> true or FsExists(pathNote) <> true then return ""
    note = ReadAsciiFile(notePath)
    if note = invalid or note <> url then return ""
    path = ReadAsciiFile(pathNote)
    if path = invalid or LocalPosterPath(path) <> true then return ""
    if QrReadLength(path) < 8 then return ""
    return path
end function

function FsExists(path as string) as boolean
    if path = invalid or path = "" then return false
    fs = CreateObject("roFileSystem")
    if fs = invalid then return false
    found = fs.Exists(path)
    if found = true then return true
    return false
end function

function DownloadQr(url as string, dest as string) as integer
    EnsureQrDir()
    DeleteQrFile(dest)
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    if transfer = invalid or port = invalid then return 0
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.SetUrl(url)
    transfer.AddHeader("Accept", "image/png")
    started = transfer.AsyncGetToFile(dest)
    if started = false or started = invalid then return 0
    event = wait(8000, port)
    if type(event) <> "roUrlEvent"
        transfer.AsyncCancel()
        return 0
    end if
    return event.GetResponseCode()
end function

sub LogQrFormat(slot as string, prepared as object)
    bit = 0
    color = -1
    interlace = 0
    indexed = "no"
    reason = "bad-png"
    if prepared <> invalid
        if prepared.bit <> invalid then bit = prepared.bit
        if prepared.color <> invalid then color = prepared.color
        if prepared.interlace <> invalid then interlace = prepared.interlace
        if prepared.converted = true or prepared.color = 3 then indexed = "yes"
        if prepared.reason <> invalid and prepared.reason <> "" then reason = prepared.reason
    end if
    print "Eaglewood: qr "; slot; " format bitdepth="; bit; " colortype="; color; " interlace="; interlace; " indexed="; indexed
    if prepared = invalid or prepared.ok <> true then print "Eaglewood: qr "; slot; " failure reason="; reason
end sub

sub PublishQr(slot as string, generation as integer, url as string, code as integer, prepared as object, path as string, bytes as integer)
    ok = "no"
    reason = "bad-png"
    bit = 0
    color = -1
    interlace = 0
    indexed = "no"
    if prepared <> invalid
        if prepared.ok = true then ok = "yes"
        if prepared.reason <> invalid and prepared.reason <> "" then reason = prepared.reason
        if prepared.bit <> invalid then bit = prepared.bit
        if prepared.color <> invalid then color = prepared.color
        if prepared.interlace <> invalid then interlace = prepared.interlace
        if prepared.converted = true or color = 3 then indexed = "yes"
    end if
    uri = path
    if uri = invalid then uri = ""
    if uri <> "" then ok = "yes"
    m.top.result = {
        generation: generation,
        generationText: generation.ToStr(),
        slot: slot,
        ok: ok,
        reason: reason,
        uri: uri,
        remote: url,
        code: code,
        bit: bit,
        color: color,
        interlace: interlace,
        indexed: indexed,
        bytes: bytes
    }
end sub

function FailQr(reason as string) as object
    return { ok: false, reason: reason, bit: 0, color: -1, interlace: 0, converted: false }
end function

function QrNotePath(slot as string) as string
    if slot = "badge" or slot = "book" or slot = "detail" or slot = "wifi" then return "cachefs:/eaglewood/qr-" + slot + ".url"
    return ""
end function

function QrPathNote(slot as string) as string
    if slot = "badge" or slot = "book" or slot = "detail" or slot = "wifi" then return "cachefs:/eaglewood/qr-" + slot + ".path"
    return ""
end function

sub EnsureQrDir()
    fs = CreateObject("roFileSystem")
    if fs <> invalid then fs.CreateDirectory("cachefs:/eaglewood")
end sub

sub DeleteQrFile(path as string)
    fs = CreateObject("roFileSystem")
    if fs <> invalid then fs.Delete(path)
end sub

function ReadQrGeneration() as integer
    generation = m.top.generation
    if generation <> invalid and generation <> 0 then return generation
    spins = 0
    while spins < 30
        Sleep(10)
        generation = m.top.generation
        if generation <> invalid and generation <> 0 then return generation
        spins = spins + 1
    end while
    if generation = invalid then return 0
    return generation
end function

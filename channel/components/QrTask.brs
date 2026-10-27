sub init()
    m.top.functionName = "fetchQrs"
end sub

' Public QR PNGs only. Grayscale files are rewritten to indexed PNGs before Poster.
sub fetchQrs()
    generation = ReadQrGeneration()
    FetchQr("badge", m.top.badgeUrl, generation)
    FetchQr("book", m.top.bookUrl, generation)
    FetchQr("detail", m.top.detailUrl, generation)
end sub

sub FetchQr(slot as string, url as string, generation as integer)
    if url = invalid then url = ""
    dest = QrPngPath(slot)
    if dest = "" then return
    if url = "" then return
    if CachedQr(slot, url)
        prepared = ExpandPngFile(dest, dest)
        LogQrFormat(slot, prepared)
        PublishQr(slot, generation, url, 0, prepared, dest)
        return
    end if
    print "Eaglewood: qr "; slot; " request sent"
    code = DownloadQr(url, "cachefs:/eaglewood/qr-next.png")
    print "Eaglewood: qr "; slot; " response code="; code
    if code <> 200
        PublishQr(slot, generation, url, code, FailQr("http"), "")
        return
    end if
    prepared = ExpandPngFile("cachefs:/eaglewood/qr-next.png", dest)
    DeleteQrFile("cachefs:/eaglewood/qr-next.png")
    LogQrFormat(slot, prepared)
    if prepared.ok = true then WriteAsciiFile(QrNotePath(slot), url)
    PublishQr(slot, generation, url, code, prepared, dest)
end sub

function CachedQr(slot as string, url as string) as boolean
    note = ReadAsciiFile(QrNotePath(slot))
    if note = invalid or note <> url then return false
    return PngFileExists(QrPngPath(slot))
end function

function DownloadQr(url as string, dest as string) as integer
    EnsureQrDir()
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

sub PublishQr(slot as string, generation as integer, url as string, code as integer, prepared as object, path as string)
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
    uri = ""
    if ok = "yes" then uri = path
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
        indexed: indexed
    }
end sub

function FailQr(reason as string) as object
    return { ok: false, reason: reason, bit: 0, color: -1, interlace: 0, converted: false }
end function

function QrPngPath(slot as string) as string
    if slot = "badge" then return "cachefs:/eaglewood/qr-badge.png"
    if slot = "book" then return "cachefs:/eaglewood/qr-book.png"
    if slot = "detail" then return "cachefs:/eaglewood/qr-detail.png"
    return ""
end function

function QrNotePath(slot as string) as string
    if slot = "badge" then return "cachefs:/eaglewood/qr-badge.url"
    if slot = "book" then return "cachefs:/eaglewood/qr-book.url"
    if slot = "detail" then return "cachefs:/eaglewood/qr-detail.url"
    return ""
end function

function PngFileExists(path as string) as boolean
    wrapped = ReadFileBytes(path)
    if wrapped = invalid then return false
    if wrapped.n < 8 then return false
    if BufAt(wrapped, 0) <> 137 or BufAt(wrapped, 1) <> 80 then return false
    return true
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

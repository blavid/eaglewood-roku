sub fetchGuest()
    generation = m.top.generation
    if generation = invalid then generation = 0
    url = GuestJsonUrl()
    if url = invalid or url = ""
        m.top.result = BlankGuestResult(generation)
        return
    end if
    m.top.result = FetchGuestDocument(url, generation)
end sub

function FetchGuestDocument(url as string, generation as integer) as object
    result = BlankGuestResult(generation)
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    if transfer = invalid or port = invalid then return result
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.SetUrl(WithCacheBuster(url))
    started = transfer.AsyncGetToString()
    if started = false or started = invalid
        return result
    end if
    event = wait(3000, port)
    if type(event) <> "roUrlEvent"
        transfer.AsyncCancel()
        return result
    end if
    if event.GetResponseCode() <> 200 then return result
    body = event.GetString()
    if body = invalid or Len(body) = 0 or Len(body) > 4096 then return result
    return GuestFields(ParseJson(body), generation)
end function

function WithCacheBuster(url as string) as string
    stamp = "0"
    clock = CreateObject("roDateTime")
    if clock <> invalid then stamp = clock.AsSeconds().ToStr()
    if Instr(1, url, "?") > 0 then return url + "&t=" + stamp
    return url + "?t=" + stamp
end function

sub init()
    m.greeting = m.top.findNode("greeting")
    m.top.backgroundColor = "0x100E0CFF"
    m.top.setFocus(true)
    m.top.observeField("relaunchCount", "onRelaunch")
    applyGreeting()
    printUiResolution()
end sub

sub onRelaunch()
    applyGreeting()
end sub

sub applyGreeting()
    text = BuildGreeting()
    if m.greeting <> invalid
        ' String assignment selects the built-in face. Size is set on that
        ' Font node afterward. A child Font uri cannot load a system font.
        m.greeting.font = "font:LargeBoldSystemFont"
        if m.greeting.font <> invalid
            m.greeting.font.size = 64
        end if
        m.greeting.color = "0xFFFFFFFF"
        m.greeting.width = 1760
        m.greeting.height = 160
        m.greeting.translation = [80, 800]
        m.greeting.horizAlign = "center"
        m.greeting.vertAlign = "center"
        m.greeting.text = text
    end if
    print "Eaglewood: greeting = "; text
end sub

sub printUiResolution()
    deviceInfo = CreateObject("roDeviceInfo")
    if deviceInfo = invalid then return
    ui = deviceInfo.GetUIResolution()
    if ui = invalid then return
    print "Eaglewood: ui = "; ui.name; " "; ui.width; "x"; ui.height
end sub

' Back is not consumed. On this screen that exits the app, which is what
' certification requires. The Home key never arrives; the OS leaves the app.
function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "back"
        return false
    end if
    return false
end function

' Optional local first name. Leave this empty for "Welcome to Eaglewood".
' A later version may read a public guest.json instead. Do not put a phone
' number, door PIN, or card number here. See the README.
function GuestFirstName() as string
    return ""
end function

function BuildGreeting() as string
    name = SanitizeFirstName(GuestFirstName())
    if name = "" then return "Welcome to Eaglewood"
    return "Welcome, " + name
end function

function SanitizeFirstName(raw as string) as string
    if raw = invalid then return ""
    text = raw.trim()
    if text = "" then return ""
    token = FirstToken(text)
    if token = "" then return ""
    ' Only a cut-off at 20 characters drops a dangling hyphen or apostrophe.
    ' A name that was typed with one of those at the end falls back instead.
    if token.len() > 20
        token = token.left(20)
        finished = false
        while not finished
            if token.len() = 0 then return ""
            last = token.right(1)
            if last = "-" or last = "'"
                token = token.left(token.len() - 1)
            else
                finished = true
            end if
        end while
    end if
    allowed = CreateObject("roRegex", "^[A-Za-z]([A-Za-z'-]*[A-Za-z])?$", "")
    if allowed.isMatch(token) then return token
    return ""
end function

function FirstToken(text as string) as string
    if text = "" then return ""
    spaceAt = Instr(1, text, " ")
    if spaceAt = 0 then return text
    if spaceAt = 1 then return ""
    return Left(text, spaceAt - 1)
end function

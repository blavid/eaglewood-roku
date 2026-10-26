sub init()
    m.greeting = m.top.findNode("greeting")
    m.backing = m.top.findNode("greetingBacking")
    m.guestTask = invalid
    m.fetchGeneration = 0
    m.top.backgroundColor = "0x100E0CFF"
    m.top.setFocus(true)
    m.top.observeField("relaunchCount", "onRelaunch")
    ShowGreeting(FallbackGreeting())
    startGuestFetch()
    printUiResolution()
end sub

sub onRelaunch()
    ShowGreeting(FallbackGreeting())
    startGuestFetch()
end sub

sub startGuestFetch()
    if m.guestTask <> invalid
        m.guestTask.unobserveField("result")
        m.guestTask.control = "STOP"
        m.guestTask = invalid
    end if
    m.fetchGeneration = m.fetchGeneration + 1
    task = CreateObject("roSGNode", "GuestTask")
    if task = invalid then return
    task.functionName = "fetchGuest"
    task.generation = m.fetchGeneration
    task.observeField("result", "onGuestFetch")
    m.guestTask = task
    task.control = "RUN"
end sub

sub onGuestFetch()
    task = m.guestTask
    if task = invalid then return
    result = task.result
    if result = invalid then return
    if result.generation <> m.fetchGeneration then return
    if result.ok <> "yes" then return
    present = false
    if result.checkoutPresent = "yes" then present = true
    text = GreetingFromGuest(result.firstName, result.lastName, result.checkout, present)
    ShowGreeting(text)
end sub

sub ShowGreeting(text as string)
    if text = invalid or text = "" then text = FallbackGreeting()
    layout = GreetingLayout(text)
    if m.backing <> invalid
        m.backing.color = "0x000000B3"
        m.backing.width = 1920
        m.backing.height = layout.barHeight
        m.backing.translation = [0, layout.barTop]
    end if
    if m.greeting <> invalid
        ' String assignment selects the built-in face. Size is set on that
        ' Font node afterward. A child Font uri cannot load a system font.
        m.greeting.font = "font:LargeBoldSystemFont"
        if m.greeting.font <> invalid then m.greeting.font.size = layout.fontSize
        m.greeting.color = "0xFFFFFFFF"
        m.greeting.width = GreetingLabelWidth()
        m.greeting.wrap = true
        m.greeting.maxLines = 2
        m.greeting.horizAlign = "center"
        m.greeting.vertAlign = "center"
        m.greeting.height = layout.barHeight
        m.greeting.translation = [80, layout.barTop]
        m.greeting.text = text
    end if
    print "Eaglewood: greeting = "; text
end sub

function GreetingLayout(text as string) as object
    sizes = GreetingFontSizes()
    chosen = sizes[sizes.Count() - 1]
    lineCount = 2
    index = 0
    while index < sizes.Count()
        size = sizes[index]
        fitted = WrapGreeting(text, GreetingLabelWidth(), SystemBoldFont(size), FallbackCharWidth(size))
        if fitted.Count() >= 1 and fitted.Count() <= 2
            chosen = size
            lineCount = fitted.Count()
            exit while
        end if
        index = index + 1
    end while
    bar = GreetingBarBox(lineCount, LineHeightForSize(chosen))
    bar.fontSize = chosen
    bar.lineCount = lineCount
    return bar
end function

function SystemBoldFont(size as integer) as object
    registry = CreateObject("roFontRegistry")
    if registry = invalid then return invalid
    return registry.GetDefaultFont(size, true, false)
end function

function LineHeightForSize(size as integer) as integer
    font = SystemBoldFont(size)
    if font <> invalid
        height = font.GetOneLineHeight()
        if height <> invalid and height > 0 then return height
    end if
    return size + (size \ 5)
end function

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

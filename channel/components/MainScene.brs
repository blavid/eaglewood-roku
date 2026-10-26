sub init()
    m.greeting = m.top.findNode("greeting")
    m.backing = m.top.findNode("greetingBacking")
    m.guestTask = invalid
    m.fetchGeneration = 0
    m.top.backgroundColor = "0x100E0CFF"
    m.top.setFocus(true)
    m.top.observeField("relaunchCount", "onRelaunch")
    ' Readable text before any layout. A layout failure must not leave this blank.
    ApplyPlainGreeting(FallbackGreeting())
    ShowGreeting(FallbackGreeting())
    startGuestFetch()
    printUiResolution()
end sub

sub onRelaunch()
    print "Eaglewood: relaunch"
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
    print "Eaglewood: task created generation="; m.fetchGeneration
    task = CreateObject("roSGNode", "GuestTask")
    if task = invalid
        print "Eaglewood: skip reason=task-create-failed"
        return
    end if
    task.functionName = "fetchGuest"
    task.generation = m.fetchGeneration
    task.observeField("result", "onGuestFetch")
    m.guestTask = task
    task.control = "RUN"
    print "Eaglewood: task started generation="; m.fetchGeneration
end sub

sub onGuestFetch()
    task = m.guestTask
    if task = invalid
        print "Eaglewood: skip reason=no-task"
        return
    end if
    result = task.result
    if result = invalid
        print "Eaglewood: skip reason=no-result"
        return
    end if
    if not GenerationMatches(result)
        print "Eaglewood: skip reason=generation"
        return
    end if
    seen = result.generationText
    if seen = invalid or seen = "" or seen = "0"
        print "Eaglewood: generation missing; applying current result"
    end if
    reason = "no"
    if result.reason <> invalid and result.reason <> "" then reason = result.reason
    ok = "no"
    if result.ok <> invalid then ok = result.ok
    print "Eaglewood: fetch result ok="; ok; " reason="; reason
    if ok <> "yes"
        print "Eaglewood: skip reason="; reason
        ShowGreeting(FallbackGreeting())
        return
    end if
    present = false
    if result.checkoutPresent = "yes" then present = true
    decision = CheckoutDecision(result.checkout, present, NowSeconds())
    print "Eaglewood: checkout decision="; decision
    text = GreetingFromGuest(result.firstName, result.lastName, result.checkout, present)
    ShowGreeting(text)
end sub

' The observer is only attached to the current task. A result whose generation
' is still 0 was published before that field was visible; apply it.
function GenerationMatches(result as object) as boolean
    want = m.fetchGeneration.ToStr()
    text = result.generationText
    number = result.generation
    if text <> invalid
        if text = want then return true
    end if
    if number <> invalid
        if number.ToStr() = want then return true
    end if
    blank = false
    if text = invalid or text = "" or text = "0" then blank = true
    if blank
        if number = invalid or number = 0 then return true
    end if
    return false
end function

sub ShowGreeting(text as string)
    if text = invalid or text = "" then text = FallbackGreeting()
    ApplyPlainGreeting(text)
    try
        ApplyGreetingLayout(text)
    catch err
        print "Eaglewood: layout error = "; LayoutErrorText(err)
    end try
    print "Eaglewood: greeting = "; text
end sub

' The same string assignment build 5 used. Built-in names only, no Font uri
' and no custom size. The label wraps; this does not measure glyphs.
sub ApplyPlainGreeting(text as string)
    if m.greeting = invalid then return
    m.greeting.font = "font:LargeBoldSystemFont"
    m.greeting.color = "0xFFFFFFFF"
    m.greeting.width = GreetingLabelWidth()
    m.greeting.wrap = true
    m.greeting.maxLines = 2
    m.greeting.horizAlign = "center"
    m.greeting.vertAlign = "center"
    m.greeting.height = GreetingBarMinHeight()
    m.greeting.translation = [80, 800]
    m.greeting.text = text
end sub

sub ApplyGreetingLayout(text as string)
    layout = GreetingLayout(text)
    if m.backing <> invalid
        m.backing.color = "0x000000B3"
        m.backing.width = 1920
        m.backing.height = layout.barHeight
        m.backing.translation = [0, layout.barTop]
    end if
    if m.greeting = invalid then return
    m.greeting.font = layout.fontName
    m.greeting.height = layout.barHeight
    m.greeting.translation = [80, layout.barTop]
end sub

function GreetingLayout(text as string) as object
    sizes = GreetingFontSizes()
    names = GreetingFontNames()
    chosen = sizes.Count() - 1
    lineCount = 2
    index = 0
    limit = GreetingLabelWidth()
    if text = invalid then text = ""
    while index < sizes.Count()
        pixels = Len(text) * FallbackCharWidth(sizes[index])
        if pixels <= limit
            chosen = index
            lineCount = 1
            exit while
        else if pixels <= (limit * 2)
            chosen = index
            lineCount = 2
            exit while
        end if
        index = index + 1
    end while
    if chosen >= names.Count() then chosen = names.Count() - 1
    if chosen < 0 then chosen = 0
    size = sizes[chosen]
    lineHeight = size + (size \ 5)
    bar = GreetingBarBox(lineCount, lineHeight)
    bar.fontName = names[chosen]
    bar.lineCount = lineCount
    return bar
end function

function GreetingFontNames() as object
    return ["font:LargeBoldSystemFont", "font:MediumBoldSystemFont", "font:SmallBoldSystemFont", "font:SmallestBoldSystemFont"]
end function

function LayoutErrorText(err as object) as string
    if err = invalid then return "layout failed"
    kind = type(err)
    if kind = "String" or kind = "roString" then return err
    if kind = "roAssociativeArray"
        message = err.Lookup("message")
        if message <> invalid and message <> "" then return message
    end if
    return "layout failed"
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

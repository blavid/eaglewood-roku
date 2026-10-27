sub init()
    m.greeting = m.top.findNode("greeting")
    m.backing = m.top.findNode("greetingBacking")
    m.idleTimer = m.top.findNode("idleTimer")
    m.guestTask = invalid
    m.guideTask = invalid
    m.fetchGeneration = 0
    m.guideGeneration = 0
    m.shell = invalid
    m.zone = "tiles"
    m.section = "home"
    m.tileIndex = 0
    m.railIndex = 0
    m.issueIndex = 0
    m.stepScroll = 0
    m.ruleScroll = 0
    m.checkoutScroll = 0
    m.guestCheckout = ""
    m.guestCheckoutPresent = "no"
    m.guestStay = "missing"
    m.brand = "Eaglewood"
    m.place = "Sunriver, Oregon"
    m.domain = "sunrivertownhome.com"
    m.checkIn = "4:00 PM"
    m.checkOut = "11:00 AM"
    m.quietHours = "Quiet hours after 10:00 PM"
    m.hostName = ""
    m.hostEmail = ""
    m.hostPhone = ""
    m.summary = ""
    m.guideSource = "builtin"
    m.guideCode = "0"
    m.guideVersion = "0"
    m.checkoutSource = "builtin"
    m.checkoutCode = "0"
    m.checkoutVersion = "0"
    m.rules = []
    m.issues = []
    m.checkoutSteps = []
    m.top.backgroundColor = "0x100E0CFF"
    m.top.setFocus(true)
    m.top.observeField("relaunchCount", "onRelaunch")
    ' Readable text before any layout. A layout failure must not leave this blank.
    ApplyPlainGreeting(FallbackGreeting())
    ShowGreeting(FallbackGreeting())
    try
        BuildShell()
        ApplyBundle(BuiltinBundle())
        ShowSection("home")
        print "Eaglewood: screen=home zone=tiles"
    catch err
        print "Eaglewood: layout error = "; LayoutErrorText(err)
    end try
    if m.idleTimer <> invalid then m.idleTimer.observeField("fire", "onIdle")
    BumpIdle()
    HoldFocus()
    startGuestFetch()
    startGuideFetch()
    printUiResolution()
end sub

sub onRelaunch()
    print "Eaglewood: relaunch"
    m.guestStay = "missing"
    m.guestCheckout = ""
    m.guestCheckoutPresent = "no"
    ShowGreeting(FallbackGreeting())
    m.zone = "tiles"
    m.section = "home"
    m.railIndex = 0
    m.tileIndex = 0
    m.issueIndex = 0
    m.stepScroll = 0
    ShowSection("home")
    print "Eaglewood: screen=home zone=tiles"
    PaintAll()
    HoldFocus()
    BumpIdle()
    startGuestFetch()
    startGuideFetch()
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

sub startGuideFetch()
    if m.guideTask <> invalid
        m.guideTask.unobserveField("result")
        m.guideTask.control = "STOP"
        m.guideTask = invalid
    end if
    m.guideGeneration = m.guideGeneration + 1
    print "Eaglewood: guide task created generation="; m.guideGeneration
    task = CreateObject("roSGNode", "GuideTask")
    if task = invalid
        print "Eaglewood: guide skip reason=task-create-failed"
        return
    end if
    task.functionName = "fetchGuideBundle"
    task.generation = m.guideGeneration
    task.observeField("result", "onGuideFetch")
    m.guideTask = task
    task.control = "RUN"
    print "Eaglewood: guide task started generation="; m.guideGeneration
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
        m.guestStay = "missing"
        m.guestCheckout = ""
        m.guestCheckoutPresent = "no"
        RefreshHomeLine()
        ShowGreeting(FallbackGreeting())
        return
    end if
    present = false
    if result.checkoutPresent = "yes" then present = true
    decision = CheckoutDecision(result.checkout, present, NowSeconds())
    print "Eaglewood: checkout decision="; decision
    m.guestStay = decision
    m.guestCheckout = AsText(result.checkout)
    m.guestCheckoutPresent = "no"
    if result.checkoutPresent <> invalid then m.guestCheckoutPresent = result.checkoutPresent
    RefreshHomeLine()
    text = GreetingFromGuest(result.firstName, result.lastName, result.checkout, present)
    ShowGreeting(text)
end sub

sub onGuideFetch()
    task = m.guideTask
    if task = invalid
        print "Eaglewood: guide skip reason=no-task"
        return
    end if
    result = task.result
    if result = invalid
        print "Eaglewood: guide skip reason=no-result"
        return
    end if
    if not GuideGenerationMatches(result)
        print "Eaglewood: guide skip reason=generation"
        return
    end if
    try
        ApplyBundle(BundleFromResult(result))
    catch err
        print "Eaglewood: layout error = "; LayoutErrorText(err)
        HoldFocus()
        return
    end try
    rules = 0
    issues = 0
    steps = 0
    if m.rules <> invalid then rules = m.rules.Count()
    if m.issues <> invalid then issues = m.issues.Count()
    if m.checkoutSteps <> invalid then steps = m.checkoutSteps.Count()
    print "Eaglewood: guide applied source="; m.guideSource; " version="; m.guideVersion; " rules="; rules; " issues="; issues
    present = "no"
    if result.hostPhonePresent <> invalid and result.hostPhonePresent <> "" then present = result.hostPhonePresent
    print "Eaglewood: host phone present="; present
    print "Eaglewood: checkout applied source="; m.checkoutSource; " version="; m.checkoutVersion; " steps="; steps
    HoldFocus()
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

function GuideGenerationMatches(result as object) as boolean
    want = m.guideGeneration.ToStr()
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

' Built-in names only, on the Label font field. The label wraps; this does not
' measure glyphs. Text is assigned before ApplyGreetingLayout runs.
sub ApplyPlainGreeting(text as string)
    if m.backing <> invalid then m.backing.visible = false
    if m.greeting = invalid then return
    m.greeting.font = "font:LargeBoldSystemFont"
    m.greeting.color = "0xFFFFFFFF"
    m.greeting.width = GreetingLabelWidth()
    m.greeting.wrap = true
    m.greeting.maxLines = 2
    m.greeting.horizAlign = "left"
    m.greeting.vertAlign = "center"
    m.greeting.height = 130
    m.greeting.translation = [ContentLeft(), ContentTop()]
    m.greeting.text = text
end sub

sub ApplyGreetingLayout(text as string)
    if m.backing <> invalid then m.backing.visible = false
    if m.greeting = invalid then return
    m.greeting.font = GreetingFace(text)
end sub

function GreetingFontNames() as object
    return ["font:LargeBoldSystemFont", "font:MediumBoldSystemFont", "font:SmallBoldSystemFont", "font:SmallestBoldSystemFont"]
end function

function GreetingFace(text as string) as string
    names = GreetingFontNames()
    sizes = GreetingFontSizes()
    chosen = 0
    if names.Count() < 1 then return "font:LargeBoldSystemFont"
    chosen = names.Count() - 1
    limit = GreetingLabelWidth()
    if text = invalid then text = ""
    last = sizes.Count() - 1
    if last < 0 then return names[0]
    for index = 0 to last
        pixels = Len(text) * FallbackCharWidth(sizes[index])
        if pixels <= (limit * 2)
            chosen = index
            exit for
        end if
    end for
    if chosen >= names.Count() then chosen = names.Count() - 1
    if chosen < 0 then chosen = 0
    return names[chosen]
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

function onKeyEvent(key as string, press as boolean) as boolean
    if press <> true then return false
    handled = true
    try
        handled = RouteKey(key)
    catch err
        print "Eaglewood: key error = "; LayoutErrorText(err)
        HoldFocus()
        handled = true
        if key = "back"
            if m.section = "home" and m.zone = "rail" then handled = false
        end if
    end try
    return handled
end function

function RouteKey(key as string) as boolean
    BumpIdle()
    HoldFocus()
    if m.shell = invalid
        if key = "back"
            print "Eaglewood: back exit"
            return false
        end if
        return true
    end if
    if key = "back" then return HandleBack()
    if key = "up" then return HandleVertical(-1)
    if key = "down" then return HandleVertical(1)
    if key = "left" then return HandleLeft()
    if key = "right" then return HandleRight()
    if key = "OK" then return HandleOk()
    return false
end function

function HandleVertical(direction as integer) as boolean
    if m.zone = "rail" then return MoveRail(direction)
    if m.zone = "tiles" then return MoveTiles(direction)
    if m.zone = "list" then return MoveIssue(direction)
    if m.zone = "detail" then return MoveStepScroll(direction)
    if m.zone = "panel" and m.section = "rules" then return MoveRuleScroll(direction)
    if m.zone = "panel" and m.section = "checkout" then return MoveCheckoutScroll(direction)
    return true
end function

function MoveRail(direction as integer) as boolean
    sections = RailSections()
    nextIndex = m.railIndex + direction
    if nextIndex < 0 or nextIndex >= sections.Count() then return true
    m.railIndex = nextIndex
    PreviewSection(sections[nextIndex])
    return true
end function

function MoveTiles(direction as integer) as boolean
    row = m.tileIndex \ 3
    if direction < 0
        if row > 0 then m.tileIndex = m.tileIndex - 3
    else
        if row = 0 then m.tileIndex = m.tileIndex + 3
    end if
    PaintTiles()
    HoldFocus()
    return true
end function

function MoveIssue(direction as integer) as boolean
    count = IssueCount()
    if count < 1 then return true
    nextIndex = m.issueIndex + direction
    if nextIndex < 0 or nextIndex >= count then return true
    m.issueIndex = nextIndex
    m.stepScroll = 0
    PaintFixes()
    HoldFocus()
    return true
end function

function MoveStepScroll(direction as integer) as boolean
    maxScroll = StepCount() - VisibleSteps()
    if maxScroll < 0 then maxScroll = 0
    nextScroll = m.stepScroll + direction
    if nextScroll < 0 or nextScroll > maxScroll then return true
    m.stepScroll = nextScroll
    PaintFixes()
    HoldFocus()
    return true
end function

function MoveRuleScroll(direction as integer) as boolean
    maxScroll = RuleCount() - VisibleRules()
    if maxScroll < 0 then maxScroll = 0
    nextScroll = m.ruleScroll + direction
    if nextScroll < 0 or nextScroll > maxScroll then return true
    m.ruleScroll = nextScroll
    PaintRules()
    HoldFocus()
    return true
end function

function MoveCheckoutScroll(direction as integer) as boolean
    maxScroll = CheckoutStepCount() - VisibleCheckoutSteps()
    if maxScroll < 0 then maxScroll = 0
    nextScroll = m.checkoutScroll + direction
    if nextScroll < 0 or nextScroll > maxScroll then return true
    m.checkoutScroll = nextScroll
    PaintCheckout()
    HoldFocus()
    return true
end function

function HandleLeft() as boolean
    if m.zone = "detail"
        m.zone = "list"
        print "Eaglewood: screen="; m.section; " zone=list"
        PaintFixes()
        HoldFocus()
        return true
    end if
    if m.zone = "tiles"
        col = m.tileIndex mod 3
        if col > 0
            m.tileIndex = m.tileIndex - 1
            PaintTiles()
            HoldFocus()
            return true
        end if
        return FocusRail()
    end if
    if m.zone = "list" or m.zone = "panel" then return FocusRail()
    if m.zone = "rail"
        if m.section = "home" then return true
        return GoHomeOnRail()
    end if
    return true
end function

function HandleRight() as boolean
    if m.zone = "rail"
        OpenSection(CurrentRailSection())
        return true
    end if
    if m.zone = "tiles"
        col = m.tileIndex mod 3
        if col < 2 then m.tileIndex = m.tileIndex + 1
        PaintTiles()
        HoldFocus()
        return true
    end if
    if m.zone = "list" then return OpenStepScroll()
    return true
end function

function HandleOk() as boolean
    if m.zone = "rail"
        OpenSection(CurrentRailSection())
        return true
    end if
    if m.zone = "tiles"
        OpenSection(CurrentTileSection())
        return true
    end if
    if m.zone = "list" then return OpenStepScroll()
    return true
end function

function HandleBack() as boolean
    if m.zone <> "rail"
        return FocusRail()
    end if
    if m.section <> "home" then return GoHomeOnRail()
    print "Eaglewood: back exit"
    return false
end function

function FocusRail() as boolean
    m.zone = "rail"
    print "Eaglewood: screen="; m.section; " zone=rail"
    PaintAll()
    HoldFocus()
    return true
end function

function GoHomeOnRail() as boolean
    m.zone = "rail"
    m.section = "home"
    m.railIndex = 0
    m.tileIndex = 0
    ShowSection("home")
    print "Eaglewood: screen=home zone=rail"
    PaintAll()
    HoldFocus()
    return true
end function

function CurrentRailSection() as string
    sections = RailSections()
    if m.railIndex < 0 or m.railIndex >= sections.Count() then return "home"
    return sections[m.railIndex]
end function

function CurrentTileSection() as string
    sections = TileSections()
    if m.tileIndex < 0 or m.tileIndex >= sections.Count() then return "wifi"
    return sections[m.tileIndex]
end function

sub OpenSection(section as string)
    m.section = section
    m.railIndex = RailIndexOf(section)
    if section = "home"
        m.zone = "tiles"
        m.tileIndex = 0
    else if section = "fixes"
        m.zone = "list"
        m.stepScroll = 0
    else
        m.zone = "panel"
    end if
    ShowSection(section)
    print "Eaglewood: screen="; section; " zone="; m.zone
    PaintAll()
    HoldFocus()
end sub

sub PreviewSection(section as string)
    m.section = section
    ShowSection(section)
    print "Eaglewood: screen="; section; " zone="; m.zone
    PaintAll()
    HoldFocus()
end sub

function OpenStepScroll() as boolean
    if StepCount() <= VisibleSteps() then return true
    m.zone = "detail"
    if m.stepScroll < 0 then m.stepScroll = 0
    print "Eaglewood: screen="; m.section; " zone=detail"
    PaintFixes()
    HoldFocus()
    return true
end function

sub onIdle()
    if m.idleTimer = invalid then return
    if m.idleTimer.fire <> true then return
    print "Eaglewood: idle return home"
    try
        m.section = "home"
        m.zone = "tiles"
        m.railIndex = 0
        m.tileIndex = 0
        m.issueIndex = 0
        m.stepScroll = 0
        m.ruleScroll = 0
        m.checkoutScroll = 0
        ShowSection("home")
        print "Eaglewood: screen=home zone=tiles"
        PaintAll()
        HoldFocus()
    catch err
        print "Eaglewood: layout error = "; LayoutErrorText(err)
        HoldFocus()
    end try
    BumpIdle()
end sub

sub BumpIdle()
    if m.idleTimer = invalid then return
    m.idleTimer.control = "stop"
    m.idleTimer.duration = 600
    m.idleTimer.control = "start"
end sub

sub HoldFocus()
    focused = true
    try
        focused = m.top.hasFocus()
    catch err
        focused = false
        print "Eaglewood: layout error = "; LayoutErrorText(err)
    end try
    if focused = true then return
    m.top.setFocus(true)
    print "Eaglewood: focus restored"
end sub

' SceneGraph chrome for the guest guide. The scene keeps focus; these nodes are not focusable.

function ContentLeft() as integer
    return 588
end function

function ContentTop() as integer
    return 120
end function

function ContentWidth() as integer
    return GreetingLabelWidth()
end function

function RailX() as integer
    return 192
end function

function RailY() as integer
    return 120
end function

function RailW() as integer
    return 372
end function

function RailH() as integer
    return 792
end function

function VisibleIssueRows() as integer
    return 8
end function

function VisibleSteps() as integer
    return 4
end function

function VisibleRules() as integer
    return 8
end function

function VisibleCheckoutSteps() as integer
    return 6
end function

function AmberColor() as string
    return "0xF2A93BFF"
end function

function InkColor() as string
    return "0xFFFFFFFF"
end function

function MuteColor() as string
    return "0xD5DBE8FF"
end function

function InkOnAmber() as string
    return "0x1C1408FF"
end function

function GlassColor() as string
    return "0x1A2438D0"
end function

function TileColor() as string
    return "0x243044C8"
end function

function RailSections() as object
    return ["home", "rules", "fixes", "todo", "dining", "hiking", "checkout", "wifi", "help"]
end function

function TileSections() as object
    return ["wifi", "todo", "dining", "hiking", "fixes", "checkout"]
end function

function RailLabel(section as string) as string
    if section = "home" then return "Home"
    if section = "rules" then return "House Rules"
    if section = "fixes" then return "Troubleshooting"
    if section = "todo" then return "Things to Do"
    if section = "dining" then return "Dining"
    if section = "hiking" then return "Hiking"
    if section = "checkout" then return "Checkout"
    if section = "wifi" then return "Wi-Fi"
    if section = "help" then return "Help"
    return "Home"
end function

function TileTitle(section as string) as string
    if section = "fixes" then return "Quick Fixes"
    return RailLabel(section)
end function

function SoonSection(section as string) as boolean
    if section = "todo" or section = "dining" or section = "hiking" or section = "wifi" then return true
    return false
end function

function RailIndexOf(section as string) as integer
    sections = RailSections()
    last = sections.Count() - 1
    for index = 0 to last
        if sections[index] = section then return index
    end for
    return 0
end function

function AsText(value as object) as string
    if value = invalid then return ""
    kind = type(value)
    if kind <> "String" and kind <> "roString" then return ""
    return value
end function

function OrText(value as object, fallback as string) as string
    text = AsText(value)
    if text = "" then return fallback
    return text
end function

function DecodeList(text as object) as object
    raw = AsText(text)
    if raw = "" then return []
    parsed = ParseJson(raw)
    if parsed = invalid then return []
    kind = type(parsed)
    if kind <> "roArray" and kind <> "Array" then return []
    return parsed
end function

sub BuildShell()
    shell = CreateObject("roSGNode", "Group")
    shell.translation = [0, 0]

    panel = AddRect(shell, GlassColor(), RailX(), RailY(), RailW(), RailH())
    panel.cornerRadius = 28
    m.railBrand = AddLabel(shell, "Eaglewood", "font:MediumBoldSystemFont", InkColor(), RailX() + 24, RailY() + 18, RailW() - 48, 40)
    m.railPlace = AddLabel(shell, "Sunriver, Oregon", "font:SmallSystemFont", MuteColor(), RailX() + 24, RailY() + 58, RailW() - 48, 32)

    m.railItems = []
    sections = RailSections()
    last = sections.Count() - 1
    for index = 0 to last
        group = CreateObject("roSGNode", "Group")
        group.translation = [RailX() + 12, RailY() + 112 + (index * 72)]
        bg = AddRect(group, "0x00000000", 0, 0, RailW() - 24, 64)
        bg.cornerRadius = 16
        label = AddLabel(group, RailLabel(sections[index]), "font:MediumBoldSystemFont", InkColor(), 16, 0, RailW() - 56, 64)
        shell.appendChild(group)
        m.railItems.Push({ group: group, bg: bg, label: label })
    end for

    m.homePane = CreateObject("roSGNode", "Group")
    shell.appendChild(m.homePane)
    m.subtitle = AddLabel(m.homePane, "Checkout", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 138, ContentWidth(), 56)
    m.subtitle.vertAlign = "top"
    m.subtitle.maxLines = 2
    BuildTiles(m.homePane)

    m.rulesPane = BuildRulesPane(shell)
    m.fixesPane = BuildFixesPane(shell)
    m.checkoutPane = BuildCheckoutPane(shell)
    m.helpPane = BuildHelpPane(shell)
    m.soonPane = BuildSoonPane(shell)

    m.footer = AddLabel(shell, FooterLine(), "font:SmallSystemFont", MuteColor(), ContentLeft(), 928, ContentWidth() - 300, 36)
    m.offline = AddLabel(shell, "", "font:SmallSystemFont", AmberColor(), ContentLeft() + ContentWidth() - 280, 928, 280, 36)
    m.offline.horizAlign = "right"
    m.offline.visible = false

    m.top.appendChild(shell)
    m.shell = shell
end sub

sub BuildTiles(parent as object)
    m.tiles = []
    sections = TileSections()
    tileW = 362
    tileH = 210
    originY = ContentTop() + 210
    last = sections.Count() - 1
    for index = 0 to last
        col = index mod 3
        row = index \ 3
        x = ContentLeft() + (col * (tileW + 22))
        y = originY + (row * (tileH + 22))
        group = CreateObject("roSGNode", "Group")
        group.translation = [x, y]
        outer = AddRect(group, TileColor(), 0, 0, tileW, tileH)
        outer.cornerRadius = 18
        inner = AddRect(group, TileColor(), 0, 0, tileW, tileH)
        inner.cornerRadius = 18
        title = AddLabel(group, TileTitle(sections[index]), "font:MediumBoldSystemFont", InkColor(), 22, 48, tileW - 44, 64)
        title.vertAlign = "center"
        subLabel = AddLabel(group, "", "font:SmallSystemFont", MuteColor(), 22, 116, tileW - 44, 40)
        parent.appendChild(group)
        m.tiles.Push({
            group: group,
            outer: outer,
            inner: inner,
            title: title,
            subLabel: subLabel,
            wide: tileW,
            tall: tileH,
            section: sections[index]
        })
    end for
end sub

function BuildRulesPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    AddLabel(pane, "House Rules", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 64)
    m.rulesMeta = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 68, ContentWidth(), 36)
    m.ruleLabels = []
    last = VisibleRules() - 1
    for index = 0 to last
        label = AddLabel(pane, "", "font:SmallSystemFont", InkColor(), ContentLeft(), ContentTop() + 116 + (index * 72), ContentWidth(), 68)
        label.vertAlign = "top"
        label.maxLines = 2
        m.ruleLabels.Push(label)
    end for
    return pane
end function

function BuildFixesPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    AddLabel(pane, "Troubleshooting", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 64)
    listX = ContentLeft()
    listY = ContentTop() + 78
    m.issueRows = []
    last = VisibleIssueRows() - 1
    for index = 0 to last
        group = CreateObject("roSGNode", "Group")
        group.translation = [listX, listY + (index * 66)]
        bg = AddRect(group, "0x00000000", 0, 0, 456, 60)
        bg.cornerRadius = 14
        label = AddLabel(group, "", "font:SmallBoldSystemFont", InkColor(), 16, 0, 424, 60)
        label.maxLines = 2
        pane.appendChild(group)
        m.issueRows.Push({ group: group, bg: bg, label: label })
    end for

    card = AddRect(pane, GlassColor(), ContentLeft() + 476, listY, 656, 528)
    card.cornerRadius = 20
    m.detailTitle = AddLabel(pane, "", "font:MediumBoldSystemFont", InkColor(), ContentLeft() + 500, listY + 16, 608, 88)
    m.detailTitle.vertAlign = "top"
    m.detailTitle.maxLines = 2
    m.stepRows = []
    stepLast = VisibleSteps() - 1
    for index = 0 to stepLast
        group = CreateObject("roSGNode", "Group")
        group.translation = [ContentLeft() + 500, listY + 112 + (index * 96)]
        badge = AddRect(group, AmberColor(), 0, 4, 36, 36)
        badge.cornerRadius = 18
        numberLabel = AddLabel(group, "", "font:SmallBoldSystemFont", InkOnAmber(), 0, 4, 36, 36)
        numberLabel.horizAlign = "center"
        body = AddLabel(group, "", "font:SmallSystemFont", InkColor(), 48, 0, 560, 92)
        body.vertAlign = "top"
        body.maxLines = 3
        pane.appendChild(group)
        m.stepRows.Push({ group: group, badge: badge, numberLabel: numberLabel, body: body })
    end for
    m.fixesHint = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), 868, ContentWidth(), 32)
    return pane
end function

function BuildCheckoutPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    AddLabel(pane, "Checkout", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 64)
    m.checkoutWhen = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 68, ContentWidth(), 36)
    m.checkoutSummary = AddLabel(pane, "", "font:SmallSystemFont", InkColor(), ContentLeft(), ContentTop() + 112, ContentWidth(), 110)
    m.checkoutSummary.vertAlign = "top"
    m.checkoutSummary.maxLines = 4
    m.checkoutStepRows = []
    last = VisibleCheckoutSteps() - 1
    for index = 0 to last
        group = CreateObject("roSGNode", "Group")
        group.translation = [ContentLeft(), ContentTop() + 236 + (index * 72)]
        badge = AddRect(group, AmberColor(), 0, 8, 36, 36)
        badge.cornerRadius = 18
        numberLabel = AddLabel(group, "", "font:SmallBoldSystemFont", InkOnAmber(), 0, 8, 36, 36)
        numberLabel.horizAlign = "center"
        body = AddLabel(group, "", "font:SmallSystemFont", InkColor(), 52, 0, ContentWidth() - 52, 68)
        body.maxLines = 2
        pane.appendChild(group)
        m.checkoutStepRows.Push({ group: group, numberLabel: numberLabel, body: body })
    end for
    m.checkoutHost = AddLabel(pane, "", "font:SmallSystemFont", InkColor(), ContentLeft(), 860, ContentWidth(), 36)
    return pane
end function

function BuildHelpPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    AddLabel(pane, "Help", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 64)
    m.helpName = AddLabel(pane, "", "font:MediumBoldSystemFont", InkColor(), ContentLeft(), ContentTop() + 96, ContentWidth(), 48)
    m.helpEmail = AddLabel(pane, "", "font:MediumSystemFont", InkColor(), ContentLeft(), ContentTop() + 156, ContentWidth(), 44)
    m.helpPhone = AddLabel(pane, "", "font:MediumBoldSystemFont", AmberColor(), ContentLeft(), ContentTop() + 214, ContentWidth(), 48)
    m.helpPhone.visible = false
    m.helpNote = AddLabel(pane, "Message us in your booking app.", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 280, ContentWidth(), 40)
    return pane
end function

function BuildSoonPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    m.soonTitle = AddLabel(pane, "", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 64)
    m.soonBody = AddLabel(pane, "Coming soon", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop() + 140, ContentWidth(), 64)
    m.soonMore = AddLabel(pane, "Coming in a later update.", "font:MediumSystemFont", MuteColor(), ContentLeft(), ContentTop() + 214, ContentWidth(), 44)
    return pane
end function

function AddRect(parent as object, color as string, x as integer, y as integer, width as integer, height as integer) as object
    rect = CreateObject("roSGNode", "Rectangle")
    rect.color = color
    rect.width = width
    rect.height = height
    rect.translation = [x, y]
    parent.appendChild(rect)
    return rect
end function

function AddLabel(parent as object, text as string, fontName as string, color as string, x as integer, y as integer, width as integer, height as integer) as object
    label = CreateObject("roSGNode", "Label")
    label.font = fontName
    label.color = color
    label.width = width
    label.height = height
    label.wrap = true
    label.vertAlign = "center"
    label.text = text
    label.translation = [x, y]
    parent.appendChild(label)
    return label
end function

sub ShowSection(section as string)
    if m.homePane <> invalid then m.homePane.visible = (section = "home")
    if m.greeting <> invalid then m.greeting.visible = (section = "home")
    if m.rulesPane <> invalid then m.rulesPane.visible = (section = "rules")
    if m.fixesPane <> invalid then m.fixesPane.visible = (section = "fixes")
    if m.checkoutPane <> invalid then m.checkoutPane.visible = (section = "checkout")
    if m.helpPane <> invalid then m.helpPane.visible = (section = "help")
    if m.soonPane <> invalid then m.soonPane.visible = SoonSection(section)
end sub

sub PaintAll()
    if m.shell = invalid then return
    PaintChrome()
    PaintRail()
    PaintTiles()
    PaintRules()
    PaintFixes()
    PaintCheckout()
    PaintHelp()
    PaintSoon()
    RefreshHomeLine()
end sub

sub PaintChrome()
    if m.railBrand <> invalid then m.railBrand.text = OrText(m.brand, "Eaglewood")
    if m.railPlace <> invalid then m.railPlace.text = OrText(m.place, "Sunriver, Oregon")
    if m.footer <> invalid then m.footer.text = FooterLine()
    PaintOffline()
end sub

sub PaintOffline()
    if m.offline = invalid then return
    text = ""
    if m.guideSource = "builtin" then text = "Offline copy"
    if m.guideSource = "pkg" then text = "Packaged copy"
    if m.guideSource = "cachefs" then text = "Saved copy"
    if text = ""
        m.offline.text = ""
        m.offline.visible = false
        return
    end if
    m.offline.text = text
    m.offline.visible = true
end sub

sub RefreshHomeLine()
    if m.subtitle = invalid then return
    m.subtitle.text = HomeStatusLine()
end sub

sub PaintRail()
    if m.railItems = invalid then return
    last = m.railItems.Count() - 1
    if last < 0 then return
    for index = 0 to last
        row = m.railItems[index]
        current = (index = m.railIndex)
        focused = current and m.zone = "rail"
        if focused
            row.bg.color = AmberColor()
            row.label.color = InkOnAmber()
        else if current
            row.bg.color = "0xFFFFFF2E"
            row.label.color = InkColor()
        else
            row.bg.color = "0x00000000"
            row.label.color = InkColor()
        end if
    end for
end sub

sub PaintTiles()
    if m.tiles = invalid then return
    last = m.tiles.Count() - 1
    if last < 0 then return
    for index = 0 to last
        tile = m.tiles[index]
        focused = (m.zone = "tiles" and index = m.tileIndex and m.section = "home")
        if focused
            tile.outer.color = AmberColor()
            tile.inner.translation = [6, 6]
            tile.inner.width = tile.wide - 12
            tile.inner.height = tile.tall - 12
        else
            tile.outer.color = TileColor()
            tile.inner.translation = [0, 0]
            tile.inner.width = tile.wide
            tile.inner.height = tile.tall
        end if
        tile.inner.color = TileColor()
        tile.subLabel.text = TileSubtitle(tile.section)
    end for
end sub

function TileSubtitle(section as string) as string
    if section = "wifi" then return "Scan to join"
    if section = "todo" then return "9 categories"
    if section = "dining" then return "Village & Bend"
    if section = "hiking" then return "6 trails"
    if section = "fixes" then return IssueCount().ToStr() + " how-tos"
    if section = "checkout"
        if m.checkOut <> invalid and m.checkOut <> "" then return "Before " + m.checkOut
        return "Before checkout"
    end if
    return ""
end function

function IssueCount() as integer
    if m.issues = invalid then return 0
    return m.issues.Count()
end function

function RuleCount() as integer
    if m.rules = invalid then return 0
    return m.rules.Count()
end function

function CheckoutStepCount() as integer
    if m.checkoutSteps = invalid then return 0
    return m.checkoutSteps.Count()
end function

function CurrentIssue() as object
    if m.issues = invalid then return invalid
    if m.issueIndex < 0 or m.issueIndex >= m.issues.Count() then return invalid
    return m.issues[m.issueIndex]
end function

function StepCount() as integer
    issue = CurrentIssue()
    if issue = invalid then return 0
    steps = issue.Lookup("steps")
    if steps = invalid then return 0
    kind = type(steps)
    if kind <> "roArray" and kind <> "Array" then return 0
    return steps.Count()
end function

function ListText(value as object, index as integer) as string
    if value = invalid then return ""
    if index < 0 or index >= value.Count() then return ""
    return AsText(value[index])
end function

sub PaintRules()
    if m.ruleLabels = invalid then return
    if m.rulesMeta <> invalid
        m.rulesMeta.text = "Check-in " + m.checkIn + " · Check-out " + m.checkOut
    end if
    start = WindowStart(RuleCount(), VisibleRules(), m.ruleScroll)
    last = m.ruleLabels.Count() - 1
    if last < 0 then return
    for index = 0 to last
        label = m.ruleLabels[index]
        text = ListText(m.rules, start + index)
        if text = ""
            label.visible = false
            label.text = ""
        else
            label.visible = true
            label.text = "-  " + text
        end if
    end for
end sub

sub PaintFixes()
    if m.issueRows = invalid then return
    count = IssueCount()
    start = WindowStart(count, VisibleIssueRows(), IssueWindowBias())
    last = m.issueRows.Count() - 1
    for index = 0 to last
        row = m.issueRows[index]
        issueIndex = start + index
        if issueIndex >= count
            row.group.visible = false
        else
            row.group.visible = true
            issue = m.issues[issueIndex]
            row.label.text = AsText(issue.Lookup("issue"))
            selected = (issueIndex = m.issueIndex)
            focused = selected and m.zone = "list"
            if focused
                row.bg.color = AmberColor()
                row.label.color = InkOnAmber()
            else if selected
                row.bg.color = "0xFFFFFF2E"
                row.label.color = InkColor()
            else
                row.bg.color = "0x00000000"
                row.label.color = InkColor()
            end if
        end if
    end for
    PaintSteps()
    if m.fixesHint <> invalid then m.fixesHint.text = FixesHint()
end sub

function IssueWindowBias() as integer
    count = IssueCount()
    visible = VisibleIssueRows()
    if count <= visible then return 0
    start = m.issueIndex - 3
    if start < 0 then start = 0
    if start > count - visible then return count - visible
    return start
end function

function WindowStart(count as integer, visible as integer, scroll as integer) as integer
    if count <= visible then return 0
    start = scroll
    if start < 0 then start = 0
    if start > count - visible then return count - visible
    return start
end function

sub PaintSteps()
    if m.stepRows = invalid then return
    issue = CurrentIssue()
    title = ""
    steps = invalid
    if issue <> invalid
        title = AsText(issue.Lookup("issue"))
        steps = issue.Lookup("steps")
    end if
    if m.detailTitle <> invalid then m.detailTitle.text = title
    maxScroll = StepCount() - VisibleSteps()
    if maxScroll < 0 then maxScroll = 0
    if m.stepScroll > maxScroll then m.stepScroll = maxScroll
    if m.stepScroll < 0 then m.stepScroll = 0
    last = m.stepRows.Count() - 1
    for index = 0 to last
        row = m.stepRows[index]
        stepIndex = m.stepScroll + index
        text = ""
        if steps <> invalid then text = ListText(steps, stepIndex)
        if text = ""
            row.group.visible = false
        else
            row.group.visible = true
            row.numberLabel.text = (stepIndex + 1).ToStr()
            row.body.text = text
        end if
    end for
end sub

function FixesHint() as string
    if m.zone = "detail" then return "Up/Down scroll    Left list    Back menu"
    if StepCount() > VisibleSteps() then return "Up/Down choose    Right steps    Left menu    Back"
    return "Up/Down choose    Left menu    Back"
end function

sub PaintCheckout()
    if m.checkoutSummary = invalid then return
    m.checkoutSummary.text = m.summary
    if m.checkoutWhen <> invalid then m.checkoutWhen.text = CheckoutWhenLine()
    if m.checkoutHost <> invalid then m.checkoutHost.text = HostLine()
    if m.checkoutStepRows = invalid then return
    maxScroll = CheckoutStepCount() - VisibleCheckoutSteps()
    if maxScroll < 0 then maxScroll = 0
    if m.checkoutScroll > maxScroll then m.checkoutScroll = maxScroll
    if m.checkoutScroll < 0 then m.checkoutScroll = 0
    start = WindowStart(CheckoutStepCount(), VisibleCheckoutSteps(), m.checkoutScroll)
    last = m.checkoutStepRows.Count() - 1
    for index = 0 to last
        row = m.checkoutStepRows[index]
        text = ListText(m.checkoutSteps, start + index)
        if text = ""
            row.group.visible = false
        else
            row.group.visible = true
            row.numberLabel.text = (start + index + 1).ToStr()
            row.body.text = text
        end if
    end for
end sub

function CheckoutWhenLine() as string
    when = m.checkOut
    if when = invalid or when = "" then when = "11:00 AM"
    dateLabel = ""
    if m.guestStay = "current" then dateLabel = FormatStayDate(m.guestCheckout)
    if dateLabel <> "" then return "Your checkout is " + dateLabel + " at " + when
    return "Checkout time " + when
end function

sub PaintHelp()
    if m.helpName = invalid then return
    m.helpName.text = m.hostName
    if m.helpEmail <> invalid then m.helpEmail.text = m.hostEmail
    if m.helpPhone = invalid then return
    if m.hostPhone = ""
        m.helpPhone.text = ""
        m.helpPhone.visible = false
    else
        m.helpPhone.text = m.hostPhone
        m.helpPhone.visible = true
    end if
    if m.helpNote <> invalid then m.helpNote.text = "Message us in your booking app."
end sub

sub PaintSoon()
    if m.soonTitle = invalid then return
    m.soonTitle.text = RailLabel(m.section)
    if m.soonBody <> invalid then m.soonBody.text = "Coming soon"
    if m.soonMore <> invalid then m.soonMore.text = "Coming in a later update."
end sub

function BundleFromResult(result as object) as object
    return {
        brand: AsText(result.brand),
        place: AsText(result.place),
        domain: AsText(result.domain),
        checkIn: AsText(result.checkIn),
        checkOut: AsText(result.checkOut),
        quietHours: AsText(result.quietHours),
        hostName: AsText(result.hostName),
        hostEmail: AsText(result.hostEmail),
        hostPhone: AsText(result.hostPhone),
        summary: AsText(result.summary),
        guideSource: AsText(result.guideSource),
        guideCode: AsText(result.guideCode),
        guideVersion: AsText(result.guideVersion),
        checkoutSource: AsText(result.checkoutSource),
        checkoutCode: AsText(result.checkoutCode),
        checkoutVersion: AsText(result.checkoutVersion),
        rules: DecodeList(result.rulesJson),
        issues: DecodeList(result.issuesJson),
        checkoutSteps: DecodeList(result.stepsJson)
    }
end function

sub ApplyBundle(bundle as object)
    if bundle = invalid then return
    m.brand = OrText(bundle.brand, "Eaglewood")
    m.place = OrText(bundle.place, "Sunriver, Oregon")
    m.domain = OrText(bundle.domain, "sunrivertownhome.com")
    m.checkIn = OrText(bundle.checkIn, "4:00 PM")
    m.checkOut = OrText(bundle.checkOut, "11:00 AM")
    m.quietHours = AsText(bundle.quietHours)
    m.hostName = AsText(bundle.hostName)
    m.hostEmail = AsText(bundle.hostEmail)
    m.hostPhone = AsText(bundle.hostPhone)
    m.summary = AsText(bundle.summary)
    m.guideSource = OrText(bundle.guideSource, "builtin")
    m.guideCode = OrText(bundle.guideCode, "0")
    m.guideVersion = OrText(bundle.guideVersion, "0")
    m.checkoutSource = OrText(bundle.checkoutSource, "builtin")
    m.checkoutCode = OrText(bundle.checkoutCode, "0")
    m.checkoutVersion = OrText(bundle.checkoutVersion, "0")
    if bundle.rules <> invalid
        m.rules = bundle.rules
    else
        m.rules = []
    end if
    if bundle.issues <> invalid
        m.issues = bundle.issues
    else
        m.issues = []
    end if
    if bundle.checkoutSteps <> invalid
        m.checkoutSteps = bundle.checkoutSteps
    else
        m.checkoutSteps = []
    end if
    if IssueCount() = 0
        m.issueIndex = 0
    else if m.issueIndex >= IssueCount()
        m.issueIndex = 0
    end if
    if m.issueIndex < 0 then m.issueIndex = 0
    PaintAll()
end sub

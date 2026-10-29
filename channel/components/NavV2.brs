' Build 34 navigation (Blake-approved redesign).
'   Quick Fixes  = Roku Settings: rail -> fix list column -> steps (rail slides off).
'   Things to Do = Roku For You: rows of cards per category, rail collapses to icons.
'   Corner ad    = Roku lower-left ad under the expanded rail, rotating from ads.json.
' m.nav2 is "" (rail/other screens), "fxList", "fxSteps", "fyGrid" or "fyItem".
' Layout is a pure function of that state (Nav2Paint), so a slide that is cut
' short by a key press just lands on the painted end state.

function Nav2RailCollapsedW() as integer
    return 112
end function

function Nav2FyLeft(collapsed as boolean) as integer
    if collapsed then return RailX() + Nav2RailCollapsedW() + 40
    return ContentLeft()
end function

function Nav2Right() as integer
    ' Build 35: action-safe right edge (FHD x 1822).
    return 1822
end function

function Nav2CardW() as integer
    ' Build 35: five cards fit inside action-safe on the collapsed grid.
    return 288
end function

function Nav2CardH() as integer
    return 162
end function

function Nav2CardGap() as integer
    return 28
end function

function Nav2CountRight() as integer
    return 1726
end function

function Nav2NameLine() as integer
    return 36
end function

function Nav2NameGap() as integer
    return 8
end function

function Nav2FxListX(deep as boolean) as integer
    if deep then return RailX()
    return RailX() + RailW() + 24
end function

function Nav2FxListW() as integer
    return 600
end function

function Nav2FxTop() as integer
    return 96
end function

function Nav2AdRect() as object
    ' Same width as the expanded rail, ~15% of 1080, equal left and bottom margins.
    ' Build 35 (pixel review): 438x214 at x 96-534, y 758-972, bottom on title-safe.
    return { x: RailX(), y: 758, w: 438, h: 214 }
end function

sub EnsureNav2()
    if m.nav2Built = true then return
    if m.shell = invalid then return
    m.nav2Built = true
    if m.nav2 = invalid then m.nav2 = ""
    m.fyRows = []
    m.fyRow = 0
    m.fyStamp = ""
    m.fxIndex = 0
    m.fxTop = 0
    BuildNav2Rail()
    BuildForYou(m.shell)
    BuildFixColumns(m.shell)
    BuildCornerAd(m.shell)
end sub

' ---------- rail ----------

sub BuildNav2Rail()
    if m.railTop = invalid then return
    m.railBg = m.railTop.getChild(0)
    if m.railBg <> invalid then m.railBg.id = "n2railBg"
    if m.railBrand <> invalid then m.railBrand.id = "n2brand"
    if m.railPlace <> invalid then m.railPlace.id = "n2place"
    if m.railDock <> invalid then m.railDock.id = "n2dock"
    index = 0
    for each row in m.railItems
        icon = CreateObject("roSGNode", "Poster")
        icon.width = 48
        icon.height = 48
        icon.translation = [20, (RailRowHeight() - 48) / 2]
        row.group.appendChild(icon)
        row.icon = icon
        row.label.id = "n2lab" + index.ToStr()
        row.mark.id = "n2mark" + index.ToStr()
        row.bg.id = "n2rowbg" + index.ToStr()
        index = index + 1
    end for
end sub

function Nav2Collapsed() as boolean
    return (m.nav2 = "fyGrid" or m.nav2 = "fyItem")
end function

sub PaintNav2Rail()
    if m.railDock = invalid then return
    collapsed = Nav2Collapsed()
    if m.railChild <> invalid then m.railChild.visible = false
    if m.railTop <> invalid
        m.railTop.visible = true
        m.railTop.translation = [0, 0]
    end if
    if m.nav2 = "fxSteps"
        m.railDock.translation = [0 - RailW() - 60, RailY()]
    else
        m.railDock.translation = [RailX(), RailY()]
    end if
    if m.railBg <> invalid
        m.railBg.width = RailW()
        if collapsed then m.railBg.width = Nav2RailCollapsedW()
    end if
    fade = 1.0
    if collapsed then fade = 0.0
    if m.railBrand <> invalid then m.railBrand.opacity = fade
    if m.railPlace <> invalid then m.railPlace.opacity = fade
    menu = TopMenu()
    last = m.railItems.Count() - 1
    for index = 0 to last
        row = m.railItems[index]
        section = ""
        if index < menu.Count() then section = menu[index]
        if row.icon <> invalid
            row.icon.uri = Nav2IconUri(section)
            row.icon.blendColor = "0xFFFFFFFF"
            if row.bg.color = AmberColor() then row.icon.blendColor = InkOnAmber()
        end if
        row.label.translation = [84, 0]
        row.label.opacity = fade
        row.mark.opacity = fade
        row.mark.translation = [84 + RailLabelWidth() + 4, 0]
        row.bg.width = RailW() - 24
        if collapsed then row.bg.width = Nav2RailCollapsedW() - 24
        if section = "fixes" and (m.nav2 = "fxList")
            ' Settings pattern: the parent row reads "< Quick Fixes" and loses its highlight.
            row.label.text = "<  " + RailLabel("fixes")
            row.label.width = CheckoutLabelWidth()
            row.mark.text = ""
            row.bg.color = "0x00000000"
            row.label.color = InkColor()
            if row.icon <> invalid then row.icon.blendColor = "0xFFFFFFFF"
        end if
        if collapsed and section = "todo"
            row.bg.color = "0x3A4A66FF"
        end if
    end for
end sub

function Nav2IconUri(section as string) as string
    known = { home: 1, wifi: 1, todo: 1, rules: 1, fixes: 1, book: 1, checkout: 1 }
    if known.DoesExist(section) then return "pkg:/images/icon-" + section + ".png"
    item = invalid
    for each entry in MenuItems()
        if MenuSection(entry) = section then item = entry
    end for
    if item <> invalid
        kind = AsText(item.Lookup("type"))
        mapped = SectionForMenuType(kind)
        if known.DoesExist(mapped) then return "pkg:/images/icon-" + mapped + ".png"
    end if
    return ""
end function

' ---------- Things to Do (For You) ----------

sub BuildForYou(parent as object)
    pane = CreateObject("roSGNode", "Group")
    pane.id = "n2fy"
    pane.visible = false
    parent.appendChild(pane)
    m.fyPane = pane
    m.fyTitle = AddLabel(pane, RailLabel("todo"), "font:LargeBoldSystemFont", InkColor(), 0, 0, 900, 68)
    SetFontSize(m.fyTitle, PageH1Size())
    m.fyTitle.maxLines = 1
    m.fySub = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), 0, 72, 1100, 40)
    SetFontSize(m.fySub, 28)
    m.fySub.maxLines = 1
    m.fyCount = AddLabel(pane, "", "font:SmallBoldSystemFont", "0xF4EFE3FF", 0, 24, 240, 40)
    SetFontSize(m.fyCount, 26)
    m.fyCount.horizAlign = "right"
    m.fyCount.maxLines = 1
    m.fyBody = CreateObject("roSGNode", "Group")
    pane.appendChild(m.fyBody)
    ' Focused-card details, drawn under the focused card.
    m.fyFocus = CreateObject("roSGNode", "Group")
    m.fyFocus.visible = false
    pane.appendChild(m.fyFocus)
    m.fyName = AddLabel(m.fyFocus, "", "font:SmallBoldSystemFont", "0xFFFFFFFF", 0, 0, 640, 86)
    SetFontSize(m.fyName, 30)
    m.fyName.vertAlign = "top"
    m.fyName.maxLines = 2
    m.fyMeta = AddLabel(m.fyFocus, "", "font:SmallSystemFont", "0xC9D1E0FF", 0, 0, 640, 76)
    SetFontSize(m.fyMeta, 24)
    m.fyMeta.vertAlign = "top"
    m.fyMeta.maxLines = 2
end sub

function FyStamp() as string
    token = 0
    if m.activitiesToken <> invalid then token = m.activitiesToken
    count = 0
    if IsList(m.activities) then count = m.activities.Count()
    return token.ToStr() + "|" + count.ToStr() + "|" + CurrentSeason()
end function

sub EnsureFyRows()
    stamp = FyStamp()
    if stamp = m.fyStamp and m.fyRows.Count() > 0 then return
    m.fyStamp = stamp
    ' Clear the old row nodes.
    while m.fyBody.getChildCount() > 0
        m.fyBody.removeChildIndex(0)
    end while
    m.fyRows = []
    for each id in TodoMenu()
        items = SortActivities(ActivitiesForScreen(m.activities, id), ScreenSortSeason(id, CurrentSeason()))
        if items.Count() > 0
            group = CreateObject("roSGNode", "Group")
            m.fyBody.appendChild(group)
            label = AddLabel(group, RailLabel(id), "font:MediumBoldSystemFont", InkColor(), 0, 0, 800, 44)
            SetFontSize(label, 32)
            label.maxLines = 1
            cards = []
            for index = 0 to items.Count() - 1
                cards.Push(MakeFyCard(group, index))
            end for
            m.fyRows.Push({ id: id, items: items, group: group, label: label, cards: cards, col: 0, first: 0 })
        end if
    end for
    if m.fyRow >= m.fyRows.Count() then m.fyRow = 0
end sub

function MakeFyCard(parent as object, index as integer) as object
    group = CreateObject("roSGNode", "Group")
    group.scaleRotateCenter = [Nav2CardW() / 2, Nav2CardH() / 2]
    parent.appendChild(group)
    ring = AddRect(group, "0xFFFFFFFF", -6, -6, Nav2CardW() + 12, Nav2CardH() + 12)
    ring.visible = false
    AddRect(group, "0x243044FF", 0, 0, Nav2CardW(), Nav2CardH())
    photo = CreateObject("roSGNode", "Poster")
    photo.width = Nav2CardW()
    photo.height = Nav2CardH()
    photo.loadWidth = Nav2CardW()
    photo.loadHeight = Nav2CardH()
    photo.loadDisplayMode = "scaleToZoom"
    photo.failedBitmapUri = PlaceholderPoster()
    photo.loadingBitmapUri = PlaceholderPoster()
    group.appendChild(photo)
    return { group: group, ring: ring, photo: photo }
end function

sub PaintForYou()
    EnsureFyRows()
    grid = (m.nav2 = "fyGrid")
    left = Nav2FyLeft(grid)
    width = Nav2Right() - left
    m.fyPane.translation = [left, 0]
    m.fyTitle.translation = [0, ContentTop()]
    m.fySub.translation = [0, ContentTop() + 72]
    m.fySub.text = FySubtitle()
    ' Build 35: right-aligned so the counter ends on title-safe x 1726.
    m.fyCount.translation = [Nav2CountRight() - left - 240, ContentTop() + 20]
    pitch = Nav2CardW() + Nav2CardGap()
    perRow = (width + Nav2CardGap()) \ pitch
    if perRow < 1 then perRow = 1
    y = ContentTop() + 136
    if grid then y = ContentTop() + 136
    m.fyFocus.visible = false
    m.fyCount.text = ""
    for r = 0 to m.fyRows.Count() - 1
        y = PaintFyRow(r, y, grid, width, pitch, perRow)
    end for
    if grid
        ' Title rows give way to the focused row once it moves down.
        m.fyTitle.visible = (m.fyRow = 0)
        m.fySub.visible = (m.fyRow = 0)
        if m.fyRow > 0
            m.fyBody.translation = [0, -100]
            m.fyFocus.translation = [m.fyFocus.translation[0], m.fyFocus.translation[1] - 100]
        else
            m.fyBody.translation = [0, 0]
        end if
    else
        m.fyTitle.visible = true
        m.fySub.visible = true
        m.fyBody.translation = [0, 0]
    end if
end sub

function PaintFyRow(r as integer, y as integer, grid as boolean, width as integer, pitch as integer, perRow as integer) as integer
    row = m.fyRows[r]
    focusedRow = grid and r = m.fyRow
    ' Roku For You: the focused row rises to the top slot; rows above leave.
    above = grid and r < m.fyRow
    row.group.visible = not above
    if above then return y
    row.group.translation = [0, y]
    ' Keep the focused card in view with one card of look-ahead.
    if row.col < row.first then row.first = row.col
    if row.col > row.first + perRow - 2 then row.first = row.col - perRow + 2
    if row.first < 0 then row.first = 0
    for c = 0 to row.cards.Count() - 1
        card = row.cards[c]
        slot = c - row.first
        card.group.translation = [slot * pitch, 52]
        ' Build 35: only whole cards, so the row ends inside action-safe.
        card.group.visible = (slot >= 0 and slot * pitch + Nav2CardW() <= width)
        focused = focusedRow and c = row.col
        card.ring.visible = focused
        card.group.scaleRotateCenter = [Nav2CardW() / 2, Nav2CardH() / 2]
        if focused
            card.group.scale = [1.08, 1.08]
        else
            card.group.scale = [1.0, 1.0]
        end if
        uri = ""
        if card.group.visible
            uri = ItemText(row.items[c], "poster")
            if uri = "" then uri = PlaceholderPoster()
        end if
        if card.photo.uri <> uri then card.photo.uri = uri
    end for
    y = y + 52 + Nav2CardH() + 44
    if focusedRow
        item = row.items[row.col]
        slot = row.col - row.first
        x = slot * pitch - 6
        detailW = 640
        if x + detailW > width then x = width - detailW
        if x < 0 then x = 0
        m.fyFocus.translation = [x, y - 44 + 26]
        m.fyName.text = JoinLines(BreakLines(ItemText(item, "name"), detailW, 30))
        nameLines = BreakLines(ItemText(item, "name"), detailW, 30).Count()
        if nameLines < 1 then nameLines = 1
        if nameLines > 2 then nameLines = 2
        ' Build 35: 30px bold title, 24px meta, 8px between them.
        m.fyMeta.translation = [0, nameLines * Nav2NameLine() + Nav2NameGap()]
        m.fyMeta.text = JoinLines(BreakLines(FyMetaText(item), detailW, 24))
        m.fyFocus.visible = true
        m.fyCount.text = (row.col + 1).ToStr() + " of " + row.items.Count().ToStr()
        y = y + 26 + nameLines * Nav2NameLine() + Nav2NameGap() + 40
    end if
    return y
end function

function FySubtitle() as string
    return SeasonSubheadFor("todo", CurrentSeason())
end function

function FyMetaText(item as object) as string
    bits = []
    distance = ItemText(item, "distance")
    season = ItemText(item, "seasonLabel")
    if distance <> "" then bits.Push(distance)
    if season <> "" then bits.Push(season)
    return JoinBits(bits)
end function

function FyMoveRow(direction as integer) as boolean
    target = m.fyRow + direction
    if target < 0 or target >= m.fyRows.Count() then return true
    m.fyRow = target
    Nav2Paint()
    return true
end function

function FyMoveCol(direction as integer) as boolean
    if m.fyRows.Count() < 1 then return Nav2ToRail("todo")
    row = m.fyRows[m.fyRow]
    target = row.col + direction
    if target < 0 then return Nav2ToRail("todo")
    if target >= row.items.Count() then return true
    row.col = target
    Nav2Paint()
    return true
end function

function FyOpenItem() as boolean
    if m.fyRows.Count() < 1 then return true
    row = m.fyRows[m.fyRow]
    m.nav2 = "fyItem"
    m.section = row.id
    m.boundSection = row.id
    m.activityStamp = ""
    EnsureActivityGrid()
    m.cardIndex = row.col
    if CardCount() > row.col
        ' Same sort as the row, so the index matches; check the id anyway.
        if ItemText(m.sortedCards[row.col], "id") <> ItemText(row.items[row.col], "id")
            m.sortedCards = row.items
        end if
    else
        m.sortedCards = row.items
    end if
    print "Eaglewood: nav2 fy open row="; row.id; " col="; row.col
    return OpenActivityDetail()
end function

function FyCloseItem() as boolean
    m.nav2 = "fyGrid"
    m.zone = "fy"
    m.section = "todo"
    m.stepScroll = 0
    ShowSection(m.section)
    PaintAll()
    print "Eaglewood: screen=todo zone=fy"
    return true
end function

' ---------- Quick Fixes (Settings) ----------

sub BuildFixColumns(parent as object)
    pane = CreateObject("roSGNode", "Group")
    pane.id = "n2fx"
    pane.visible = false
    parent.appendChild(pane)
    m.fxPane = pane
    m.fxList = CreateObject("roSGNode", "Group")
    m.fxList.id = "n2fxList"
    pane.appendChild(m.fxList)
    m.fxListBg = AddRect(m.fxList, GlassColor(), 0, 0, Nav2FxListW(), 1080 - Nav2FxTop() - 64)
    m.fxHead = AddLabel(m.fxList, RailLabel("fixes"), "font:MediumBoldSystemFont", AmberColor(), 32, 16, Nav2FxListW() - 64, 48)
    SetFontSize(m.fxHead, 32)
    m.fxHead.maxLines = 1
    m.fxRows = []
    for index = 0 to 9
        group = CreateObject("roSGNode", "Group")
        m.fxList.appendChild(group)
        bg = AddRect(group, "0x00000000", 12, 0, Nav2FxListW() - 24, 60)
        crumb = AddLabel(group, "<", "font:SmallBoldSystemFont", InkColor(), 18, 0, 28, 60)
        SetFontSize(crumb, 28)
        label = AddLabel(group, "", "font:SmallSystemFont", InkColor(), 52, 0, FxLabelW(), 60)
        SetFontSize(label, 26)
        label.vertAlign = "center"
        label.maxLines = 4
        mark = AddLabel(group, ">", "font:SmallBoldSystemFont", AmberColor(), Nav2FxListW() - 56, 0, 28, 60)
        SetFontSize(mark, 28)
        m.fxRows.Push({ group: group, bg: bg, crumb: crumb, label: label, mark: mark })
    end for
    m.fxMore = CreateObject("roSGNode", "Poster")
    m.fxMore.uri = "pkg:/images/chevron-down.png"
    m.fxMore.width = 32
    m.fxMore.height = 20
    m.fxMore.visible = false
    m.fxList.appendChild(m.fxMore)
    m.fxScroll = CreateObject("roSGNode", "DetailScroll")
    m.fxScroll.id = "n2fxScroll"
    pane.appendChild(m.fxScroll)
end sub

function FxLabelW() as integer
    return Nav2FxListW() - 52 - 64
end function

function FxRowH(text as string) as integer
    lines = BreakLines(text, FxLabelW(), 26).Count()
    if lines < 1 then lines = 1
    if lines > 4 then lines = 4
    return lines * 36 + 26
end function

function FxTitle(index as integer) as string
    issues = FixIssues()
    if index < 0 or index >= issues.Count() then return ""
    return AsText(issues[index].Lookup("issue")).Trim()
end function

sub PaintFixColumns()
    deep = (m.nav2 = "fxSteps")
    listFocus = (m.nav2 = "fxList")
    m.fxList.translation = [Nav2FxListX(deep), Nav2FxTop()]
    count = IssueCount()
    if m.fxIndex >= count then m.fxIndex = 0
    m.issueIndex = m.fxIndex
    areaTop = 84
    areaH = 1080 - Nav2FxTop() - 64 - areaTop - 40
    ' Window: the least scroll that keeps the focused row fully visible.
    if m.fxIndex < m.fxTop then m.fxTop = m.fxIndex
    while m.fxTop < m.fxIndex and FxSpan(m.fxTop, m.fxIndex) > areaH
        m.fxTop = m.fxTop + 1
    end while
    y = areaTop
    slot = 0
    index = m.fxTop
    more = false
    while slot < m.fxRows.Count()
        row = m.fxRows[slot]
        if index >= count
            row.group.visible = false
        else
            text = FxTitle(index)
            h = FxRowH(text)
            if y + h > areaTop + areaH
                row.group.visible = false
                more = true
            else
                row.group.visible = true
                row.group.translation = [0, y]
                row.label.text = JoinLines(BreakLines(text, FxLabelW(), 26))
                row.label.height = h
                row.bg.height = h - 6
                row.mark.height = h
                row.crumb.height = h
                row.mark.visible = (StepCountFor(index) > 0)
                focused = (index = m.fxIndex)
                row.crumb.visible = deep and focused
                if listFocus and focused
                    row.bg.color = AmberColor()
                    row.label.color = InkOnAmber()
                    row.mark.color = InkOnAmber()
                else if deep and focused
                    row.bg.color = "0x3A4A66FF"
                    row.label.color = InkColor()
                    row.mark.color = InkColor()
                else
                    row.bg.color = "0x00000000"
                    row.label.color = InkColor()
                    row.mark.color = AmberColor()
                end if
                y = y + h
            end if
        end if
        index = index + 1
        slot = slot + 1
    end while
    if index < count then more = true
    m.fxMore.visible = more
    m.fxMore.translation = [(Nav2FxListW() - 32) / 2, areaTop + areaH + 8]
    ' Steps: a preview beside the list, or the whole right side once opened.
    showSteps = (listFocus or deep) and count > 0
    m.fxScroll.visible = showSteps
    if showSteps
        x = Nav2FxListX(false) + Nav2FxListW() + 24
        if deep then x = Nav2FxListX(true) + Nav2FxListW() + 24
        m.fxScroll.fontSize = 28
        m.fxScroll.pitch = 42
        m.fxScroll.padding = 32
        m.fxScroll.translation = [x, Nav2FxTop()]
        m.fxScroll.frameWidth = Nav2Right() - x
        m.fxScroll.frameHeight = 1080 - Nav2FxTop() - 64
        key = m.fxIndex.ToStr() + "|" + m.fxScroll.frameWidth.ToStr()
        if m.fxScrollKey <> key
            m.fxScrollKey = key
            m.fxScroll.heading = FxTitle(m.fxIndex)
            m.fxScroll.body = FixStepsText()
        end if
        if deep
            m.fxScroll.hint = "Up/Down|Scroll|Left|Fixes list"
        else
            m.fxScroll.hint = "Up/Down|Next fix|Right|Open steps"
        end if
        if m.stepScroll > m.fxScroll.maxOffset then m.stepScroll = m.fxScroll.maxOffset
        if m.stepScroll < 0 then m.stepScroll = 0
        m.fxScroll.offset = m.stepScroll
    end if
end sub

function FxSpan(first as integer, last as integer) as integer
    total = 0
    for index = first to last
        total = total + FxRowH(FxTitle(index))
    end for
    return total
end function

function StepCountFor(index as integer) as integer
    issues = FixIssues()
    if index < 0 or index >= issues.Count() then return 0
    steps = issues[index].Lookup("steps")
    if not IsList(steps) then return 0
    return steps.Count()
end function

' ---------- corner ad ----------

sub BuildCornerAd(parent as object)
    rect = Nav2AdRect()
    group = CreateObject("roSGNode", "Group")
    group.id = "n2ad"
    group.translation = [rect.x, rect.y]
    parent.appendChild(group)
    m.adGroup = group
    shadow = CreateObject("roSGNode", "Poster")
    shadow.uri = "pkg:/images/ad-shadow.png"
    shadow.translation = [-24, -24]
    shadow.width = rect.w + 48
    shadow.height = rect.h + 48
    group.appendChild(shadow)
    m.adA = MakeAdPoster(group, rect, "n2adA")
    m.adB = MakeAdPoster(group, rect, "n2adB")
    m.adB.opacity = 0.0
    m.ads = LoadAds()
    m.adIndex = 0
    m.adFront = m.adA
    m.adFrontB = false
    if m.ads.Count() > 0 then m.adA.uri = m.ads[0].image
    timer = CreateObject("roSGNode", "Timer")
    timer.repeat = true
    timer.duration = m.adSeconds
    timer.observeField("fire", "onAdTimer")
    m.top.appendChild(timer)
    m.adTimer = timer
    if m.ads.Count() > 1 then timer.control = "start"
    print "Eaglewood: ad list count="; m.ads.Count(); " rotate="; m.adSeconds
end sub

function MakeAdPoster(group as object, rect as object, id as string) as object
    poster = CreateObject("roSGNode", "Poster")
    poster.id = id
    poster.width = rect.w
    poster.height = rect.h
    poster.loadWidth = rect.w * 2
    poster.loadHeight = rect.h * 2
    poster.loadDisplayMode = "scaleToFit"
    group.appendChild(poster)
    return poster
end function

function LoadAds() as object
    m.adSeconds = 50
    m.adFade = 1.0
    out = []
    parsed = ParseJson(ReadAsciiFile("pkg:/data/ads.json"))
    if parsed = invalid or type(parsed) <> "roAssociativeArray" then return out
    seconds = parsed.Lookup("rotateSeconds")
    if seconds <> invalid and seconds >= 10 then m.adSeconds = seconds
    fade = parsed.Lookup("fadeSeconds")
    if fade <> invalid and fade > 0 then m.adFade = fade
    list = parsed.Lookup("ads")
    if not IsList(list) then return out
    for each entry in list
        if IsAssoc(entry)
            image = AsText(entry.Lookup("image"))
            if image <> "" then out.Push({ id: AsText(entry.Lookup("id")), image: image })
        end if
    end for
    return out
end function

sub onAdTimer()
    AdvanceAd()
end sub

sub AdvanceAd()
    if m.ads = invalid or m.ads.Count() < 2 then return
    m.adIndex = (m.adIndex + 1) mod m.ads.Count()
    ' SceneGraph nodes cannot be compared with "=", so track the front by flag.
    back = m.adB
    front = m.adA
    if m.adFrontB = true
        back = m.adA
        front = m.adB
    end if
    back.uri = m.ads[m.adIndex].image
    m.adFront = back
    m.adFrontB = not (m.adFrontB = true)
    print "Eaglewood: ad show id="; m.ads[m.adIndex].id; " index="; m.adIndex
    if SimulatorRun() or m.emuReplay = true
        back.opacity = 1.0
        front.opacity = 0.0
        return
    end if
    anim = CreateObject("roSGNode", "Animation")
    anim.duration = m.adFade
    anim.repeat = false
    anim.easeFunction = "linear"
    fadeIn = CreateObject("roSGNode", "FloatFieldInterpolator")
    fadeIn.key = [0.0, 1.0]
    fadeIn.keyValue = [0.0, 1.0]
    fadeIn.fieldToInterp = back.id + ".opacity"
    fadeOut = CreateObject("roSGNode", "FloatFieldInterpolator")
    fadeOut.key = [0.0, 1.0]
    fadeOut.keyValue = [1.0, 0.0]
    fadeOut.fieldToInterp = front.id + ".opacity"
    anim.appendChild(fadeIn)
    anim.appendChild(fadeOut)
    if m.adAnim <> invalid
        m.adAnim.control = "stop"
        m.adGroup.removeChild(m.adAnim)
    end if
    m.adAnim = anim
    m.adGroup.appendChild(anim)
    anim.control = "start"
end sub

sub PaintAd()
    if m.adGroup = invalid then return
    ' Shown wherever the rail is expanded; hidden when it collapses or slides off.
    show = true
    if Nav2Collapsed() then show = false
    if m.nav2 = "fxSteps" then show = false
    ' Build 35: Book Direct already shows the site QR.
    if m.section = "book" then show = false
    if m.ads = invalid or m.ads.Count() < 1 then show = false
    if m.adGroup.visible <> show then print "Eaglewood: ad visible="; show; " nav="; m.nav2; " section="; m.section
    m.adGroup.visible = show
    ' Last shell child, above every pane.
    if m.shell <> invalid
        m.shell.removeChild(m.adGroup)
        m.shell.appendChild(m.adGroup)
    end if
end sub

' ---------- paint + keys ----------

sub Nav2Paint()
    if m.shell = invalid then return
    EnsureNav2()
    if m.nav2Built <> true then return
    onTodo = (m.section = "todo")
    fyItem = (m.nav2 = "fyItem")
    onFix = (m.section = "fixes")
    if onTodo
        if m.activityPane <> invalid then m.activityPane.visible = false
        if m.detailPane <> invalid then m.detailPane.visible = false
        if m.detailScroll <> invalid then m.detailScroll.visible = false
        ReleaseCardImages()
    end if
    m.fyPane.visible = onTodo
    if onTodo then PaintForYou()
    if onFix
        if m.fixesPage <> invalid then m.fixesPage.visible = false
        if m.fixesPane <> invalid then m.fixesPane.visible = false
        if m.detailScroll <> invalid then m.detailScroll.visible = false
    end if
    m.fxPane.visible = onFix
    if onFix then PaintFixColumns()
    if m.footer <> invalid and (onTodo or onFix or fyItem) then m.footer.visible = false
    if m.offline <> invalid and Nav2Collapsed() then m.offline.visible = false
    PaintNav2Rail()
    PaintAd()
end sub

' Records the animated fields, repaints, then tweens from the old values.
sub Nav2Transition(nextNav as string)
    before = Nav2Snapshot()
    m.nav2 = nextNav
    Nav2Paint()
    after = Nav2Snapshot()
    Nav2Tween(before, after)
end sub

function Nav2Tracked() as object
    list = [
        { id: "n2dock", field: "translation" },
        { id: "n2railBg", field: "width" },
        { id: "n2brand", field: "opacity" },
        { id: "n2place", field: "opacity" },
        { id: "n2fy", field: "translation" },
        { id: "n2fxList", field: "translation" },
        { id: "n2fxScroll", field: "translation" }
    ]
    for index = 0 to m.railItems.Count() - 1
        list.Push({ id: "n2lab" + index.ToStr(), field: "opacity" })
        list.Push({ id: "n2mark" + index.ToStr(), field: "opacity" })
        list.Push({ id: "n2rowbg" + index.ToStr(), field: "width" })
    end for
    return list
end function

function Nav2Snapshot() as object
    out = {}
    if m.shell = invalid then return out
    for each entry in Nav2Tracked()
        node = m.top.findNode(entry.id)
        if node <> invalid then out[entry.id + "." + entry.field] = node.getField(entry.field)
    end for
    return out
end function

sub Nav2Tween(before as object, after as object)
    Nav2StopTween()
    if SimulatorRun() or m.emuReplay = true then return
    anim = CreateObject("roSGNode", "Animation")
    if anim = invalid then return
    anim.duration = 0.35
    anim.easeFunction = "outCubic"
    anim.repeat = false
    added = 0
    for each key in after
        old = before.Lookup(key)
        now = after.Lookup(key)
        if old <> invalid and now <> invalid
            kind = type(now)
            interp = invalid
            if kind = "roArray"
                if old[0] <> now[0] or old[1] <> now[1] then interp = CreateObject("roSGNode", "Vector2DFieldInterpolator")
            else
                if old <> now then interp = CreateObject("roSGNode", "FloatFieldInterpolator")
            end if
            if interp <> invalid
                interp.key = [0.0, 1.0]
                interp.keyValue = [old, now]
                interp.fieldToInterp = key
                anim.appendChild(interp)
                added = added + 1
            end if
        end if
    end for
    if added = 0 then return
    m.nav2Anim = anim
    m.top.appendChild(anim)
    anim.control = "start"
end sub

' A key during a slide ends it on the painted state (same rule as build 32).
sub Nav2StopTween()
    if m.nav2Anim = invalid then return
    m.nav2Anim.control = "stop"
    m.top.removeChild(m.nav2Anim)
    m.nav2Anim = invalid
    Nav2Paint()
end sub

function Nav2ToRail(section as string) as boolean
    m.zone = "rail"
    m.section = section
    m.menuDepth = "top"
    m.railIndex = MenuIndex(TopMenu(), section)
    print "Eaglewood: screen="; section; " zone=rail"
    ' Clear the nav state before the legacy paint so the rail row gets its
    ' expanded (gold) focus, then tween from the collapsed snapshot.
    before = Nav2Snapshot()
    m.nav2 = ""
    ShowSection(m.section)
    PaintAll()
    Nav2Tween(before, Nav2Snapshot())
    return true
end function

function Nav2EnterFy(rowId as string) as boolean
    EnsureNav2()
    m.menuDepth = "top"
    m.section = "todo"
    m.zone = "fy"
    m.railIndex = MenuIndex(TopMenu(), "todo")
    EnsureFyRows()
    if rowId <> ""
        for r = 0 to m.fyRows.Count() - 1
            if m.fyRows[r].id = rowId then m.fyRow = r
        end for
    end if
    print "Eaglewood: screen=todo zone=fy row="; m.fyRow
    ShowSection(m.section)
    PaintAll()
    Nav2Transition("fyGrid")
    return true
end function

function Nav2EnterFx() as boolean
    EnsureNav2()
    if IssueCount() < 1 then return true
    m.menuDepth = "top"
    m.section = "fixes"
    m.zone = "fxlist"
    m.railIndex = MenuIndex(TopMenu(), "fixes")
    m.stepScroll = 0
    print "Eaglewood: screen=fixes zone=fxlist"
    ShowSection(m.section)
    PaintAll()
    Nav2Transition("fxList")
    return true
end function

' Returns invalid when the old router should handle the key.
function Nav2Key(key as string) as object
    EnsureNav2()
    if m.nav2Built <> true then return invalid
    Nav2StopTween()
    nav = m.nav2
    if nav = ""
        if m.zone = "rail" and MenuDepth() = "top"
            if m.section = "todo" and (key = "right" or key = "OK") then return Nav2EnterFy("")
            if m.section = "fixes" and (key = "right" or key = "OK") then return Nav2EnterFx()
        end if
        return invalid
    end if
    if nav = "fyGrid"
        if key = "left" then return FyMoveCol(-1)
        if key = "right" then return FyMoveCol(1)
        if key = "up" then return FyMoveRow(-1)
        if key = "down" then return FyMoveRow(1)
        if key = "OK" then return FyOpenItem()
        if key = "back" then return Nav2ToRail("todo")
        return true
    end if
    if nav = "fyItem"
        if key = "back" or key = "left" then return FyCloseItem()
        if key = "up" then return MoveBodyScroll(-1)
        if key = "down" then return MoveBodyScroll(1)
        return true
    end if
    if nav = "fxList"
        if key = "up" or key = "down"
            delta = 1
            if key = "up" then delta = -1
            target = m.fxIndex + delta
            if target >= 0 and target < IssueCount()
                m.fxIndex = target
                m.stepScroll = 0
                Nav2Paint()
            end if
            return true
        end if
        if key = "right" or key = "OK"
            if StepCountFor(m.fxIndex) < 1 then return true
            m.zone = "fxsteps"
            m.stepScroll = 0
            print "Eaglewood: screen=fixes zone=fxsteps"
            Nav2Transition("fxSteps")
            return true
        end if
        if key = "left" or key = "back" then return Nav2ToRail("fixes")
        return true
    end if
    if nav = "fxSteps"
        if key = "up" or key = "down"
            delta = 1
            if key = "up" then delta = -1
            target = m.stepScroll + delta
            if m.fxScroll <> invalid and target >= 0 and target <= m.fxScroll.maxOffset
                m.stepScroll = target
                m.fxScroll.offset = target
            end if
            return true
        end if
        if key = "left" or key = "back"
            m.zone = "fxlist"
            print "Eaglewood: screen=fixes zone=fxlist"
            Nav2Transition("fxList")
            return true
        end if
        return true
    end if
    return invalid
end function

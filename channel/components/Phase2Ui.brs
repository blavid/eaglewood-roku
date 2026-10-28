' Book Direct, Wi-Fi, activity grids, and the corner badge.
' The scene keeps the remote. MarkupGrid is not focusable; it only virtualizes the cards.
' Card nodes are named from sourceIndex. Two activities may share an id.

function DisplayDomain() as string
    domain = "sunrivertownhome.com"
    return domain
end function

function ComingSoonWifi() as string
    return "Wi-Fi details coming soon"
end function

sub BuildPhase2(parent as object)
    BuildHomePrompt(m.homePane)
    BuildBadge(parent)
    m.bookPane = BuildBookPane(parent)
    m.wifiPane = BuildWifiPane(parent)
    m.activityPane = BuildActivityPane(parent)
    m.detailPane = BuildDetailPane(parent)
    m.activityStamp = ""
    m.boundSection = ""
    m.jumpedIndex = -1
    m.badgeReady = false
    m.bookPhotoTried = false
    m.bookQrTried = false
    m.detailPhotoTried = false
    m.detailQrFailed = false
    m.wifiJsonCode = 0
    m.wifiPngCode = 0
    m.wifiPngBit = 0
    m.wifiPngColor = -1
    m.wifiPngInterlace = 0
    m.wifiIndexed = "no"
    m.wifiRemoteSafe = ""
end sub

sub BuildHomePrompt(parent as object)
    if parent = invalid then return
    group = CreateObject("roSGNode", "Group")
    group.translation = [ContentLeft(), 312]
    AddRect(group, "0x00000055", 8, 8, 1132, 156)
    m.promptOuter = AddRect(group, AmberColor(), 0, 0, 1132, 156)
    m.promptInner = AddRect(group, "0xF4EFE3FF", 0, 0, 1132, 156)
    pine = CreateObject("roSGNode", "Poster")
    pine.uri = "pkg:/images/decor-pine.png"
    pine.width = 44
    pine.height = 32
    pine.loadWidth = 72
    pine.loadHeight = 48
    pine.translation = [18, 62]
    group.appendChild(pine)
    m.promptTitle = AddLabel(group, "Book your next stay direct and save!", "font:SmallBoldSystemFont", "0x1B4D38FF", 74, 12, 960, 96)
    m.promptTitle.horizAlign = "left"
    m.promptTitle.vertAlign = "center"
    m.promptTitle.maxLines = 2
    m.promptSub = AddLabel(group, "", "font:SmallestSystemFont", "0x3E5348FF", 74, 108, 960, 40)
    m.promptSub.horizAlign = "left"
    m.promptSub.maxLines = 2
    arrow = AddRect(group, AmberColor(), 1064, 58, 40, 40)
    arrowText = AddLabel(group, ">", "font:SmallBoldSystemFont", InkOnAmber(), 1064, 58, 40, 40)
    arrowText.horizAlign = "center"
    parent.appendChild(group)
    m.promptGroup = group
end sub

sub BuildBadge(parent as object)
    frame = BadgeFrame()
    group = CreateObject("roSGNode", "Group")
    group.translation = [1304, 832]
    group.visible = false
    card = AddRect(group, "0xFFFFFFF2", 0, 0, frame.w, frame.h)
    card.visible = false
    m.badgeCard = card
    m.badgeMark = AddRect(group, QrMarkColor(), 0, 0, frame.w, frame.h)
    m.badgeMark.visible = false
    m.badgePoster = CreateObject("roSGNode", "Poster")
    m.badgePoster.id = "badgeQr"
    m.badgePoster.focusable = false
    m.badgePoster.translation = [196, 8]
    m.badgePoster.width = 128
    m.badgePoster.height = 128
    m.badgePoster.loadWidth = 256
    m.badgePoster.loadHeight = 256
    m.badgePoster.loadDisplayMode = "scaleToFit"
    m.badgePoster.visible = false
    m.badgePoster.observeField("loadStatus", "onBadgeStatus")
    m.badgeMissing = AddLabel(group, "", "font:SmallestSystemFont", "0x1C1408FF", 12, 78, 196, 64)
    m.badgeMissing.horizAlign = "center"
    m.badgeMissing.maxLines = 3
    group.appendChild(m.badgePoster)
    m.badgeDomain = AddLabel(group, DisplayDomain(), QrCaptionFont(), QrCaptionColor(), frame.captionX, frame.captionY, frame.captionW, frame.captionH)
    m.badgeDomain.color = BadgeCaptionColor()
    m.badgeDomain.horizAlign = "center"
    m.badgeDomain.vertAlign = "center"
    m.badgeDomain.maxLines = 1
    m.badgeDomain.visible = false
    parent.appendChild(group)
    m.badgeGroup = group
    m.badgeHint = AddLabel(parent, "", "font:SmallSystemFont", MuteColor(), 980, 800, 500, 28)
    m.badgeHint.horizAlign = "right"
    m.badgeHint.visible = false
    m.badgeUri = ""
    m.badgeRemote = ""
    m.badgeFile = ""
    m.badgeFailed = false
end sub

function BuildBookPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    panel = AddRect(pane, BookPanelColor(), 540, 36, 1320, 1000)
    m.bookLines = []
    for index = 0 to 2
        label = AddLabel(pane, "", "font:MediumBoldSystemFont", BookInkColor(), 588, 64 + (index * 44), 1100, 44)
        label.horizAlign = "left"
        m.bookLines.Push(label)
    end for
    banner = AddRect(pane, BookBannerColor(), 588, 214, 620, 64)
    bannerText = AddLabel(pane, "", "font:MediumBoldSystemFont", InkOnAmber(), 588, 214, 620, 64)
    bannerText.horizAlign = "center"
    m.bookBanner = bannerText
    m.bookPhoto = CreateObject("roSGNode", "Poster")
    m.bookPhoto.translation = [588, 292]
    m.bookPhoto.width = 680
    m.bookPhoto.height = 200
    m.bookPhoto.loadWidth = 680
    m.bookPhoto.loadHeight = 360
    m.bookPhoto.loadDisplayMode = "scaleToZoom"
    m.bookPhoto.failedBitmapUri = PlaceholderPoster()
    pane.appendChild(m.bookPhoto)
    m.bookPhoto.observeField("loadStatus", "onBookPhotoStatus")
    slot = BookQrSlot()
    qrCard = AddRect(pane, BookCardColor(), slot.cardX, slot.cardY, slot.cardW, slot.cardH)
    qrCard.visible = false
    m.bookQrCard = qrCard
    m.bookQrMark = AddRect(pane, QrMarkColor(), slot.cardX, slot.cardY, slot.cardW, slot.cardH)
    m.bookQrMark.visible = false
    m.bookQrPlate = AddRect(pane, "0xFFFFFFF2", slot.qrX, slot.qrY, slot.qrW, slot.qrH)
    m.bookQrPlate.visible = false
    m.bookQr = CreateObject("roSGNode", "Poster")
    m.bookQr.id = "bookQr"
    m.bookQr.focusable = false
    m.bookQr.translation = [slot.qrX, slot.qrY]
    m.bookQr.width = slot.qrW
    m.bookQr.height = slot.qrH
    m.bookQr.loadWidth = slot.qrW
    m.bookQr.loadHeight = slot.qrW
    m.bookQr.loadDisplayMode = "scaleToFit"
    m.bookQr.visible = false
    pane.appendChild(m.bookQr)
    m.bookQr.observeField("loadStatus", "onBookQrStatus")
    scan = AddLabel(pane, "Scan me!", "font:SmallBoldSystemFont", BookInkColor(), slot.labelX, slot.labelY, slot.labelW, slot.labelH)
    scan.horizAlign = "center"
    scan.visible = false
    m.bookScan = scan
    m.bookDomain = AddLabel(pane, DisplayDomain(), QrCaptionFont(), "0xF2A93BFF", slot.domainX, slot.domainY, slot.domainW, slot.domainH)
    m.bookDomain.horizAlign = "center"
    m.bookDomain.visible = false
    m.bookQrMissing = AddLabel(pane, "", "font:SmallestSystemFont", AmberColor(), slot.domainX, slot.domainY, slot.domainW, slot.domainH)
    m.bookQrMissing.horizAlign = "center"
    m.bookQrMissing.visible = false
    bodyRect = BookBodyRect()
    m.bookBody = AddLabel(pane, "", "font:SmallSystemFont", BookInkColor(), bodyRect.x, bodyRect.y, bodyRect.w, bodyRect.h)
    m.bookBody.vertAlign = "top"
    m.bookBody.maxLines = 6
    saveRect = BookSavingsRect()
    m.bookSavings = AddLabel(pane, "", "font:SmallestSystemFont", BookInkColor(), saveRect.x, saveRect.y, saveRect.w, saveRect.h)
    m.bookSavings.vertAlign = "top"
    m.bookSavings.maxLines = 5
    m.perkGroups = []
    perkRow = BookPerkRow()
    for index = 0 to 4
        chip = CreateObject("roSGNode", "Group")
        chip.translation = [perkRow.x + (index * 226), perkRow.y]
        bg = AddRect(chip, BookCardColor(), 0, 0, 214, 88)
        text = AddLabel(chip, "", "font:SmallestSystemFont", BookInkColor(), 8, 4, 198, 80)
        text.horizAlign = "center"
        text.vertAlign = "center"
        text.maxLines = 2
        pane.appendChild(chip)
        m.perkGroups.Push({ group: chip, bg: bg, text: text })
    end for
    m.bookSign = AddLabel(pane, "", "font:SmallBoldSystemFont", BookInkColor(), 1288, 888, 300, 36)
    m.bookSign.horizAlign = "right"
    m.bookPhotoUri = ""
    m.bookQrUri = ""
    m.bookFile = ""
    return pane
end function

function BuildWifiPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    AddLabel(pane, "Join the Wi-Fi", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 64)
    m.wifiBacking = AddRect(pane, "0x1A2438FF", ContentLeft(), ContentTop() + 96, 400, 400)
    m.wifiPoster = CreateObject("roSGNode", "Poster")
    m.wifiPoster.id = "wifiQr"
    m.wifiPoster.focusable = false
    m.wifiPoster.translation = [ContentLeft() + 20, ContentTop() + 116]
    m.wifiPoster.width = 360
    m.wifiPoster.height = 360
    m.wifiPoster.loadWidth = 480
    m.wifiPoster.loadHeight = 480
    m.wifiPoster.loadDisplayMode = "scaleToFit"
    m.wifiPoster.visible = false
    pane.appendChild(m.wifiPoster)
    m.wifiPoster.observeField("loadStatus", "onWifiPosterStatus")
    m.wifiMissing = AddLabel(pane, "", "font:SmallSystemFont", "0xFFFFFFF2", ContentLeft() + 16, ContentTop() + 128, 368, 336)
    m.wifiMissing.horizAlign = "center"
    m.wifiMissing.vertAlign = "top"
    m.wifiMissing.maxLines = 8
    textX = ContentLeft() + 430
    textW = 700
    AddLabel(pane, "Network", "font:SmallSystemFont", MuteColor(), textX, ContentTop() + 96, textW, 36)
    m.wifiSsidLabel = AddLabel(pane, "", "font:SmallBoldSystemFont", InkColor(), textX, ContentTop() + 132, textW, 108)
    m.wifiSsidLabel.vertAlign = "top"
    m.wifiSsidLabel.maxLines = 3
    m.wifiPasswordHeading = AddLabel(pane, "Password", "font:SmallSystemFont", MuteColor(), textX, ContentTop() + 248, textW, 36)
    m.wifiPasswordLabel = AddLabel(pane, "", "font:SmallBoldSystemFont", InkColor(), textX, ContentTop() + 284, textW, 156)
    m.wifiPasswordLabel.vertAlign = "top"
    m.wifiPasswordLabel.maxLines = 6
    m.wifiHint = AddLabel(pane, "Point your phone camera at the code and tap the banner to join.", "font:SmallSystemFont", MuteColor(), textX, ContentTop() + 460, textW, 110)
    m.wifiHint.vertAlign = "top"
    m.wifiHint.maxLines = 4
    m.wifiRouter = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), 710, ContentWidth(), 180)
    m.wifiRouter.vertAlign = "top"
    m.wifiRouter.maxLines = 6
    m.wifiShown = ""
    m.wifiPaintToken = ""
    return pane
end function

function BuildActivityPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    m.activityTitle = AddLabel(pane, "", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 64)
    m.activitySub = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 64, ContentWidth(), 36)
    grid = CreateObject("roSGNode", "MarkupGrid")
    grid.translation = [ContentLeft(), ContentTop() + 104]
    grid.itemComponentName = "ActivityCard"
    grid.itemSize = [364, 488]
    grid.itemSpacing = [18, 16]
    grid.numColumns = 3
    grid.numRows = 1
    grid.drawFocusFeedback = false
    grid.focusable = false
    grid.vertFocusAnimationStyle = "floatingFocus"
    pane.appendChild(grid)
    m.activityGrid = grid
    m.activityEmpty = AddLabel(pane, ActivityEmptyText(""), "font:MediumSystemFont", MuteColor(), ContentLeft(), ContentTop() + 180, ContentWidth(), 72)
    m.activityEmpty.vertAlign = "top"
    m.activityEmpty.maxLines = 2
    m.activityEmpty.visible = false
    m.activityHint = AddLabel(pane, "Left menu    Arrows browse    OK open", "font:SmallSystemFont", MuteColor(), ContentLeft(), 752, 900, 32)
    return pane
end function

function BuildDetailPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    m.detailName = AddLabel(pane, "", "font:MediumBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 132)
    m.detailName.vertAlign = "top"
    m.detailName.maxLines = 3
    m.detailPhoto = CreateObject("roSGNode", "Poster")
    photo = DetailPhotoRect()
    m.detailPhoto.translation = [photo.x, photo.y]
    m.detailPhoto.width = photo.w
    m.detailPhoto.height = photo.h
    m.detailPhoto.loadWidth = 640
    m.detailPhoto.loadHeight = 360
    m.detailPhoto.loadDisplayMode = "scaleToZoom"
    m.detailPhoto.failedBitmapUri = PlaceholderPoster()
    pane.appendChild(m.detailPhoto)
    m.detailPhoto.observeField("loadStatus", "onDetailPhotoStatus")
    card = DetailQrCardRect()
    cardX = card.x
    cardY = card.y
    qrCard = AddRect(pane, "0xFFFFFFF2", cardX, cardY, card.w, card.h)
    qrCard.visible = false
    m.detailQrCard = qrCard
    m.detailQrMark = AddRect(pane, QrMarkColor(), cardX, cardY, card.w, card.h)
    m.detailQrMark.visible = false
    m.detailPlace = invalid
    siteRect = DetailQrSiteRect()
    site = AddLabel(pane, "Website / menu", "font:SmallSystemFont", "0x1C1408FF", siteRect.x, siteRect.y, siteRect.w, siteRect.h)
    site.horizAlign = "center"
    site.visible = false
    m.detailSite = site
    posterRect = DetailQrPosterRect()
    m.detailQr = CreateObject("roSGNode", "Poster")
    m.detailQr.id = "detailQr"
    m.detailQr.focusable = false
    m.detailQr.translation = [posterRect.x, posterRect.y]
    m.detailQr.width = posterRect.w
    m.detailQr.height = posterRect.h
    m.detailQr.loadWidth = posterRect.w
    m.detailQr.loadHeight = posterRect.w
    m.detailQr.loadDisplayMode = "scaleToFit"
    m.detailQr.visible = false
    pane.appendChild(m.detailQr)
    m.detailQr.observeField("loadStatus", "onDetailQrStatus")
    captionRect = DetailQrCaptionRect()
    m.detailQrCaption = AddLabel(pane, "", QrCaptionFont(), QrCaptionColor(), captionRect.x, captionRect.y, captionRect.w, captionRect.h)
    m.detailQrCaption.horizAlign = "center"
    m.detailQrCaption.visible = false
    m.detailQrMissing = AddLabel(pane, "", "font:SmallestSystemFont", "0x1C1408FF", cardX, cardY + card.h - 32, card.w, 28)
    m.detailQrMissing.horizAlign = "center"
    m.detailQrMissing.visible = false
    m.detailMeta = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 432, ContentWidth(), 36)
    body = DetailBodyRect()
    m.detailBody = AddLabel(pane, "", "font:SmallSystemFont", InkColor(), body.x, body.y, body.w, body.h)
    m.detailBody.vertAlign = "top"
    m.detailBody.maxLines = 6
    m.detailTip = AddLabel(pane, "", "font:SmallBoldSystemFont", AmberColor(), ContentLeft(), ContentTop() + 680, 700, 48)
    m.detailTip.vertAlign = "top"
    m.detailTip.maxLines = 2
    m.detailExtra = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 732, 700, 44)
    m.detailExtra.vertAlign = "top"
    m.detailExtra.maxLines = 2
    m.detailCredit = AddLabel(pane, "", "font:SmallestSystemFont", MuteColor(), ContentLeft() + 420, 900, 280, 28)
    m.detailBack = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), 900, 400, 28)
    m.detailPhotoUri = ""
    m.detailQrUri = ""
    m.detailFile = ""
    return pane
end function

sub PaintPhase2()
    PaintPrompt()
    PaintBook()
    PaintWifi()
    if ActivitySection(m.section) then PaintActivity()
    PaintBadge()
end sub

sub PaintPrompt()
    if m.promptTitle = invalid or m.book = invalid then return
    m.promptTitle.text = HomePromptTitle(m.book)
    m.promptSub.text = PromptSubline(BookText(m.book, "homePromptSub", "Up to about 10% less than Airbnb or Vrbo"))
    focused = (m.zone = "prompt" and m.section = "home")
    if m.promptInner = invalid then return
    if focused
        m.promptInner.translation = [4, 4]
        m.promptInner.width = 1124
        m.promptInner.height = 148
    else
        m.promptInner.translation = [0, 0]
        m.promptInner.width = 1132
        m.promptInner.height = 156
    end if
end sub

function HomePromptTitle(book as object) as string
    title = "Book your next stay direct and save!"
    text = BookText(book, "homePromptTitle", title)
    if text = "Book direct & save" then return title
    return text
end function

function PromptSubline(text as string) as string
    if text = invalid then text = ""
    if Instr(1, LCase(text), "ok for details") > 0 then return text
    if text = "" then return "OK for details"
    return text + "  ·  OK for details"
end function

function BookText(book as object, key as string, fallback as string) as string
    if not IsAssoc(book) then return fallback
    text = GuideLimitedText(book.Lookup(key), 180)
    if text = "" then return fallback
    return text
end function

sub PaintBadge()
    uri = ""
    if IsAssoc(m.book) then uri = GuideLimitedText(m.book.Lookup("bookingQrImageUrl"), 320)
    if not PosterKindOk(uri) then uri = ""
    uri = WithQrVersion(uri)
    if m.badgeDomain <> invalid then m.badgeDomain.text = DisplayDomain()
    EnsureQrSlot("badge", uri)
end sub

sub onBadgeStatus()
    NoteQrLoaded("badge")
    poster = PosterForSlot("badge")
    if poster = invalid then return
    status = poster.loadStatus
    if status <> "failed" and status <> "error" then return
    if QrRemote("badge") <> "" and m.section <> "book"
        if m.badgeGroup <> invalid then m.badgeGroup.visible = true
        if m.badgeCard <> invalid then m.badgeCard.visible = true
        if m.badgeDomain <> invalid then m.badgeDomain.visible = true
        poster.visible = false
        ShowQrMark("badge", true)
    end if
    if m.qrAssigning = true then return
    if QrRetried("badge") then return
    ScheduleBadgeRetry()
end sub

' The retry runs on a timer so it is outside the loadStatus observer.
sub ScheduleBadgeRetry()
    if m.badgeRetryArmed = true then return
    if m.top = invalid then return
    m.badgeRetryArmed = true
    timer = CreateObject("roSGNode", "Timer")
    timer.duration = 0.2
    timer.repeat = false
    timer.observeField("fire", "onBadgeRetry")
    m.top.appendChild(timer)
    m.badgeRetryTimer = timer
    timer.control = "start"
end sub

sub onBadgeRetry()
    if m.badgeRetryTimer <> invalid
        m.badgeRetryTimer.control = "stop"
        if m.top <> invalid then m.top.removeChild(m.badgeRetryTimer)
        m.badgeRetryTimer = invalid
    end if
    m.badgeRetryArmed = false
    if QrRemote("badge") = "" or m.section = "book" then return
    path = StoredQrPath("badge")
    poster = PosterForSlot("badge")
    if poster = invalid or path = "" then return
    MountQrPoster(poster, path, "badge")
end sub

sub UpdateBadgeVisible()
    ShowQrFrame("badge", QrRemote("badge") <> "")
end sub

sub ShowBadgeFrame(show as boolean)
    if BadgeShown(m.section) <> true then show = false
    if m.badgeGroup <> invalid then m.badgeGroup.visible = show
    if m.badgeCard <> invalid then m.badgeCard.visible = show
    if m.badgeLabel <> invalid then m.badgeLabel.visible = show
    if m.badgeDomain <> invalid then m.badgeDomain.visible = show
    failed = BadgePosterFailed()
    if m.badgePoster <> invalid
        if show = true and failed = true
            m.badgePoster.visible = false
        else
            m.badgePoster.visible = show
        end if
    end if
    if m.badgeMissing <> invalid then m.badgeMissing.visible = false
    if show = true and failed = true
        ShowQrMark("badge", true)
    else
        ShowQrMark("badge", show)
    end if
    if m.badgeHint = invalid then return
    if show and m.zone = "item"
        m.badgeHint.text = "Always available"
        m.badgeHint.visible = true
    else
        m.badgeHint.visible = false
    end if
end sub

sub PaintBook()
    if m.bookPane = invalid or not IsAssoc(m.book) then return
    lines = BookHeadline(m.book)
    if m.bookLines <> invalid
        last = m.bookLines.Count() - 1
        for index = 0 to last
            text = ""
            if index < lines.Count() then text = lines[index]
            m.bookLines[index].text = text
            m.bookLines[index].visible = (text <> "")
        end for
    end if
    if m.bookBanner <> invalid then m.bookBanner.text = BookText(m.book, "banner", "Book direct and save!")
    if m.bookBody <> invalid then m.bookBody.text = BookText(m.book, "body", "")
    if m.bookSavings <> invalid then m.bookSavings.text = BookText(m.book, "savingsText", DefaultSavingsText())
    if m.section = "book" then LogBookBody()
    if m.bookSign <> invalid then m.bookSign.text = BookText(m.book, "signOff", "Thanks for staying!")
    if m.bookDomain <> invalid then m.bookDomain.text = DisplayDomain()
    PaintPerks()
    photo = GuideLimitedText(m.book.Lookup("photo"), 240)
    if photo = "" then photo = GuideLimitedText(m.book.Lookup("photoFallback"), 240)
    if photo <> m.bookPhotoUri and m.bookPhoto <> invalid
        m.bookPhotoUri = photo
        m.bookPhotoTried = false
        m.bookPhoto.loadWidth = 680
        m.bookPhoto.loadHeight = 360
        m.bookPhoto.uri = photo
    end if
    qr = WithQrVersion(GuideLimitedText(m.book.Lookup("qrImageUrl"), 320))
    if not PosterKindOk(qr) then qr = ""
    EnsureQrSlot("book", qr)
end sub

function BookHeadline(book as object) as object
    lines = []
    raw = invalid
    if IsAssoc(book) then raw = book.Lookup("headline")
    if IsList(raw)
        last = raw.Count() - 1
        if last > 2 then last = 2
        if last >= 0
            for index = 0 to last
                text = GuideLimitedText(raw[index], 80)
                if text <> "" then lines.Push(text)
            end for
        end if
    end if
    if lines.Count() = 0 then return ["Love our home?", "Want to come back?", "Like saving money?"]
    return lines
end function

sub PaintPerks()
    if m.perkGroups = invalid then return
    perks = []
    if IsAssoc(m.book)
        raw = m.book.Lookup("perks")
        if IsList(raw) then perks = raw
    end if
    colors = [BookBannerColor(), BookCardColor(), BookBannerColor(), BookCardColor(), BookBannerColor()]
    inks = [InkOnAmber(), BookInkColor(), InkOnAmber(), BookInkColor(), InkOnAmber()]
    last = m.perkGroups.Count() - 1
    for index = 0 to last
        chip = m.perkGroups[index]
        if index >= perks.Count()
            chip.group.visible = false
        else
            chip.group.visible = true
            label = ""
            entry = perks[index]
            if IsAssoc(entry) then label = GuideLimitedText(entry.Lookup("label"), 40)
            chip.text.text = label
            chip.bg.color = colors[index]
            chip.text.color = inks[index]
        end if
    end for
end sub

sub onBookPhotoStatus()
    if m.bookPhoto = invalid then return
    status = m.bookPhoto.loadStatus
    if status <> "failed" and status <> "error" then return
    if m.bookPhotoTried = true then return
    m.bookPhotoTried = true
    fallback = ""
    if IsAssoc(m.book) then fallback = GuideLimitedText(m.book.Lookup("photoFallback"), 240)
    if fallback <> "" and fallback <> m.bookPhotoUri
        m.bookPhotoUri = fallback
        m.bookPhoto.loadWidth = 680
        m.bookPhoto.loadHeight = 360
        m.bookPhoto.uri = fallback
    end if
end sub

sub ShowBookQr(show as boolean)
    if m.bookQrCard <> invalid then m.bookQrCard.visible = show
    if m.bookQrPlate <> invalid then m.bookQrPlate.visible = show
    if m.bookScan <> invalid then m.bookScan.visible = show
    if m.bookDomain <> invalid then m.bookDomain.visible = show
    if m.bookQr <> invalid then m.bookQr.visible = show
    if m.bookQrMissing <> invalid then m.bookQrMissing.visible = false
    ShowQrMark("book", show)
end sub

' Assign a path the task already finished. The scene does not read the file.
' A failed load clears uri, so the assigned path is retried once, and that
' retry never runs from inside the loadStatus observer.
sub MountQrPosterBody(poster as object, path as string, slot as string)
    if m.qrAssigning = true then return
    if poster = invalid or path = invalid or path = "" then return
    if Left(path, 8) <> "cachefs:" and Left(path, 4) <> "tmp:" then return
    poster.visible = true
    poster.focusable = false
    poster.loadDisplayMode = "scaleToFit"
    RememberPoster(slot, poster)
    status = poster.loadStatus
    if slot = "badge" then LogBadgeColdStart(path, NotedQrBytes(slot), status)
    plan = BadgeColdStartPlan(path, NotedQrBytes(slot), poster.uri, status)
    if plan.action = "keep" then return
    if poster.uri = path and plan.action = "assign"
        print "Eaglewood: qr "; slot; " retry"
        m.qrAssigning = true
        poster.uri = ""
        poster.uri = path
        m.qrAssigning = false
        LogQrState(slot, poster)
        return
    end if
    if AssignedQrPath(slot) = path
        if status = "ready" or status = "loading" then return
        if QrRetried(slot) then return
        MarkQrRetry(slot)
        print "Eaglewood: qr "; slot; " retry"
        m.qrAssigning = true
        poster.uri = ""
        poster.uri = path
        m.qrAssigning = false
        LogQrState(slot, poster)
        return
    end if
    noted = NotedQrBytes(slot)
    print "Eaglewood: qr "; slot; " file bytes="; noted; " read="; noted
    ClearQrRetry(slot)
    NoteAssigned(slot, path)
    m.qrAssigning = true
    poster.uri = path
    m.qrAssigning = false
    LogQrState(slot, poster)
end sub

sub onBookQrStatus()
    NoteQrLoaded("book")
end sub

sub PaintWifi()
    if m.wifiSsidLabel = invalid then return
    notice = ""
    if m.wifiNotice <> invalid then notice = m.wifiNotice
    ssid = ""
    if m.wifiSsid <> invalid then ssid = m.wifiSsid
    password = ""
    if m.wifiPassword <> invalid then password = m.wifiPassword
    lines = WifiLines(notice, ssid, password)
    m.wifiSsidLabel.text = lines.network
        if m.wifiPasswordLabel <> invalid
        if lines.mode = "show"
            m.wifiPasswordLabel.text = lines.password
            m.wifiPasswordLabel.font = "font:SmallBoldSystemFont"
        else
            m.wifiPasswordLabel.text = ""
            m.wifiPasswordLabel.font = "font:SmallSystemFont"
        end if
    end if
    if m.wifiPasswordHeading <> invalid then m.wifiPasswordHeading.visible = (lines.mode = "show")
    if m.wifiHint <> invalid then m.wifiHint.visible = (lines.mode = "show")
    if m.wifiPaintToken <> lines.mode
        m.wifiPaintToken = lines.mode
        print "Eaglewood: wifi screen mode="; lines.mode
    end if
    if m.wifiRouter <> invalid then m.wifiRouter.text = RouterStep(m.issues)
    pngReady = (m.wifiPng = "yes")
    poster = PosterForSlot("wifi")
    if poster = invalid then return
    path = "cachefs:/eaglewood/wifi.png"
    if m.wifiFile <> invalid and m.wifiFile <> "" then path = m.wifiFile
    plate = ""
    if pngReady
        poster.loadWidth = 480
        poster.loadHeight = 480
        GuardMountQrPoster(poster, path, "wifi")
    end if
    drawn = false
    if pngReady = true
        if poster.loadStatus = "ready" then drawn = true
    end if
    if drawn
        poster.visible = true
        if m.wifiBacking <> invalid
            m.wifiBacking.color = "0xFFFFFFFF"
            m.wifiBacking.visible = true
        end if
        if m.wifiMissing <> invalid
            m.wifiMissing.text = ""
            m.wifiMissing.visible = false
        end if
    else
        poster.visible = false
        if m.wifiBacking <> invalid
            m.wifiBacking.color = "0x1A2438FF"
            m.wifiBacking.visible = true
        end if
        if notice = "coming-soon"
            plate = ComingSoonWifi()
        else if lines.mode = "fallback"
            plate = WifiFallbackMessage()
        else
            plate = "Join code unavailable"
        end if
        if m.wifiMissing <> invalid
            m.wifiMissing.color = "0xFFFFFFF2"
            m.wifiMissing.text = plate
            m.wifiMissing.visible = true
        end if
    end if
end sub

function WifiLines(notice as string, ssid as string, password as string) as object
    if notice = "coming-soon" and ssid = ""
        return { mode: "coming-soon", network: ComingSoonWifi(), password: "" }
    end if
    if ssid = ""
        return { mode: "fallback", network: NetworkValue(WifiFallbackText()), password: WifiFallbackMessage() }
    end if
    return { mode: "show", network: ssid, password: password }
end function

function NetworkValue(text as string) as string
    if text = invalid then return ""
    prefix = "network name:"
    if Len(text) < Len(prefix) then return text
    if LCase(Left(text, Len(prefix))) <> prefix then return text
    rest = Mid(text, Len(prefix) + 1)
    if rest = invalid then return ""
    rest = rest.Trim()
    if rest = "" then return text
    return rest
end function

function WifiFallbackMessage() as string
    return "Wi-Fi details couldn't load right now. Please check your booking welcome message or contact your host (see Help)."
end function

sub onWifiPosterStatus()
    if m.wifiPoster = invalid then return
    LogQrState("wifi", m.wifiPoster)
    status = m.wifiPoster.loadStatus
    if status = "ready"
        m.wifiPoster.visible = true
        if m.wifiMissing <> invalid then m.wifiMissing.text = ""
        return
    end if
    if status <> "failed" and status <> "error" then return
    if m.wifiMissing <> invalid then m.wifiMissing.text = "QR image could not be drawn"
end sub

function WifiFallbackText() as string
    if not IsList(m.issues) then return ComingSoonWifi()
    last = m.issues.Count() - 1
    if last < 0 then return ComingSoonWifi()
    for index = 0 to last
        issue = m.issues[index]
        if WifiIssueText(issue)
            steps = issue.Lookup("steps")
            if IsList(steps) and steps.Count() > 0
                return GuideLimitedText(steps[0], 180)
            end if
        end if
    end for
    return ComingSoonWifi()
end function

sub PaintActivity()
    if m.activityTitle = invalid then return
    m.activityTitle.text = RailLabel(m.section)
    if m.activitySub <> invalid then m.activitySub.text = ActivitySubtitle()
    EnsureActivityGrid()
    count = CardCount()
    if m.activityEmpty <> invalid
        if count = 0 then m.activityEmpty.text = ActivityEmptyText(m.section)
        m.activityEmpty.visible = (count = 0)
    end if
    if m.activityGrid <> invalid then m.activityGrid.visible = (count > 0)
    if m.zone = "item"
        PaintDetail()
    else
        ShowCardFocus()
    end if
end sub

function ActivitySubtitle() as string
    season = "winter"
    if m.activitySeason <> invalid and m.activitySeason <> "" then season = m.activitySeason
    extra = "Seasonal picks"
    if m.section = "dining" then extra = "Village & Bend"
    if m.section = "hiking" then extra = "Trails nearby"
    if m.section = "winter" then extra = "Winter picks"
    if m.section = "summer" then extra = "Summer picks"
    if m.section = "fishing" then extra = "On the water"
    if m.section = "biking" then extra = "Rides nearby"
    if m.section = "todo" then extra = "OK to browse"
    return "Sorted for " + season + "  ·  " + extra
end function

sub EnsureActivityGrid()
    if m.boundSection <> m.section
        m.boundSection = m.section
        m.cardIndex = 0
        m.jumpedIndex = -1
    end if
    season = CurrentSeason()
    m.activitySeason = season
    token = 0
    if m.activitiesToken <> invalid then token = m.activitiesToken
    count = 0
    if IsList(m.activities) then count = m.activities.Count()
    stamp = m.section + "|" + token.ToStr() + "|" + count.ToStr() + "|" + season
    if stamp = m.activityStamp and m.activityContent <> invalid then return
    m.activityStamp = stamp
    picked = ActivitiesForScreen(m.activities, m.section)
    m.sortedCards = SortActivities(picked, season)
    if m.cardIndex < 0 or m.cardIndex >= CardCount() then m.cardIndex = 0
    RebuildActivityGrid()
end sub

function CardCount() as integer
    if not IsList(m.sortedCards) then return 0
    return m.sortedCards.Count()
end function

sub RebuildActivityGrid()
    if m.activityGrid = invalid then return
    root = CreateObject("roSGNode", "ContentNode")
    last = CardCount() - 1
    if last >= 0
        for index = 0 to last
            item = m.sortedCards[index]
            node = CreateObject("roSGNode", "ActivityContent")
            node.id = CardNodeId(item)
            node.title = ItemText(item, "name")
            node.distance = ItemText(item, "distance")
            node.seasonLabel = ItemText(item, "seasonLabel")
            node.swatch = SwatchFor(SourceIndexOf(item))
            node.sourceIndex = SourceIndexOf(item)
            node.imageUri = ""
            node.imageFallback = ""
            node.cardFocused = false
            root.appendChild(node)
        end for
    end if
    m.activityContent = root
    m.activityGrid.content = root
    m.jumpedIndex = -1
end sub

function CardNodeId(item as object) as string
    return "card" + SourceIndexOf(item).ToStr()
end function

function ItemText(item as object, key as string) as string
    if not IsAssoc(item) then return ""
    return GuideLimitedText(AaField(item, key), 420)
end function

function SwatchFor(index as integer) as string
    colors = ["0x6B4A32FF", "0x5C4033FF", "0x3E5C45FF", "0x4A5560FF", "0x6A5330FF", "0x2F4F45FF"]
    slot = index mod 6
    if slot < 0 then slot = 0
    return colors[slot]
end function

sub ShowCardFocus()
    if m.activityContent = invalid then return
    count = m.activityContent.getChildCount()
    if count < 1 then return
    start = ActivityWindowStart(m.cardIndex)
    finish = start + 9
    if finish > count then finish = count
    last = count - 1
    for index = 0 to last
        child = m.activityContent.getChild(index)
        child.cardFocused = (m.zone = "grid" and index = m.cardIndex)
        uri = ""
        fallback = ""
        if index >= start and index < finish
            item = invalid
            if index < CardCount() then item = m.sortedCards[index]
            if IsAssoc(item)
                uri = ItemText(item, "poster")
                fallback = ItemText(item, "posterFallback")
            end if
            if uri = "" then uri = PlaceholderPoster()
        end if
        if child.imageFallback <> fallback then child.imageFallback = fallback
        if child.imageUri <> uri then child.imageUri = uri
    end for
    if m.activityGrid <> invalid and m.zone = "grid" and m.jumpedIndex <> m.cardIndex
        m.activityGrid.jumpToItem = m.cardIndex
        m.jumpedIndex = m.cardIndex
    end if
end sub

function ActivityWindowStart(index as integer) as integer
    if index < 0 then return 0
    row = index \ 3
    if row > 0 then row = row - 1
    return row * 3
end function

sub ReleaseCardImages()
    if m.activityContent = invalid then return
    last = m.activityContent.getChildCount() - 1
    if last < 0 then return
    for index = 0 to last
        child = m.activityContent.getChild(index)
        child.cardFocused = false
        child.imageUri = ""
        child.imageFallback = ""
    end for
end sub

sub PaintDetail()
    LogDetailOpen()
    item = ActivityAt(m.sortedCards, m.cardIndex)
    if m.detailName <> invalid then m.detailName.text = ItemText(item, "name")
    if m.detailMeta <> invalid then m.detailMeta.text = DetailMeta(item)
    if m.detailBody <> invalid
        m.detailBody.text = ""
        m.detailBody.visible = false
    end if
    if m.detailTip <> invalid
        m.detailTip.text = ""
        m.detailTip.visible = false
    end if
    if m.detailExtra <> invalid
        m.detailExtra.text = ""
        m.detailExtra.visible = false
    end if
    FillDetailBody()
    if m.detailCredit <> invalid then m.detailCredit.text = ItemText(item, "credit")
    if m.detailBack <> invalid then m.detailBack.text = "Back to " + RailLabel(m.section)
    photo = ItemText(item, "poster")
    if photo = "" then photo = PlaceholderPoster()
    if m.detailPhoto <> invalid and photo <> m.detailPhotoUri
        m.detailPhotoUri = photo
        m.detailPhotoTried = false
        m.detailPhoto.loadWidth = 640
        m.detailPhoto.loadHeight = 360
        m.detailPhoto.uri = photo
    end if
    qr = DetailQrForItem(item)
    if m.detailQrCaption <> invalid
        if m.section = "dining" then m.detailQrCaption.text = "Scan for this restaurant"
        else m.detailQrCaption.text = "Scan for this place"
    end if
    if qr = ""
        source = "none"
        if m.activitiesSource <> invalid and m.activitiesSource <> "" then source = m.activitiesSource
        print "Eaglewood: qr detail skip reason=no-url id="; ItemText(item, "id"); " index="; m.cardIndex; " source="; source
    else if qr <> QrRemote("detail")
        print "Eaglewood: qr detail open url="; SafeUri(qr)
    end if
    EnsureQrSlot("detail", qr)
    RevealDetailQr()
end sub

sub LogDetailOpen()
    item = ActivityAt(m.sortedCards, m.cardIndex)
    id = ItemText(item, "id")
    qr = DetailQrForItem(item)
    print "Eaglewood: detail open id="; id; " qrUrl="; qr
    print "Eaglewood: detail card rect="; ScreenRectText(DetailQrCardRect())
end sub

sub LogBookBody()
    text = ""
    if m.bookBody <> invalid then text = m.bookBody.text
    rect = BookBodyRect()
    lines = WrapGreeting(text, rect.w, invalid, FallbackCharWidth(BookBodyFontSize()))
    print "Eaglewood: book body lines="; lines.Count(); " rect="; ScreenRectText(rect)
end sub

function BookBodyFontSize() as integer
    return 27
end function

function BookBodyLineHeight() as integer
    return 36
end function

function BookSavingsFontSize() as integer
    return 20
end function

function BookSavingsLineHeight() as integer
    return 26
end function

function BookPanelColor() as string
    return "0x1A2438FF"
end function

function BookCardColor() as string
    return "0x243044FF"
end function

function BookBannerColor() as string
    return "0xF2A93BFF"
end function

function BookInkColor() as string
    return "0xFFFFFFF2"
end function

sub LogBadgePlacement()
    group = m.badgeGroup
    if group = invalid then return
    visible = "false"
    if group.visible = true then visible = "true"
    parentId = "none"
    index = -1
    parent = group.getParent()
    if parent <> invalid
        parentId = "shell"
        if parent.id <> invalid and parent.id <> "" then parentId = parent.id
        count = parent.getChildCount()
        last = count - 1
        if last >= 0
            for at = 0 to last
                child = parent.getChild(at)
                same = false
                if child <> invalid
                    if child.isSameNode(group) = true then same = true
                end if
                if same = true then index = at
            end for
        end if
    end if
    opacity = 1
    if group.opacity <> invalid then opacity = group.opacity
    tx = 0
    ty = 0
    trans = group.translation
    if trans <> invalid
        tx = trans[0]
        ty = trans[1]
    end if
    scene = BadgeSceneRect(group)
    print "Eaglewood: badge visible="; visible; " parent="; parentId; " index="; index; " opacity="; opacity; " translation="; tx.ToStr(); ","; ty.ToStr(); " sceneRect="; ScreenRectText(scene)
end sub

function BadgeSceneRect(node as object) as object
    frame = BadgeFrame()
    x = frame.x
    y = frame.y
    wide = frame.w
    tall = frame.h
    if node = invalid then return { x: x, y: y, w: wide, h: tall }
    bounds = node.boundingRect()
    if bounds <> invalid
        if bounds.x <> invalid then x = bounds.x
        if bounds.y <> invalid then y = bounds.y
        if bounds.width <> invalid and bounds.width > 0 then wide = bounds.width
        if bounds.height <> invalid and bounds.height > 0 then tall = bounds.height
    end if
    parent = node.getParent()
    while parent <> invalid
        trans = parent.translation
        if trans <> invalid
            x = x + trans[0]
            y = y + trans[1]
        end if
        parent = parent.getParent()
    end while
    return { x: x, y: y, w: wide, h: tall }
end function

function BadgeShown(section as string) as boolean
    if section = "book" then return false
    return true
end function

function BadgeNavigateReparents() as boolean
    return false
end function

function DetailQrForItem(item as object) as string
    qr = DetailQrUrl(item)
    if qr <> "" then return qr
    alt = ActivityById(m.activities, ItemText(item, "id"))
    if alt = invalid then return ""
    return DetailQrUrl(alt)
end function

sub ShowDetailQr(show as boolean)
    ready = DetailPosterReady()
    if m.detailQrCard <> invalid then m.detailQrCard.visible = show
    if m.detailPlace <> invalid then m.detailPlace.visible = show
    if m.detailSite <> invalid then m.detailSite.visible = show
    if m.detailQrCaption <> invalid then m.detailQrCaption.visible = show
    if m.detailQr <> invalid then m.detailQr.visible = (show and ready)
    if m.detailQrMissing <> invalid then m.detailQrMissing.visible = false
    ShowQrMark("detail", show)
end sub

function DetailPosterReady() as boolean
    poster = PosterForSlot("detail")
    if poster = invalid then return false
    if poster.loadStatus = "ready" then return true
    return false
end function

' The poster stays hidden until it has a bitmap, so the cream rect stays visible.
sub RevealDetailQr()
    if QrRemote("detail") = "" then return
    ready = DetailPosterReady()
    if m.detailQrCard <> invalid then m.detailQrCard.visible = true
    poster = PosterForSlot("detail")
    if poster <> invalid then poster.visible = ready
    if ready
        ShowQrMark("detail", false)
    else
        ShowQrMark("detail", true)
    end if
end sub

function DetailMeta(item as object) as string
    bits = []
    season = ItemText(item, "seasonLabel")
    distance = ItemText(item, "distance")
    if season <> "" then bits.Push(season)
    if distance <> "" then bits.Push(distance)
    return JoinBits(bits)
end function

function ActivityScrollText() as string
    item = ActivityAt(m.sortedCards, m.cardIndex)
    text = ItemText(item, "description")
    tip = ItemText(item, "tip")
    extra = DetailExtra(item)
    if tip <> "" then text = text + Chr(10) + "Tip: " + tip
    if extra <> "" then text = text + Chr(10) + extra
    return text
end function

function DetailExtra(item as object) as string
    bits = []
    difficulty = ItemText(item, "difficulty")
    trail = ItemText(item, "trailDistance")
    getting = ItemText(item, "gettingThere")
    if difficulty <> "" then bits.Push(difficulty)
    if trail <> "" then bits.Push(trail)
    line = JoinBits(bits)
    if getting <> ""
        if line <> "" then line = line + " · "
        line = line + getting
    end if
    return line
end function

function JoinBits(bits as object) as string
    if not IsList(bits) or bits.Count() = 0 then return ""
    line = bits[0]
    last = bits.Count() - 1
    if last < 1 then return line
    for index = 1 to last
        line = line + " · " + bits[index]
    end for
    return line
end function

sub onDetailPhotoStatus()
    if m.detailPhoto = invalid then return
    status = m.detailPhoto.loadStatus
    if status <> "failed" and status <> "error" then return
    if m.detailPhotoTried = true
        if m.detailPhotoUri <> PlaceholderPoster()
            m.detailPhotoUri = PlaceholderPoster()
            m.detailPhoto.loadWidth = 64
            m.detailPhoto.loadHeight = 64
            m.detailPhoto.uri = PlaceholderPoster()
        end if
        return
    end if
    m.detailPhotoTried = true
    item = ActivityAt(m.sortedCards, m.cardIndex)
    fallback = ItemText(item, "posterFallback")
    if fallback <> "" and fallback <> m.detailPhotoUri
        m.detailPhotoUri = fallback
        m.detailPhoto.loadWidth = 640
        m.detailPhoto.loadHeight = 360
        m.detailPhoto.uri = fallback
        return
    end if
    m.detailPhotoUri = PlaceholderPoster()
    m.detailPhoto.uri = PlaceholderPoster()
end sub

sub onDetailQrStatus()
    NoteQrLoaded("detail")
end sub

sub ApplyWifiResult(result as object)
    if result = invalid then return
    m.wifiSsid = AsText(AaField(result, "ssid"))
    m.wifiPassword = AsText(AaField(result, "password"))
    m.wifiPng = AsText(AaField(result, "png"))
    if m.wifiPng = "" then m.wifiPng = "no"
    m.wifiSource = AsText(result.source)
    m.wifiNotice = AsText(result.notice)
    m.wifiJsonCode = ResultNumber(result, "jsonCode")
    m.wifiPngCode = ResultNumber(result, "pngCode")
    m.wifiPngBit = ResultNumber(result, "pngBit")
    m.wifiPngColor = ResultNumber(result, "pngColor")
    m.wifiPngInterlace = ResultNumber(result, "pngInterlace")
    m.wifiIndexed = AsText(result.pngIndexed)
    if m.wifiIndexed = "" then m.wifiIndexed = "no"
    m.wifiRemoteSafe = AsText(result.remoteSafe)
    incoming = AsText(result.pngPath)
    if incoming <> "" then m.wifiFile = incoming
    NoteQrBytes("wifi", ResultNumber(result, "pngBytes"))
    PaintWifi()
end sub

function ResultNumber(result as object, key as string) as integer
    if result = invalid then return 0
    return GuideInt(result.Lookup(key))
end function

function QrDebugMarks() as boolean
    return false
end function

function QrMarkColor() as string
    if QrDebugMarks() then return "0xFF00FFFF"
    return "0xFFFFFFF2"
end function

function QrCaptionFont() as string
    return "font:SmallestBoldSystemFont"
end function

function QrCaptionColor() as string
    return AmberColor()
end function

function CheckoutTileRect() as object
    tileW = 362
    tileH = 164
    stride = 22
    originY = 480
    return {
        x: ContentLeft() + (2 * (tileW + stride)),
        y: originY + (tileH + stride),
        w: tileW,
        h: tileH
    }
end function

' Build 18 corner. The gold caption sits under the 128px QR, inside the card.
function BadgeCaptionColor() as string
    return "0x8A5A00FF"
end function

function BadgeFrame() as object
    return {
        x: 1304,
        y: 832,
        w: 520,
        h: 188,
        qrX: 196,
        qrY: 8,
        qr: 128,
        captionX: 12,
        captionY: 144,
        captionW: 496,
        captionH: 40
    }
end function

function BadgeCaptionRect() as object
    frame = BadgeFrame()
    return {
        x: frame.x + frame.captionX,
        y: frame.y + frame.captionY,
        w: frame.captionW,
        h: frame.captionH
    }
end function

function BadgePosterFailed() as boolean
    poster = PosterForSlot("badge")
    if poster = invalid then return false
    status = poster.loadStatus
    if status = "failed" or status = "error" then return true
    return false
end function

function DetailPhotoRect() as object
    return { x: ContentLeft(), y: ContentTop() + 140, w: 700, h: 260 }
end function

function DetailQrCardRect() as object
    return { x: ContentLeft() + 740, y: ContentTop() + 140, w: 280, h: 280 }
end function

function DetailBodyRect() as object
    return { x: ContentLeft(), y: ContentTop() + 472, w: ContentWidth(), h: 200 }
end function

function DetailQrPosterRect() as object
    card = DetailQrCardRect()
    return { x: card.x + 30, y: card.y + 36, w: 220, h: 200 }
end function

function DetailQrSiteRect() as object
    card = DetailQrCardRect()
    return { x: card.x + 16, y: card.y + 4, w: 248, h: 28 }
end function

function DetailQrCaptionRect() as object
    card = DetailQrCardRect()
    return { x: card.x, y: card.y + card.h - 32, w: card.w, h: 28 }
end function

function BookBodyRect() as object
    return { x: 588, y: 500, w: 680, h: 160 }
end function

function BookSavingsRect() as object
    return { x: 588, y: 668, w: 680, h: 112 }
end function

function BookPerkRow() as object
    return { x: ContentLeft(), y: 788, w: 1132, h: 88 }
end function

function RectOnScreen(rect as object) as boolean
    if rect = invalid then return false
    if rect.x < 0 or rect.y < 0 then return false
    if rect.w < 1 or rect.h < 1 then return false
    if rect.x + rect.w > 1920 then return false
    if rect.y + rect.h > 1080 then return false
    return true
end function

function ScreenRectText(rect as object) as string
    if rect = invalid then return "0,0 0x0"
    return rect.x.ToStr() + "," + rect.y.ToStr() + " " + rect.w.ToStr() + "x" + rect.h.ToStr()
end function

function RectsClear(a as object, b as object, gap as integer) as boolean
    if a = invalid or b = invalid then return false
    if a.x >= b.x + b.w + gap then return true
    if b.x >= a.x + a.w + gap then return true
    if a.y >= b.y + b.h + gap then return true
    if b.y >= a.y + a.h + gap then return true
    return false
end function

' Scan me card, poster, label, and domain. All of it sits inside the card
' and inside 1920x1080.
function BookQrSlot() as object
    cardX = 1296
    cardY = 292
    cardW = 360
    cardH = 280
    qrW = 220
    qrH = 180
    return {
        cardX: cardX,
        cardY: cardY,
        cardW: cardW,
        cardH: cardH,
        qrX: cardX + ((cardW - qrW) \ 2),
        qrY: cardY + ((cardH - qrH) \ 2),
        qrW: qrW,
        qrH: qrH,
        labelX: cardX,
        labelY: cardY + 4,
        labelW: cardW,
        labelH: 40,
        domainX: cardX,
        domainY: cardY + cardH - 48,
        domainW: cardW,
        domainH: 40
    }
end function

' True when the poster is centered in the Scan me card. Even sizes leave equal gaps.
function BookQrCentered(slot as object) as boolean
    if slot = invalid then return false
    leftGap = slot.qrX - slot.cardX
    rightGap = slot.cardX + slot.cardW - slot.qrX - slot.qrW
    if leftGap <> rightGap then return false
    topGap = slot.qrY - slot.cardY
    bottomGap = slot.cardY + slot.cardH - slot.qrY - slot.qrH
    if topGap <> bottomGap then return false
    if leftGap < 1 or topGap < 1 then return false
    return true
end function

function BookQrFits(slot as object) as boolean
    if slot = invalid then return false
    if slot.cardX < 0 or slot.cardY < 0 then return false
    if slot.cardX + slot.cardW > 1920 or slot.cardY + slot.cardH > 1080 then return false
    if InsideSlot(slot.qrX, slot.qrY, slot.qrW, slot.qrH, slot) <> true then return false
    if InsideSlot(slot.labelX, slot.labelY, slot.labelW, slot.labelH, slot) <> true then return false
    if InsideSlot(slot.domainX, slot.domainY, slot.domainW, slot.domainH, slot) <> true then return false
    return true
end function

function InsideSlot(x as integer, y as integer, width as integer, height as integer, slot as object) as boolean
    if x < slot.cardX or y < slot.cardY then return false
    if x + width > slot.cardX + slot.cardW then return false
    if y + height > slot.cardY + slot.cardH then return false
    return true
end function

function DetailQrUrl(item as object) as string
    qr = WithQrVersion(ItemText(item, "qrUrl"))
    if not PosterKindOk(qr) then qr = WithQrVersion(ItemText(item, "qrUri"))
    if not PosterKindOk(qr) then return ""
    return qr
end function

function PosterForSlot(slot as string) as object
    if slot = "badge" then return LivePoster("badgeQr", m.badgePoster)
    if slot = "book" then return LivePoster("bookQr", m.bookQr)
    if slot = "detail" then return LivePoster("detailQr", m.detailQr)
    if slot = "wifi" then return LivePoster("wifiQr", m.wifiPoster)
    return invalid
end function

function LivePoster(id as string, fallback as object) as object
    node = invalid
    if m.top <> invalid then node = m.top.findNode(id)
    if node <> invalid then return node
    return fallback
end function

sub RememberPoster(slot as string, node as object)
    if node = invalid then return
    if slot = "badge" then m.badgePoster = node
    if slot = "book" then m.bookQr = node
    if slot = "detail" then m.detailQr = node
    if slot = "wifi" then m.wifiPoster = node
end sub

function QrRetried(slot as string) as boolean
    if m.qrRetries = invalid then return false
    value = m.qrRetries.Lookup(slot)
    if value = invalid then return false
    return value = true
end function

sub MarkQrRetry(slot as string)
    if m.qrRetries = invalid then m.qrRetries = {}
    m.qrRetries[slot] = true
end sub

sub ClearQrRetry(slot as string)
    if m.qrRetries = invalid then m.qrRetries = {}
    m.qrRetries[slot] = false
end sub

function AssignedQrPath(slot as string) as string
    if m.qrAssigned = invalid then return ""
    value = m.qrAssigned.Lookup(slot)
    if value = invalid then return ""
    return value
end function

sub NoteAssigned(slot as string, path as string)
    if m.qrAssigned = invalid then m.qrAssigned = {}
    m.qrAssigned[slot] = path
end sub

sub ClearQrAssign(slot as string)
    ClearQrRetry(slot)
    NoteAssigned(slot, "")
end sub

function NotedQrBytes(slot as string) as integer
    if m.qrBytes = invalid then return 0
    value = m.qrBytes.Lookup(slot)
    if value = invalid then return 0
    return value
end function

sub NoteQrBytes(slot as string, bytes as integer)
    if m.qrBytes = invalid then m.qrBytes = {}
    m.qrBytes[slot] = bytes
end sub

sub ReassignStoredQrs()
    ApplyStoredQr("badge")
    ApplyStoredQr("book")
    ApplyStoredQr("detail")
end sub

function StoredQrPath(slot as string) as string
    if m.qrPaths = invalid then return ""
    value = m.qrPaths.Lookup(slot)
    if value = invalid then return ""
    return value
end function

sub ClearStoredQr(slot as string)
    if m.qrPaths = invalid then m.qrPaths = {}
    m.qrPaths[slot] = ""
end sub

sub EnsureQrSlot(slot as string, url as string)
    if url = invalid then url = ""
    if url <> QrRemote(slot)
        RememberQrRemote(slot, url)
        if slot = "badge"
            m.badgeFile = ""
            m.badgeReady = false
            m.badgeFailed = false
            if m.badgeMissing <> invalid then m.badgeMissing.text = ""
        end if
        if slot = "book"
            m.bookQrTried = false
            m.bookFile = ""
            if m.bookQrMissing <> invalid then m.bookQrMissing.text = ""
        end if
        if slot = "detail"
            m.detailQrFailed = false
            m.detailFile = ""
            if m.detailQrMissing <> invalid then m.detailQrMissing.text = ""
        end if
        ClearStoredQr(slot)
        ClearQrAssign(slot)
        if url <> "" then StartQrFetch(slot)
    end if
    ShowQrFrame(slot, url <> "")
    ApplyStoredQr(slot)
    if slot = "detail" then RevealDetailQr()
end sub

function QrRemote(slot as string) as string
    if slot = "badge"
        if m.badgeRemote = invalid then return ""
        return m.badgeRemote
    end if
    if slot = "book"
        if m.bookQrUri = invalid then return ""
        return m.bookQrUri
    end if
    if slot = "detail"
        if m.detailQrUri = invalid then return ""
        return m.detailQrUri
    end if
    return ""
end function

sub RememberQrRemote(slot as string, url as string)
    if slot = "badge"
        m.badgeRemote = url
        m.badgeUri = url
    end if
    if slot = "book" then m.bookQrUri = url
    if slot = "detail" then m.detailQrUri = url
end sub

sub ShowQrFrame(slot as string, show as boolean)
    if slot = "badge" then ShowBadgeFrame(show)
    if slot = "book" then ShowBookQr(show)
    if slot = "detail" then ShowDetailQr(show)
end sub

sub ShowQrMark(slot as string, show as boolean)
    mark = QrMarkForSlot(slot)
    if mark = invalid then return
    if show
        poster = PosterForSlot(slot)
        if poster <> invalid
            if poster.loadStatus = "ready" then show = false
        end if
    end if
    mark.visible = show
end sub

function QrMarkForSlot(slot as string) as object
    if slot = "badge" then return m.badgeMark
    if slot = "book" then return m.bookQrMark
    if slot = "detail" then return m.detailQrMark
    return invalid
end function

sub NoteQrLoaded(slot as string)
    poster = PosterForSlot(slot)
    if poster = invalid then return
    LogQrState(slot, poster)
    if poster.loadStatus <> "ready" then return
    if slot = "badge" then m.badgeReady = true
    poster.visible = true
    mark = QrMarkForSlot(slot)
    if mark <> invalid then mark.visible = false
end sub

sub RaiseBadge()
    if m.badgeGroup = invalid or m.shell = invalid then return
    m.shell.removeChild(m.badgeGroup)
    m.shell.appendChild(m.badgeGroup)
end sub

sub ApplyStoredQr(slot as string)
    path = StoredQrPath(slot)
    if path = "" then return
    ShowQrFrame(slot, true)
    AssignQrPoster(slot, path)
    if slot = "detail" then RevealDetailQr()
end sub

sub AssignQrPoster(slot as string, uri as string)
    if uri = invalid or uri = "" then return
    if m.qrPaths = invalid then m.qrPaths = {}
    m.qrPaths[slot] = uri
    if slot = "badge" then m.badgeFile = uri
    if slot = "book" then m.bookFile = uri
    if slot = "detail" then m.detailFile = uri
    poster = PosterForSlot(slot)
    nodeId = "none"
    found = "false"
    if poster <> invalid
        found = "true"
        if poster.id <> invalid and poster.id <> "" then nodeId = poster.id
    end if
    print "Eaglewood: qr "; slot; " deliver uri="; uri; " node="; nodeId; " found="; found
    if poster = invalid then return
    MountQrPoster(poster, uri, slot)
end sub

sub LogQrState(name as string, poster as object)
    status = "none"
    shown = "none"
    if poster <> invalid
        if poster.loadStatus <> invalid and poster.loadStatus <> "" then status = poster.loadStatus
        if poster.uri <> invalid and poster.uri <> "" then shown = SafeUri(poster.uri)
    end if
    print "Eaglewood: qr "; name; " uri="; shown; " status="; status; " rect="; QrRectText(poster)
end sub

function QrRectText(poster as object) as string
    if poster = invalid then return "0,0 0x0"
    bounds = poster.boundingRect()
    if bounds = invalid or bounds.width = invalid or bounds.height = invalid then return "0,0 0x0"
    x = 0
    y = 0
    if bounds.x <> invalid then x = bounds.x
    if bounds.y <> invalid then y = bounds.y
    return x.ToStr() + "," + y.ToStr() + " " + bounds.width.ToStr() + "x" + bounds.height.ToStr()
end function

sub LogQrScreen()
    if m.section = "wifi"
        print "Eaglewood: wifi response code="; m.wifiJsonCode
        print "Eaglewood: wifi png response code="; m.wifiPngCode
        print "Eaglewood: wifi png format bitdepth="; m.wifiPngBit; " colortype="; m.wifiPngColor; " interlace="; m.wifiPngInterlace; " indexed="; m.wifiIndexed
        LogQrState("wifi", m.wifiPoster)
    else if m.section = "book"
        LogQrState("book", PosterForSlot("book"))
        LogQrFormat("book")
    else if ActivitySection(m.section) and m.zone = "item"
        LogQrState("detail", PosterForSlot("detail"))
        LogQrFormat("detail")
    end if
    if m.section <> "book"
        LogQrState("badge", PosterForSlot("badge"))
        LogQrFormat("badge")
    end if
    LogCaptionLayout()
end sub

sub LogCaptionLayout()
    checkout = "0,0 0x0"
    if m.tiles <> invalid
        last = m.tiles.Count() - 1
        if last >= 0
            for index = 0 to last
                tile = m.tiles[index]
                if tile.section = "checkout" then checkout = QrRectText(tile.group)
            end for
        end if
    end if
    print "Eaglewood: caption badge rect="; QrRectText(m.badgeDomain); " book rect="; QrRectText(m.bookDomain); " checkout rect="; checkout
end sub

sub LogQrFormat(slot as string)
    text = ""
    if m.qrFormats <> invalid then text = AsText(m.qrFormats.Lookup(slot))
    if text <> "" then print "Eaglewood: qr "; slot; " format "; text
end sub

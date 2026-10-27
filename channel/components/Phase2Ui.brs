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
end sub

sub BuildHomePrompt(parent as object)
    if parent = invalid then return
    group = CreateObject("roSGNode", "Group")
    group.translation = [ContentLeft(), 316]
    m.promptOuter = AddRect(group, AmberColor(), 0, 0, 1132, 72)
    m.promptOuter.cornerRadius = 18
    m.promptInner = AddRect(group, "0xF4EFE3FF", 0, 0, 1132, 72)
    m.promptInner.cornerRadius = 18
    pine = CreateObject("roSGNode", "Poster")
    pine.uri = "pkg:/images/decor-pine.png"
    pine.width = 44
    pine.height = 32
    pine.loadWidth = 72
    pine.loadHeight = 48
    pine.translation = [18, 20]
    group.appendChild(pine)
    m.promptTitle = AddLabel(group, "Book direct & save", "font:SmallBoldSystemFont", "0x1B4D38FF", 74, 8, 820, 32)
    m.promptTitle.horizAlign = "left"
    m.promptSub = AddLabel(group, "", "font:SmallestSystemFont", "0x3E5348FF", 74, 36, 820, 28)
    m.promptSub.horizAlign = "left"
    arrow = AddRect(group, AmberColor(), 1064, 16, 40, 40)
    arrow.cornerRadius = 20
    arrowText = AddLabel(group, ">", "font:SmallBoldSystemFont", InkOnAmber(), 1064, 16, 40, 40)
    arrowText.horizAlign = "center"
    parent.appendChild(group)
    m.promptGroup = group
end sub

sub BuildBadge(parent as object)
    group = CreateObject("roSGNode", "Group")
    group.translation = [1508, 768]
    group.visible = false
    card = AddRect(group, "0xFFFFFFF2", 0, 0, 220, 204)
    card.cornerRadius = 16
    m.badgeLabel = AddLabel(group, "Book direct", "font:SmallBoldSystemFont", "0x1B4D38FF", 8, 4, 204, 28)
    m.badgeLabel.horizAlign = "center"
    m.badgePoster = CreateObject("roSGNode", "Poster")
    m.badgePoster.translation = [32, 34]
    m.badgePoster.width = 156
    m.badgePoster.height = 156
    m.badgePoster.loadWidth = 156
    m.badgePoster.loadHeight = 156
    m.badgePoster.loadDisplayMode = "scaleToFit"
    group.appendChild(m.badgePoster)
    m.badgePoster.observeField("loadStatus", "onBadgeStatus")
    m.badgeDomain = AddLabel(group, DisplayDomain(), "font:SmallestBoldSystemFont", "0x146B3AFF", 8, 168, 204, 28)
    m.badgeDomain.horizAlign = "center"
    parent.appendChild(group)
    m.badgeGroup = group
    m.badgeHint = AddLabel(parent, "", "font:SmallSystemFont", MuteColor(), 980, 860, 500, 32)
    m.badgeHint.horizAlign = "right"
    m.badgeHint.visible = false
    m.badgeUri = ""
end sub

function BuildBookPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    panel = AddRect(pane, "0xF4EFE3FF", 540, 36, 1320, 1000)
    panel.cornerRadius = 28
    pines = CreateObject("roSGNode", "Poster")
    pines.uri = "pkg:/images/decor-pine.png"
    pines.translation = [588, 78]
    pines.width = 72
    pines.height = 48
    pines.loadWidth = 72
    pines.loadHeight = 48
    pane.appendChild(pines)
    heart = CreateObject("roSGNode", "Poster")
    heart.uri = "pkg:/images/decor-heart.png"
    heart.translation = [1548, 78]
    heart.width = 48
    heart.height = 48
    heart.loadWidth = 48
    heart.loadHeight = 48
    pane.appendChild(heart)
    m.bookLines = []
    for index = 0 to 2
        label = AddLabel(pane, "", "font:MediumBoldSystemFont", "0x1B4D38FF", 676, 64 + (index * 44), 840, 44)
        label.horizAlign = "left"
        m.bookLines.Push(label)
    end for
    banner = AddRect(pane, "0x1B4D38FF", 588, 214, 620, 64)
    banner.cornerRadius = 18
    bannerText = AddLabel(pane, "", "font:MediumBoldSystemFont", InkColor(), 588, 214, 620, 64)
    bannerText.horizAlign = "center"
    m.bookBanner = bannerText
    m.bookPhoto = CreateObject("roSGNode", "Poster")
    m.bookPhoto.translation = [588, 300]
    m.bookPhoto.width = 680
    m.bookPhoto.height = 300
    m.bookPhoto.loadWidth = 680
    m.bookPhoto.loadHeight = 360
    m.bookPhoto.loadDisplayMode = "scaleToZoom"
    m.bookPhoto.failedBitmapUri = PlaceholderPoster()
    pane.appendChild(m.bookPhoto)
    m.bookPhoto.observeField("loadStatus", "onBookPhotoStatus")
    qrCard = AddRect(pane, "0x1B4D38FF", 1296, 300, 300, 360)
    qrCard.cornerRadius = 16
    scan = AddLabel(pane, "Scan me!", "font:SmallBoldSystemFont", InkColor(), 1296, 308, 300, 32)
    scan.horizAlign = "center"
    m.bookQr = CreateObject("roSGNode", "Poster")
    m.bookQr.translation = [1336, 348]
    m.bookQr.width = 220
    m.bookQr.height = 220
    m.bookQr.loadWidth = 220
    m.bookQr.loadHeight = 220
    m.bookQr.loadDisplayMode = "scaleToFit"
    pane.appendChild(m.bookQr)
    m.bookQr.observeField("loadStatus", "onBookQrStatus")
    m.bookDomain = AddLabel(pane, DisplayDomain(), "font:SmallBoldSystemFont", AmberColor(), 1312, 578, 268, 32)
    m.bookDomain.horizAlign = "center"
    m.bookQrMissing = AddLabel(pane, "", "font:SmallestSystemFont", AmberColor(), 1312, 612, 268, 36)
    m.bookQrMissing.horizAlign = "center"
    m.bookBody = AddLabel(pane, "", "font:SmallSystemFont", "0x1C2A24FF", 588, 616, 680, 88)
    m.bookBody.vertAlign = "top"
    m.bookSavings = AddLabel(pane, "", "font:SmallBoldSystemFont", "0x1B4D38FF", 588, 708, 680, 72)
    m.bookSavings.vertAlign = "top"
    m.perkGroups = []
    for index = 0 to 4
        chip = CreateObject("roSGNode", "Group")
        chip.translation = [ContentLeft() + (index * 214), 792]
        bg = AddRect(chip, "0x1B4D38FF", 0, 0, 200, 48)
        bg.cornerRadius = 16
        text = AddLabel(chip, "", "font:SmallestBoldSystemFont", InkColor(), 8, 0, 184, 48)
        text.horizAlign = "center"
        pane.appendChild(chip)
        m.perkGroups.Push({ group: chip, bg: bg, text: text })
    end for
    m.bookSign = AddLabel(pane, "", "font:SmallBoldSystemFont", "0x2C4A6EFF", 1288, 860, 300, 36)
    m.bookSign.horizAlign = "right"
    ridges = CreateObject("roSGNode", "Poster")
    ridges.uri = "pkg:/images/decor-ridges.png"
    ridges.translation = [560, 948]
    ridges.width = 1280
    ridges.height = 80
    ridges.loadWidth = 1280
    ridges.loadHeight = 88
    pane.appendChild(ridges)
    m.bookPhotoUri = ""
    m.bookQrUri = ""
    return pane
end function

function BuildWifiPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    AddLabel(pane, "Join the Wi-Fi", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 64)
    backing = AddRect(pane, "0xFFFFFFFF", ContentLeft(), ContentTop() + 96, 420, 420)
    backing.cornerRadius = 24
    m.wifiPoster = CreateObject("roSGNode", "Poster")
    m.wifiPoster.translation = [ContentLeft() + 30, ContentTop() + 126]
    m.wifiPoster.width = 360
    m.wifiPoster.height = 360
    m.wifiPoster.loadWidth = 480
    m.wifiPoster.loadHeight = 480
    m.wifiPoster.loadDisplayMode = "scaleToFit"
    pane.appendChild(m.wifiPoster)
    m.wifiMissing = AddLabel(pane, "", "font:SmallSystemFont", "0x1C1408FF", ContentLeft() + 24, ContentTop() + 250, 372, 80)
    m.wifiMissing.horizAlign = "center"
    textX = ContentLeft() + 460
    AddLabel(pane, "Network", "font:SmallSystemFont", MuteColor(), textX, ContentTop() + 110, 640, 32)
    m.wifiSsidLabel = AddLabel(pane, "", "font:MediumBoldSystemFont", InkColor(), textX, ContentTop() + 146, 640, 56)
    AddLabel(pane, "Password", "font:SmallSystemFont", MuteColor(), textX, ContentTop() + 220, 640, 32)
    m.wifiPasswordLabel = AddLabel(pane, "", "font:MediumBoldSystemFont", InkColor(), textX, ContentTop() + 256, 640, 56)
    m.wifiHint = AddLabel(pane, "Point your phone camera at the code and tap the banner to join.", "font:SmallSystemFont", MuteColor(), textX, ContentTop() + 340, 640, 72)
    m.wifiHint.vertAlign = "top"
    m.wifiRouter = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), 860, 900, 64)
    m.wifiRouter.vertAlign = "top"
    m.wifiShown = ""
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
    grid.itemSize = [364, 252]
    grid.itemSpacing = [18, 16]
    grid.numColumns = 3
    grid.numRows = 2
    grid.drawFocusFeedback = false
    grid.focusable = false
    grid.vertFocusAnimationStyle = "floatingFocus"
    pane.appendChild(grid)
    m.activityGrid = grid
    m.activityEmpty = AddLabel(pane, "Nothing to show yet.", "font:MediumSystemFont", MuteColor(), ContentLeft(), ContentTop() + 180, ContentWidth(), 48)
    m.activityEmpty.visible = false
    m.activityHint = AddLabel(pane, "Left menu    Arrows browse    OK open", "font:SmallSystemFont", MuteColor(), ContentLeft(), 752, 900, 32)
    return pane
end function

function BuildDetailPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    m.detailName = AddLabel(pane, "", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), 760, 64)
    m.detailPhoto = CreateObject("roSGNode", "Poster")
    m.detailPhoto.translation = [ContentLeft(), ContentTop() + 78]
    m.detailPhoto.width = 700
    m.detailPhoto.height = 320
    m.detailPhoto.loadWidth = 640
    m.detailPhoto.loadHeight = 360
    m.detailPhoto.loadDisplayMode = "scaleToZoom"
    m.detailPhoto.failedBitmapUri = PlaceholderPoster()
    pane.appendChild(m.detailPhoto)
    m.detailPhoto.observeField("loadStatus", "onDetailPhotoStatus")
    m.detailQrCard = AddRect(pane, "0xFFFFFFF2", ContentLeft() + 740, ContentTop() + 78, 280, 360)
    m.detailQrCard.cornerRadius = 18
    place = AddLabel(pane, "This place", "font:SmallBoldSystemFont", "0x1C1408FF", ContentLeft() + 756, ContentTop() + 88, 248, 28)
    place.horizAlign = "center"
    site = AddLabel(pane, "Website / menu", "font:SmallSystemFont", "0x1C1408FF", ContentLeft() + 756, ContentTop() + 116, 248, 28)
    site.horizAlign = "center"
    m.detailQr = CreateObject("roSGNode", "Poster")
    m.detailQr.translation = [ContentLeft() + 780, ContentTop() + 152]
    m.detailQr.width = 200
    m.detailQr.height = 200
    m.detailQr.loadWidth = 280
    m.detailQr.loadHeight = 280
    m.detailQr.loadDisplayMode = "scaleToFit"
    pane.appendChild(m.detailQr)
    m.detailQr.observeField("loadStatus", "onDetailQrStatus")
    m.detailQrCaption = AddLabel(pane, "", "font:SmallestSystemFont", "0x1C1408FF", ContentLeft() + 756, ContentTop() + 360, 248, 32)
    m.detailQrCaption.horizAlign = "center"
    m.detailQrMissing = AddLabel(pane, "", "font:SmallestSystemFont", "0x1C1408FF", ContentLeft() + 756, ContentTop() + 392, 248, 36)
    m.detailQrMissing.horizAlign = "center"
    m.detailMeta = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 412, 700, 32)
    m.detailBody = AddLabel(pane, "", "font:SmallSystemFont", InkColor(), ContentLeft(), ContentTop() + 448, 700, 140)
    m.detailBody.vertAlign = "top"
    m.detailTip = AddLabel(pane, "", "font:SmallBoldSystemFont", AmberColor(), ContentLeft(), ContentTop() + 592, 700, 64)
    m.detailTip.vertAlign = "top"
    m.detailExtra = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 660, 700, 64)
    m.detailExtra.vertAlign = "top"
    m.detailCredit = AddLabel(pane, "", "font:SmallestSystemFont", MuteColor(), ContentLeft(), 860, ContentWidth(), 32)
    m.detailBack = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), 900, 700, 32)
    m.detailPhotoUri = ""
    m.detailQrUri = ""
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
    m.promptTitle.text = BookText(m.book, "homePromptTitle", "Book direct & save")
    m.promptSub.text = PromptSubline(BookText(m.book, "homePromptSub", "Up to about 10% less than Airbnb or Vrbo"))
    focused = (m.zone = "prompt" and m.section = "home")
    if m.promptInner = invalid then return
    if focused
        m.promptInner.translation = [4, 4]
        m.promptInner.width = 1124
        m.promptInner.height = 64
    else
        m.promptInner.translation = [0, 0]
        m.promptInner.width = 1132
        m.promptInner.height = 72
    end if
end sub

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
    if m.badgePoster = invalid or m.badgeGroup = invalid then return
    uri = ""
    if IsAssoc(m.book) then uri = GuideLimitedText(m.book.Lookup("bookingQrImageUrl"), 240)
    if not PosterKindOk(uri) then uri = ""
    if uri <> m.badgeUri
        m.badgeUri = uri
        m.badgeReady = false
        m.badgePoster.loadWidth = 156
        m.badgePoster.loadHeight = 156
        m.badgePoster.uri = uri
    end if
    if m.badgeDomain <> invalid then m.badgeDomain.text = DisplayDomain()
    UpdateBadgeVisible()
end sub

sub onBadgeStatus()
    if m.badgePoster = invalid then return
    status = m.badgePoster.loadStatus
    if status = "ready" then m.badgeReady = true
    if status = "failed" or status = "error" then m.badgeReady = false
    UpdateBadgeVisible()
end sub

sub UpdateBadgeVisible()
    if m.badgeGroup = invalid then return
    show = (m.badgeReady = true and m.section <> "book" and m.badgeUri <> "")
    m.badgeGroup.visible = show
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
    qr = GuideLimitedText(m.book.Lookup("qrImageUrl"), 240)
    if qr <> m.bookQrUri and m.bookQr <> invalid
        m.bookQrUri = qr
        m.bookQrTried = false
        m.bookQr.loadWidth = 220
        m.bookQr.loadHeight = 220
        m.bookQr.uri = qr
        if m.bookQrMissing <> invalid then m.bookQrMissing.text = ""
    end if
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
    colors = ["0x1B4D38FF", "0xF2A93BFF", "0xC96A32FF", "0x1B4D38FF", "0xF2A93BFF"]
    inks = [InkColor(), InkOnAmber(), InkColor(), InkColor(), InkOnAmber()]
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

sub onBookQrStatus()
    if m.bookQr = invalid or m.bookQrMissing = invalid then return
    status = m.bookQr.loadStatus
    if status = "ready"
        m.bookQrMissing.text = ""
        return
    end if
    if status <> "failed" and status <> "error" then return
    m.bookQrMissing.text = "Link unavailable offline."
end sub

sub PaintWifi()
    if m.wifiSsidLabel = invalid then return
    notice = ""
    if m.wifiNotice <> invalid then notice = m.wifiNotice
    ssid = ""
    if m.wifiSsid <> invalid then ssid = m.wifiSsid
    password = ""
    if m.wifiPassword <> invalid then password = m.wifiPassword
    if notice = "coming-soon" and ssid = ""
        m.wifiSsidLabel.text = ComingSoonWifi()
        m.wifiPasswordLabel.text = ""
    else if ssid = ""
        m.wifiSsidLabel.text = WifiFallbackText()
        m.wifiPasswordLabel.text = ""
    else
        m.wifiSsidLabel.text = ssid
        m.wifiPasswordLabel.text = password
    end if
    if m.wifiRouter <> invalid then m.wifiRouter.text = RouterStep(m.issues)
    pngReady = (m.wifiPng = "yes")
    if m.wifiPoster = invalid then return
    path = "cachefs:/eaglewood/wifi.png"
    if pngReady
        if m.wifiShown <> path
            m.wifiShown = path
            m.wifiPoster.loadWidth = 480
            m.wifiPoster.loadHeight = 480
            m.wifiPoster.uri = ""
            m.wifiPoster.uri = path
        end if
        m.wifiPoster.visible = true
        if m.wifiMissing <> invalid then m.wifiMissing.text = ""
    else
        m.wifiPoster.visible = false
        m.wifiShown = ""
        if m.wifiMissing <> invalid
            if notice = "coming-soon" then m.wifiMissing.text = ComingSoonWifi()
            else m.wifiMissing.text = "Join code unavailable"
        end if
    end if
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
    if m.activityEmpty <> invalid then m.activityEmpty.visible = (count = 0)
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
    return GuideLimitedText(item.Lookup(key), 180)
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
    item = invalid
    if m.cardIndex >= 0 and m.cardIndex < CardCount() then item = m.sortedCards[m.cardIndex]
    if m.detailName <> invalid then m.detailName.text = ItemText(item, "name")
    if m.detailMeta <> invalid then m.detailMeta.text = DetailMeta(item)
    if m.detailBody <> invalid then m.detailBody.text = ItemText(item, "description")
    if m.detailTip <> invalid
        tip = ItemText(item, "tip")
        if tip = "" then m.detailTip.text = ""
        else m.detailTip.text = "Tip: " + tip
    end if
    if m.detailExtra <> invalid then m.detailExtra.text = DetailExtra(item)
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
    qr = ItemText(item, "qrUri")
    showQr = (qr <> "")
    if m.detailQrCard <> invalid then m.detailQrCard.visible = showQr
    if m.detailQr <> invalid then m.detailQr.visible = showQr
    if m.detailQrCaption <> invalid then m.detailQrCaption.visible = showQr
    if m.detailQrMissing <> invalid then m.detailQrMissing.visible = showQr
    if not showQr then return
    if m.detailQrCaption <> invalid
        if m.section = "dining" then m.detailQrCaption.text = "Scan for this restaurant"
        else m.detailQrCaption.text = "Scan for this place"
    end if
    if m.detailQr <> invalid and qr <> m.detailQrUri
        m.detailQrUri = qr
        m.detailQrFailed = false
        m.detailQr.loadWidth = 280
        m.detailQr.loadHeight = 280
        m.detailQr.uri = qr
        if m.detailQrMissing <> invalid then m.detailQrMissing.text = ""
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
    item = invalid
    if m.cardIndex >= 0 and m.cardIndex < CardCount() then item = m.sortedCards[m.cardIndex]
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
    if m.detailQr = invalid or m.detailQrMissing = invalid then return
    status = m.detailQr.loadStatus
    if status = "ready"
        m.detailQrMissing.text = ""
        m.detailQr.visible = true
        return
    end if
    if status <> "failed" and status <> "error" then return
    m.detailQr.visible = false
    m.detailQrMissing.text = "Link unavailable offline."
end sub

sub ApplyWifiResult(result as object)
    if result = invalid then return
    m.wifiSsid = AsText(result.ssid)
    m.wifiPassword = AsText(result.password)
    m.wifiPng = AsText(result.png)
    if m.wifiPng = "" then m.wifiPng = "no"
    m.wifiSource = AsText(result.source)
    m.wifiNotice = AsText(result.notice)
    m.wifiShown = ""
    PaintWifi()
end sub

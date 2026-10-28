sub init()
    m.photo = m.top.findNode("photo")
    m.swatch = m.top.findNode("swatch")
    m.ring = m.top.findNode("ring")
    m.nameLabel = m.top.findNode("name")
    m.distanceLabel = m.top.findNode("distance")
    m.chip = m.top.findNode("chip")
    m.chipText = m.top.findNode("chipText")
    m.bound = invalid
    m.shown = ""
    m.triedFallback = false
    if m.photo <> invalid
        m.photo.loadWidth = 354
        m.photo.loadHeight = 150
        m.photo.observeField("loadStatus", "onPhotoStatus")
    end if
end sub

sub onItemContent()
    if m.bound <> invalid
        m.bound.unobserveField("imageUri")
        m.bound.unobserveField("cardFocused")
        m.bound.unobserveField("imageFallback")
    end if
    m.bound = m.top.itemContent
    m.triedFallback = false
    m.shown = ""
    if m.bound <> invalid
        m.bound.observeField("imageUri", "paintCard")
        m.bound.observeField("cardFocused", "paintCard")
        m.bound.observeField("imageFallback", "paintCard")
    end if
    paintCard()
end sub

sub paintCard()
    content = m.bound
    title = ""
    distance = ""
    season = ""
    swatch = "0x5C4033FF"
    focused = false
    uri = ""
    if content <> invalid
        if content.title <> invalid then title = content.title
        if content.distance <> invalid then distance = content.distance
        if content.seasonLabel <> invalid then season = content.seasonLabel
        if content.swatch <> invalid and content.swatch <> "" then swatch = content.swatch
        if content.cardFocused = true then focused = true
        if content.imageUri <> invalid then uri = content.imageUri
    end if
    if m.ring <> invalid then m.ring.visible = focused
    if m.swatch <> invalid then m.swatch.color = swatch
    if m.nameLabel <> invalid then m.nameLabel.text = title
    if m.distanceLabel <> invalid then m.distanceLabel.text = distance
    PaintChip(SeasonChipText(season))
    ShowPoster(uri)
end sub

function SeasonChipText(season as string) as string
    if season = invalid then return ""
    return season
end function

function ChipWidthFor(season as string) as integer
    if season = invalid or season = "" then return 0
    return 332
end function

sub PaintChip(season as string)
    if m.chip = invalid or m.chipText = invalid then return
    if season = invalid or season = ""
        m.chip.visible = false
        m.chipText.visible = false
        m.chipText.text = ""
        return
    end if
    width = ChipWidthFor(season)
    m.chip.width = width
    m.chipText.width = width
    m.chip.visible = true
    m.chipText.visible = true
    m.chipText.text = season
end sub

sub ShowPoster(uri as string)
    if m.photo = invalid then return
    if uri = invalid then uri = ""
    if uri = m.shown then return
    m.shown = uri
    m.triedFallback = false
    m.photo.loadWidth = 354
    m.photo.loadHeight = 150
    if uri = ""
        m.photo.uri = "pkg:/images/tv-placeholder.jpg"
        return
    end if
    m.photo.uri = uri
end sub

sub onPhotoStatus()
    if m.photo = invalid then return
    status = m.photo.loadStatus
    if status <> "failed" and status <> "error" then return
    if m.triedFallback = true
        UsePlaceholder()
        return
    end if
    m.triedFallback = true
    fallback = ""
    if m.bound <> invalid and m.bound.imageFallback <> invalid then fallback = m.bound.imageFallback
    if fallback <> "" and fallback <> m.shown
        m.shown = fallback
        m.photo.loadWidth = 354
        m.photo.loadHeight = 150
        m.photo.uri = fallback
        return
    end if
    UsePlaceholder()
end sub

sub UsePlaceholder()
    if m.photo = invalid then return
    held = "pkg:/images/tv-placeholder.jpg"
    if m.shown = held then return
    m.shown = held
    m.photo.loadWidth = 64
    m.photo.loadHeight = 64
    m.photo.uri = held
end sub

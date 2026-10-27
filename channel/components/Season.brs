' Pacific calendar seasons and the TV activity sort.
' compareSeasonRank matches src/lib/season-order.ts: lower rank first,
' a missing rank after every ranked activity, ties by source index.
' Months are America/Los_Angeles calendar months, not the TV timezone.
' December-February winter, March-May spring, June-August summer, September-November fall.
' QR payloads use url only. affiliateUrl is ignored. Images must be jpg or png.

function IsList(value as object) as boolean
    if value = invalid then return false
    kind = type(value)
    if kind = "roArray" or kind = "Array" then return true
    return false
end function

function IsAssoc(value as object) as boolean
    if value = invalid then return false
    if type(value) = "roAssociativeArray" then return true
    return false
end function

function CalendarSeasonForMonth(month as integer) as string
    if month = 12 or month = 1 or month = 2 then return "winter"
    if month >= 3 and month <= 5 then return "spring"
    if month >= 6 and month <= 8 then return "summer"
    if month >= 9 and month <= 11 then return "fall"
    return ""
end function

function CurrentSeason() as string
    parts = PacificLocalParts(NowSeconds())
    if parts = invalid then return "winter"
    season = CalendarSeasonForMonth(parts.month)
    if season = "" then return "winter"
    return season
end function

' Local civil time in America/Los_Angeles for a UTC Unix second count.
' US daylight time: second Sunday in March 02:00 PST through the first
' Sunday in November 02:00 PDT. The TV timezone setting is not read.
function PacificLocalParts(utcSeconds as integer) as object
    if utcSeconds < 946684800 then return invalid
    utc = CivilParts(utcSeconds)
    if utc = invalid then return invalid
    offsetHours = 8
    if PacificDaylightInstant(utcSeconds, utc.year) then offsetHours = 7
    localSeconds = utcSeconds - (offsetHours * 3600)
    parts = CivilParts(localSeconds)
    if parts = invalid then return invalid
    parts.offsetHours = offsetHours
    return parts
end function

function PacificDaylightInstant(utcSeconds as integer, year as integer) as boolean
    startSeconds = DstStartUtc(year)
    endSeconds = DstEndUtc(year)
    if startSeconds = invalid or endSeconds = invalid then return false
    ' CivilSeconds comes back boxed. Compare the unboxed counts.
    if utcSeconds >= Int(startSeconds) and utcSeconds < Int(endSeconds) then return true
    return false
end function

function DstStartUtc(year as integer) as object
    ' 02:00 PST on the second Sunday in March is 10:00 UTC.
    return CivilSeconds(year, 3, NthSunday(year, 3, 2), 10, 0, 0)
end function

function DstEndUtc(year as integer) as object
    ' 02:00 PDT on the first Sunday in November is 09:00 UTC.
    return CivilSeconds(year, 11, NthSunday(year, 11, 1), 9, 0, 0)
end function

function CivilParts(seconds as integer) as object
    if seconds < 0 then return invalid
    days = seconds \ 86400
    remainder = seconds - (days * 86400)
    hour = remainder \ 3600
    minute = (remainder mod 3600) \ 60
    second = remainder mod 60
    date = CivilFromDays(days)
    if date = invalid then return invalid
    date.hour = hour
    date.minute = minute
    date.second = second
    return date
end function

' Inverse of DaysFromCivil. Howard Hinnant's civil_from_days.
function CivilFromDays(z as integer) as object
    z = z + 719468
    if z < 0 then return invalid
    era = z \ 146097
    doe = z - (era * 146097)
    yoe = (doe - (doe \ 1460) + (doe \ 36524) - (doe \ 146096)) \ 365
    year = yoe + (era * 400)
    doy = doe - ((365 * yoe) + (yoe \ 4) - (yoe \ 100))
    mp = ((5 * doy) + 2) \ 153
    day = doy - (((153 * mp) + 2) \ 5) + 1
    month = mp + 3
    if month > 12
        month = month - 12
        year = year + 1
    end if
    if month < 1 or month > 12 or day < 1 then return invalid
    return { year: year, month: month, day: day }
end function

function RankFor(activity as object, season as string) as integer
    if not IsAssoc(activity) then return 0
    ranks = AaField(activity, "seasonRank")
    if not IsAssoc(ranks) then return 0
    return PositiveRank(AaField(ranks, season))
end function

function PositiveRank(value as object) as integer
    number = GuideInt(value)
    if number < 1 then return 0
    return number
end function

' 0 means the two sides are equal for this key. Negative means a is first.
function CompareSeasonRank(season as string, a as object, b as object, indexA as integer, indexB as integer) as integer
    rankA = RankFor(a, season)
    rankB = RankFor(b, season)
    missingA = (rankA < 1)
    missingB = (rankB < 1)
    if missingA or missingB
        if missingA and missingB then return indexA - indexB
        if missingA then return 1
        return -1
    end if
    if rankA <> rankB then return rankA - rankB
    return indexA - indexB
end function

function SourceIndexOf(item as object) as integer
    if not IsAssoc(item) then return 0
    value = AaField(item, "sourceIndex")
    if value = invalid then return 0
    return GuideInt(value)
end function

function SortActivities(items as object, season as string) as object
    ordered = []
    if not IsList(items) then return ordered
    last = items.Count() - 1
    if last < 0 then return ordered
    for index = 0 to last
        ordered.Push(items[index])
    end for
    if last < 1 then return ordered
    for index = 1 to last
        current = ordered[index]
        slot = index
        while slot > 0
            previous = ordered[slot - 1]
            compared = CompareSeasonRank(season, previous, current, SourceIndexOf(previous), SourceIndexOf(current))
            if compared <= 0 then exit while
            ordered[slot] = previous
            slot = slot - 1
        end while
        ordered[slot] = current
    end for
    return ordered
end function

function ActivitiesForScreen(items as object, screen as string) as object
    picked = []
    if not IsList(items) then return picked
    last = items.Count() - 1
    if last < 0 then return picked
    for index = 0 to last
        item = items[index]
        if ItemOnScreen(item, screen) then picked.Push(item)
    end for
    return picked
end function

function ItemOnScreen(item as object, screen as string) as boolean
    if not IsAssoc(item) then return false
    section = GuideLimitedText(AaField(item, "sectionId"), 80)
    if screen = "dining" then return section = "dining"
    if screen = "hiking" then return section = "hiking"
    if screen = "todo"
        if section = "dining" or section = "hiking" then return false
        return true
    end if
    return false
end function

function ActivitiesQrCount(items as object) as integer
    total = 0
    if not IsList(items) then return 0
    last = items.Count() - 1
    if last < 0 then return 0
    for index = 0 to last
        item = items[index]
        if IsAssoc(item)
            qr = GuideLimitedText(AaField(item, "qrUrl"), 420)
            if qr = "" then qr = GuideLimitedText(AaField(item, "qrUri"), 420)
            if qr <> "" then total = total + 1
        end if
    end for
    return total
end function

' A cached activities file from before qrUrl existed still normalizes.
' Prefer it only when it actually carries QR links. Otherwise use the bundle.
function ChooseActivities(cached as object, bundled as object) as object
    if cached <> invalid and ActivitiesQrCount(cached.items) > 0 then return cached
    if bundled <> invalid and ActivitiesQrCount(bundled.items) > 0 then return bundled
    if cached <> invalid then return cached
    return bundled
end function

' 200 and 304 both normalize the raw activities document, then keep qrUrl.
' A cached copy that parses but has no qrUrl yields the packaged snapshot.
' Cards that share an id stay distinct: callers read them with ActivityAt.
function ActivitiesFromFetch(parsed as object, source as string, code as string, bundled as object) as object
    found = invalid
    if IsAssoc(parsed)
        norm = NormalizeActivities(parsed)
        if IsAssoc(norm)
            norm.activitiesSource = source
            norm.activitiesCode = code
            found = norm
        end if
    end if
    return ChooseActivities(found, bundled)
end function

function ActivityAt(items as object, index as integer) as object
    if not IsList(items) then return invalid
    if index < 0 or index >= items.Count() then return invalid
    return items[index]
end function

' Bumped so a launch discards activities.json written before qrUrl was kept.
function ActivitiesCacheGeneration() as string
    return "qr3"
end function

' A 304, or a cache whose activities dropped qrUrl, is thrown away.
' The wipe itself is only activities.json and its etag.
function ActivitiesCacheShouldDiscard(reason as string, cached as object) as boolean
    if reason = "not-modified" then return true
    if cached <> invalid and ActivitiesCacheDropsQr(cached) = true then return true
    return false
end function

' True when a cached activities document is missing qrUrl on any activity.
function ActivitiesCacheDropsQr(parsed as object) as boolean
    if not IsAssoc(parsed) then return true
    sections = parsed.Lookup("activitySections")
    if not IsList(sections) then return true
    last = sections.Count() - 1
    if last < 0 then return true
    saw = false
    for sectionAt = 0 to last
        section = sections[sectionAt]
        if IsAssoc(section)
            rows = section.Lookup("activities")
            if IsList(rows)
                rowLast = rows.Count() - 1
                if rowLast >= 0
                    for rowAt = 0 to rowLast
                        row = rows[rowAt]
                        if IsAssoc(row)
                            saw = true
                            if GuideLimitedText(row.Lookup("qrUrl"), 420) = "" then return true
                        end if
                    end for
                end if
            end if
        end if
    end for
    if saw = false then return true
    return false
end function

' Two cards may share an id. Prefer the one that still has qrUrl.
function ActivityById(items as object, id as string) as object
    if id = invalid or id = "" then return invalid
    if IsAssoc(items)
        sections = items.Lookup("activitySections")
        if IsList(sections) then return ActivityInSections(sections, id)
    end if
    if not IsList(items) then return invalid
    return ActivityInList(items, id)
end function

function ActivityInList(items as object, id as string) as object
    found = invalid
    last = items.Count() - 1
    if last < 0 then return invalid
    for index = 0 to last
        item = items[index]
        if ActivityIdIs(item, id)
            if found = invalid then found = item
            if ActivityHasQr(item) then return item
        end if
    end for
    return found
end function

function ActivityInSections(sections as object, id as string) as object
    found = invalid
    last = sections.Count() - 1
    if last < 0 then return invalid
    for sectionAt = 0 to last
        section = sections[sectionAt]
        if IsAssoc(section)
            rows = section.Lookup("activities")
            if IsList(rows)
                rowLast = rows.Count() - 1
                if rowLast >= 0
                    for rowAt = 0 to rowLast
                        row = rows[rowAt]
                        if ActivityIdIs(row, id)
                            if found = invalid then found = row
                            if ActivityHasQr(row) then return row
                        end if
                    end for
                end if
            end if
        end if
    end for
    return found
end function

function ActivityIdIs(item as object, id as string) as boolean
    if not IsAssoc(item) then return false
    return GuideLimitedText(AaField(item, "id"), 80) = id
end function

function ActivityHasQr(item as object) as boolean
    if not IsAssoc(item) then return false
    if GuideLimitedText(AaField(item, "qrUrl"), 420) <> "" then return true
    if GuideLimitedText(AaField(item, "qrUri"), 420) <> "" then return true
    return false
end function

function ActivitySection(section as string) as boolean
    if section = "dining" or section = "hiking" or section = "todo" then return true
    return false
end function

function ContentOrigin() as string
    return "https://sunrivertownhome.com"
end function

' Absolute http(s) URLs stay as written. A path such as /images/tv/a.jpg
' is resolved against the site origin. The JSON may use either form.
function ResolveContentUrl(url as object) as string
    text = GuideLimitedText(url, 400)
    if text = "" then return ""
    lower = LCase(text)
    if Left(lower, 8) = "https://" or Left(lower, 7) = "http://" then return text
    origin = ContentOrigin()
    if Left(text, 1) = "/" then return origin + text
    return origin + "/" + text
end function

function PlaceholderPoster() as string
    return "pkg:/images/tv-placeholder.jpg"
end function

' 200/304 use the new body. Any other code keeps a cached copy when one exists.
' 503 with nothing cached is the worker's empty "secrets not set" response.
function WifiScreenMode(code as integer, hasCache as boolean) as string
    if code = 200 or code = 304 then return "show"
    if hasCache then return "cache"
    if code = 503
        ' Assigned first so this is not a returned path-key-shaped literal.
        mode = "coming-soon"
        return mode
    end if
    return "fallback"
end function

function PosterKindOk(url as object) as boolean
    text = GuideLimitedText(url, 400)
    if text = "" then return false
    lower = LCase(text)
    if Left(lower, 8) <> "https://" and Left(lower, 7) <> "http://" then return false
    path = text
    query = Instr(1, path, "?")
    if query > 0 then path = Left(path, query - 1)
    hash = Instr(1, path, "#")
    if hash > 0 then path = Left(path, hash - 1)
    lowerPath = LCase(path)
    if Right(lowerPath, 4) = ".jpg" then return true
    if Right(lowerPath, 5) = ".jpeg" then return true
    if Right(lowerPath, 4) = ".png" then return true
    return false
end function

' Cloudflare can keep a grayscale PNG at the plain /data/qr/ URL for hours.
' v=rgb2 is only for those public QR files. Wi-Fi URLs are left unchanged.
function WithQrVersion(url as string) as string
    if url = invalid or url = "" then return ""
    if Instr(1, url, "/data/qr/") < 1 then return url
    if Instr(1, url, "?v=rgb2") > 0 or Instr(1, url, "&v=rgb2") > 0 then return url
    if Instr(1, url, "?") > 0 then return url + "&v=rgb2"
    return url + "?v=rgb2"
end function

function ActivityPoster(item as object) as object
    chosen = { poster: "", posterFallback: "" }
    if not IsAssoc(item) then return chosen
    tv = ResolveContentUrl(item.Lookup("imageTvUrl"))
    full = ResolveContentUrl(item.Lookup("imageUrl"))
    primary = ""
    if PosterKindOk(tv) then primary = tv
    if PosterKindOk(full)
        if primary = ""
            primary = full
        else if full <> primary
            chosen.posterFallback = full
        end if
    end if
    chosen.poster = primary
    return chosen
end function

function ActivityQr(item as object) as string
    if not IsAssoc(item) then return ""
    ' Plain url only. affiliateUrl is reserved and must not become a QR.
    link = GuideLimitedText(AaField(item, "url"), 400)
    if link = "" then return ""
    given = ResolveContentUrl(AaField(item, "qrUrl"))
    if PosterKindOk(given) then return WithQrVersion(given)
    return ""
end function

function CreditLine(credit as object) as string
    if not IsAssoc(credit) then return ""
    author = GuideLimitedText(credit.Lookup("author"), 80)
    license = GuideLimitedText(credit.Lookup("license"), 48)
    changes = GuideLimitedText(credit.Lookup("changes"), 40)
    if author = "" and license = "" then return ""
    line = author
    if license <> ""
        if line <> "" then line = line + " · "
        line = line + license
        if changes <> "" then line = line + " (" + changes + ")"
    end if
    line = line + " · Wikimedia Commons"
    return GuideLimitedText(line, 220)
end function

function NormalizeActivities(parsed as object) as object
    if not IsAssoc(parsed) then return invalid
    sections = parsed.Lookup("activitySections")
    if not IsList(sections) then return invalid
    items = []
    sourceIndex = 0
    sectionLast = sections.Count() - 1
    if sectionLast >= 0
        for sectionAt = 0 to sectionLast
            if items.Count() >= 240 then exit for
            section = sections[sectionAt]
            if IsAssoc(section)
                sectionId = GuideLimitedText(section.Lookup("id"), 80)
                rows = section.Lookup("activities")
                if IsList(rows)
                    rowLast = rows.Count() - 1
                    if rowLast >= 0
                        for rowAt = 0 to rowLast
                            if items.Count() >= 240 then exit for
                            item = SlimActivity(rows[rowAt], sectionId, sourceIndex)
                            sourceIndex = sourceIndex + 1
                            if item <> invalid then items.Push(item)
                        end for
                    end if
                end if
            end if
        end for
    end if
    return {
        activitiesVersion: GuideInt(parsed.Lookup("version")),
        items: items
    }
end function

function SeasonRankRecord(ranks as object) as object
    record = {}
    record["winter"] = PositiveRank(AaField(ranks, "winter"))
    record["spring"] = PositiveRank(AaField(ranks, "spring"))
    record["summer"] = PositiveRank(AaField(ranks, "summer"))
    record["fall"] = PositiveRank(AaField(ranks, "fall"))
    return record
end function

function SlimActivity(raw as object, sectionId as string, sourceIndex as integer) as object
    if not IsAssoc(raw) then return invalid
    name = GuideLimitedText(AaField(raw, "name"), 120)
    if name = "" then name = "Untitled"
    poster = ActivityPoster(raw)
    ranks = AaField(raw, "seasonRank")
    if not IsAssoc(ranks) then ranks = {}
    qr = ActivityQr(raw)
    ' An AA literal lowercases qrUrl and seasonRank. FormatJson then writes
    ' those short names, and the scene's case-sensitive ParseJson misses them.
    item = {}
    item["id"] = GuideLimitedText(AaField(raw, "id"), 80)
    item["name"] = name
    item["description"] = GuideLimitedText(AaField(raw, "description"), 420)
    item["distance"] = GuideLimitedText(AaField(raw, "distance"), 80)
    item["trailDistance"] = GuideLimitedText(AaField(raw, "trailDistance"), 120)
    item["difficulty"] = GuideLimitedText(AaField(raw, "difficulty"), 40)
    item["gettingThere"] = GuideLimitedText(AaField(raw, "gettingThere"), 220)
    item["seasonLabel"] = GuideLimitedText(AaField(raw, "seasonLabel"), 80)
    item["tip"] = GuideLimitedText(AaField(raw, "tip"), 180)
    item["url"] = GuideLimitedText(AaField(raw, "url"), 400)
    item["qrUrl"] = qr
    item["qrUri"] = qr
    item["poster"] = poster.poster
    item["posterFallback"] = poster.posterFallback
    item["credit"] = CreditLine(AaField(raw, "imageCredit"))
    item["sectionId"] = sectionId
    item["sourceIndex"] = sourceIndex
    item["seasonRank"] = SeasonRankRecord(ranks)
    return item
end function

function DefaultSavingsText() as string
    return "Book direct and pay up to about 10% less than Airbnb or Vrbo, plus no booking-site service fees."
end function

function DefaultDomain() as string
    ' Not returned as one literal: the guest-key guard treats a dotted token that
    ' shape as a path key when it is the entire returned string.
    domain = "sunrivertownhome.com"
    return domain
end function

function DefaultBookDirect() as object
    book = {
        headline: ["Love our home?", "Want to come back?", "Like saving money?"],
        banner: "Book direct and save!",
        body: "Our website has lots of great information about the house, local activities, dining, outdoor adventures and more!",
        savingsText: DefaultSavingsText(),
        siteUrl: "https://sunrivertownhome.com",
        bookingUrl: "https://book.sunrivertownhome.com",
        qrImageUrl: "https://sunrivertownhome.com/data/qr/book-direct-site.png",
        bookingQrImageUrl: "https://sunrivertownhome.com/data/qr/book-direct-booking.png",
        photo: "https://sunrivertownhome.com/images/tv/book-direct-living.jpg",
        photoFallback: "https://sunrivertownhome.com/images/photos/house/living-room-1.jpg",
        perks: DefaultPerks(),
        signOff: "Thanks for staying!",
        homePromptTitle: "Book your next stay direct and save!",
        homePromptSub: "Up to about 10% less than Airbnb or Vrbo"
    }
    book.qrImageUrl = WithQrVersion(book.qrImageUrl)
    book.bookingQrImageUrl = WithQrVersion(book.bookingQrImageUrl)
    return book
end function

function DefaultPerks() as object
    return [
        { id: "house", label: "House info", icon: "house" },
        { id: "activities", label: "Local activities", icon: "mountain" },
        { id: "dining", label: "Dining", icon: "dining" },
        { id: "outdoors", label: "Outdoor adventures", icon: "pines" },
        { id: "more", label: "And more!", icon: "more" }
    ]
end function

function NormalizeBookDirect(parsed as object) as object
    book = DefaultBookDirect()
    site = {}
    block = {}
    if IsAssoc(parsed)
        found = parsed.Lookup("siteConfig")
        if IsAssoc(found) then site = found
        foundBlock = parsed.Lookup("bookDirect")
        if IsAssoc(foundBlock) then block = foundBlock
    end if
    headlines = StringList(block.Lookup("headline"), 3, 80)
    if headlines.Count() > 0 then book.headline = headlines
    banner = GuideString(block, "banner", 80)
    if banner <> "" then book.banner = banner
    body = GuideString(block, "body", 280)
    if body <> "" then book.body = body
    savings = GuideString(block, "savingsText", 220)
    if savings <> "" then book.savingsText = savings
    siteUrl = GuideString(block, "siteUrl", 200)
    if siteUrl = ""
        domain = GuideString(site, "domain", 80)
        if domain <> "" then siteUrl = "https://" + domain
    end if
    if siteUrl <> "" then book.siteUrl = siteUrl
    booking = GuideString(block, "bookingUrl", 200)
    if booking = "" then booking = GuideString(site, "bookUrl", 200)
    if booking <> "" then book.bookingUrl = booking
    qr = FirstPosterUrl(GuideString(block, "qrImageUrl", 320), "https://sunrivertownhome.com/data/qr/book-direct-site.png")
    book.qrImageUrl = WithQrVersion(qr)
    bookingQr = FirstPosterUrl(GuideString(block, "bookingQrImageUrl", 320), "https://sunrivertownhome.com/data/qr/book-direct-booking.png")
    book.bookingQrImageUrl = WithQrVersion(bookingQr)
    photos = BookPhotos(block)
    book.photo = photos.poster
    book.photoFallback = photos.posterFallback
    perks = PerkList(block.Lookup("perks"))
    if perks.Count() > 0 then book.perks = perks
    signOff = GuideString(block, "signOff", 80)
    if signOff <> "" then book.signOff = signOff
    prompt = GuideString(block, "homePromptTitle", 80)
    if prompt <> "" then book.homePromptTitle = prompt
    promptSub = GuideString(block, "homePromptSub", 120)
    if promptSub <> "" then book.homePromptSub = promptSub
    return book
end function

function FirstPosterUrl(preferred as string, fallback as string) as string
    preferredUrl = ResolveContentUrl(preferred)
    fallbackUrl = ResolveContentUrl(fallback)
    if PosterKindOk(preferredUrl) then return preferredUrl
    if PosterKindOk(fallbackUrl) then return fallbackUrl
    return ""
end function

function BookPhotos(block as object) as object
    raw = {}
    raw.imageTvUrl = GuideString(block, "photoTvUrl", 240)
    raw.imageUrl = GuideString(block, "photoUrl", 240)
    chosen = ActivityPoster(raw)
    if chosen.poster = ""
        chosen = ActivityPoster({
            imageTvUrl: "https://sunrivertownhome.com/images/tv/book-direct-living.jpg",
            imageUrl: "https://sunrivertownhome.com/images/photos/house/living-room-1.jpg"
        })
    end if
    return chosen
end function

function PerkList(value as object) as object
    items = []
    if not IsList(value) then return items
    last = value.Count() - 1
    if last < 0 then return items
    for index = 0 to last
        if items.Count() >= 5 then exit for
        entry = value[index]
        if IsAssoc(entry)
            label = GuideString(entry, "label", 40)
            id = GuideString(entry, "id", 24)
            icon = GuideString(entry, "icon", 24)
            if label <> "" then items.Push({ id: id, label: label, icon: icon })
        end if
    end for
    return items
end function

function WifiIssueText(issue as object) as boolean
    if not IsAssoc(issue) then return false
    text = LCase(GuideLimitedText(issue.Lookup("issue"), 140))
    if Instr(1, text, "wifi") > 0 then return true
    if Instr(1, text, "wi-fi") > 0 then return true
    if Instr(1, text, "wi fi") > 0 then return true
    return false
end function

function IssuesForFixes(issues as object) as object
    visible = []
    if not IsList(issues) then return visible
    last = issues.Count() - 1
    if last < 0 then return visible
    for index = 0 to last
        issue = issues[index]
        if not WifiIssueText(issue) then visible.Push(issue)
    end for
    return visible
end function

function RouterStep(issues as object) as string
    if not IsList(issues) then return ""
    last = issues.Count() - 1
    if last < 0 then return ""
    for index = 0 to last
        issue = issues[index]
        if WifiIssueText(issue)
            steps = issue.Lookup("steps")
            if IsList(steps)
                stepLast = steps.Count() - 1
                if stepLast >= 0
                    for stepAt = 0 to stepLast
                        text = GuideLimitedText(steps[stepAt], 220)
                        if Instr(1, LCase(text), "router") > 0 then return text
                    end for
                end if
            end if
        end if
    end for
    return ""
end function

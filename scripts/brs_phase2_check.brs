sub Main()
    failed = 0
    failed = failed + ExpectSeason(1772348400, 2, 23, "winter")
    failed = failed + ExpectSeason(1772353800, 3, 0, "spring")
    failed = failed + ExpectHour(1772962200, 3, 8, 1, 8)
    failed = failed + ExpectHour(1772965800, 3, 8, 3, 7)
    failed = failed + ExpectSeason(1780293600, 5, 23, "spring")
    failed = failed + ExpectSeason(1780299000, 6, 0, "summer")
    failed = failed + ExpectSeason(1793138400, 10, 15, "fall")
    failed = failed + ExpectSeason(1796113800, 12, 0, "winter")
    failed = failed + ExpectDay(1798788600, 2026, 12, 31, 23)

    early = { sourceIndex: 1, seasonRank: { fall: 2 } }
    later = { sourceIndex: 2, seasonRank: { fall: 1 } }
    missing = { sourceIndex: 0, seasonRank: { fall: 0 } }
    if CompareSeasonRank("fall", early, later, 1, 2) <= 0
        print "FAIL a higher seasonRank sorted first"
        failed = failed + 1
    end if
    if CompareSeasonRank("fall", later, early, 2, 1) >= 0
        print "FAIL a lower seasonRank did not sort first"
        failed = failed + 1
    end if
    if CompareSeasonRank("fall", missing, later, 0, 2) <= 0
        print "FAIL a missing rank sorted ahead of a ranked activity"
        failed = failed + 1
    end if
    tiedA = { sourceIndex: 4, seasonRank: { fall: 3 } }
    tiedB = { sourceIndex: 9, seasonRank: { fall: 3 } }
    if CompareSeasonRank("fall", tiedB, tiedA, 9, 4) <= 0
        print "FAIL equal ranks did not keep the earlier source index first"
        failed = failed + 1
    end if

    sorted = SortActivities([early, missing, later], "fall")
    if sorted.Count() <> 3 or SourceIndexOf(sorted[0]) <> 2 or SourceIndexOf(sorted[1]) <> 1 or SourceIndexOf(sorted[2]) <> 0
        print "FAIL sort order was not rank, then source index"
        failed = failed + 1
    end if

    dupes = NormalizeActivities({
        version: 4,
        activitySections: [
            { id: "guided-tours-and-activities", activities: [Sample("viator-ebike-tour", "https://example.com/a")] },
            { id: "golf-family", activities: [Sample("viator-ebike-tour", "https://example.com/a")] }
        ]
    })
    if dupes = invalid or dupes.items.Count() <> 2
        print "FAIL duplicate activity ids were collapsed"
        failed = failed + 1
    else
        if dupes.items[0].id <> dupes.items[1].id
            print "FAIL duplicate ids were rewritten"
            failed = failed + 1
        end if
        if SourceIndexOf(dupes.items[0]) = SourceIndexOf(dupes.items[1])
            print "FAIL duplicate ids share a source index"
            failed = failed + 1
        end if
        if CardNodeId(dupes.items[0]) = CardNodeId(dupes.items[1])
            print "FAIL card nodes would share an id"
            failed = failed + 1
        end if
    end if

    if ResolveContentUrl("/images/tv/a.jpg") <> "https://sunrivertownhome.com/images/tv/a.jpg"
        print "FAIL a root-relative URL did not resolve"
        failed = failed + 1
    end if
    if ResolveContentUrl("images/tv/a.jpg") <> "https://sunrivertownhome.com/images/tv/a.jpg"
        print "FAIL a relative URL did not resolve"
        failed = failed + 1
    end if
    absolute = "https://sunrivertownhome.com/images/tv/a.jpg"
    if ResolveContentUrl(absolute) <> absolute
        print "FAIL an absolute URL was rewritten"
        failed = failed + 1
    end if

    tv = ActivityPoster({ imageTvUrl: "/images/tv/place.jpg", imageUrl: "https://cdn.example/place.webp" })
    if tv.poster <> "https://sunrivertownhome.com/images/tv/place.jpg"
        print "FAIL imageTvUrl did not win"
        failed = failed + 1
    end if
    webp = ActivityPoster({ imageUrl: "https://cdn.example/place.webp" })
    if webp.poster <> ""
        print "FAIL a webp imageUrl was accepted"
        failed = failed + 1
    end if
    gif = ActivityPoster({ imageTvUrl: "https://cdn.example/place.gif", imageUrl: "https://cdn.example/place.avif" })
    if gif.poster <> ""
        print "FAIL a gif or avif poster was accepted"
        failed = failed + 1
    end if
    png = ActivityPoster({ imageUrl: "https://cdn.example/place.png" })
    if png.poster <> "https://cdn.example/place.png"
        print "FAIL a png imageUrl was rejected"
        failed = failed + 1
    end if

    if ActivityQr({ id: "cafe", qrUrl: "/data/qr/cafe.png", affiliateUrl: "https://affiliate.example/cafe" }) <> ""
        print "FAIL a QR was built without url"
        failed = failed + 1
    end if
    linked = ActivityQr({ id: "cafe", url: "https://cafe.example", qrUrl: "/data/qr/cafe.png", affiliateUrl: "https://affiliate.example/cafe" })
    if linked <> "https://sunrivertownhome.com/data/qr/cafe.png?v=rgb2"
        print "FAIL qrUrl was not resolved from url"
        failed = failed + 1
    end if
    joined = WithQrVersion("https://sunrivertownhome.com/data/qr/cafe.png?x=1")
    if joined <> "https://sunrivertownhome.com/data/qr/cafe.png?x=1&v=rgb2"
        print "FAIL a QR query was not joined with &"
        failed = failed + 1
    end if
    kept = WithQrVersion("https://sunrivertownhome.com/data/qr/cafe.png?v=rgb2")
    if kept <> "https://sunrivertownhome.com/data/qr/cafe.png?v=rgb2"
        print "FAIL the QR version was added twice"
        failed = failed + 1
    end if
    other = WithQrVersion("https://cdn.example/place.png")
    if other <> "https://cdn.example/place.png"
        print "FAIL a non-QR image gained a version"
        failed = failed + 1
    end if
    wifiUrl = WithQrVersion("https://cdn.example/tv/wifi.png")
    if wifiUrl <> "https://cdn.example/tv/wifi.png"
        print "FAIL a Wi-Fi URL gained a version"
        failed = failed + 1
    end if
    derived = ActivityQr({ id: "cafe", url: "https://cafe.example" })
    if derived <> ""
        print "FAIL a missing qrUrl still built a QR"
        failed = failed + 1
    end if
    norm = NormalizeActivities({
        version: 4,
        activitySections: [{
            id: "guided-tours-and-activities",
            activities: [{
                id: "viator-ebike-tour",
                name: "Electric Bike Tour",
                url: "https://www.viator.com/tours/Bend/example",
                qrUrl: "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png"
            }]
        }]
    })
    if norm = invalid or norm.items.Count() <> 1
        print "FAIL the detail activity did not normalize"
        failed = failed + 1
    else
        item = norm.items[0]
        wanted = "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png?v=rgb2"
        if item.qrUrl <> wanted or item.qrUri <> wanted or DetailQrUrl(item) <> wanted
            print "FAIL qrUrl was not passed to the detail item"
            failed = failed + 1
        end if
    end if
    stale = { items: [{ id: "viator-ebike-tour", qrUri: "" }] }
    fresh = { items: [{ id: "viator-ebike-tour", qrUrl: "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png?v=rgb2" }] }
    picked = ChooseActivities(stale, fresh)
    if picked = invalid or picked.items[0].qrUrl = ""
        print "FAIL a cache without qrUrl beat the bundled snapshot"
        failed = failed + 1
    end if
    kept = ChooseActivities(fresh, stale)
    if kept = invalid or kept.items[0].qrUrl <> fresh.items[0].qrUrl
        print "FAIL a cache with qrUrl was discarded"
        failed = failed + 1
    end if
    raw304 = {
        version: 4,
        activitySections: [{
            id: "guided-tours-and-activities",
            activities: [
                { id: "viator-ebike-tour", name: "First tour", url: "https://example.com/a", qrUrl: "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png" },
                { id: "viator-ebike-tour", name: "Second tour", url: "https://example.com/b", qrUrl: "https://sunrivertownhome.com/data/qr/viator-ebike-tour-b.png" }
            ]
        }]
    }
    stale304 = {
        version: 4,
        activitySections: [{
            id: "guided-tours-and-activities",
            activities: [
                { id: "viator-ebike-tour", name: "First tour", url: "https://example.com/a" },
                { id: "viator-ebike-tour", name: "Second tour", url: "https://example.com/b" }
            ]
        }]
    }
    bundled304 = ActivitiesFromFetch(raw304, "pkg", "0", invalid)
    from304 = ActivitiesFromFetch(stale304, "not-modified", "304", bundled304)
    first304 = ActivityAt(from304.items, 0)
    second304 = ActivityAt(from304.items, 1)
    firstQr = "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png?v=rgb2"
    secondQr = "https://sunrivertownhome.com/data/qr/viator-ebike-tour-b.png?v=rgb2"
    if first304 = invalid or second304 = invalid or first304.qrUrl <> firstQr or second304.qrUrl <> secondQr
        print "FAIL a 304 cache without qrUrl dropped the packaged QR links"
        failed = failed + 1
    else if first304.id <> "viator-ebike-tour" or second304.id <> "viator-ebike-tour" or first304.qrUrl = second304.qrUrl
        print "FAIL duplicate activity ids were collapsed"
        failed = failed + 1
    else
        kept304 = ActivitiesFromFetch(raw304, "not-modified", "304", { items: [{ id: "other", qrUrl: "https://sunrivertownhome.com/data/qr/other.png?v=rgb2" }] })
        round304 = ParseJson(EncodeJson(kept304.items))
        if ActivityAt(kept304.items, 0).qrUrl <> firstQr or ActivityAt(round304, 1).qrUrl <> secondQr
            print "FAIL a 304 document with qrUrl did not keep both cards"
            failed = failed + 1
        end if
    end if
    if BookQrFits(BookQrSlot()) <> true
        print "FAIL the Scan me slot falls outside its card or the screen"
        failed = failed + 1
    end if
    if QrDebugMarks() <> false or QrMarkColor() <> "0xFFFFFFF2"
        print "FAIL QR debug marks are on"
        failed = failed + 1
    end if
    if ActivitiesCacheGeneration() <> "qr3"
        print "FAIL the activities cache generation was not bumped"
        failed = failed + 1
    end if
    if ActivitiesCacheDropsQr({ activitySections: [{ activities: [{ id: "viator-ebike-tour", url: "https://example.com/a" }] }] }) <> true
        print "FAIL a cached activity without qrUrl was kept"
        failed = failed + 1
    end if
    if ActivitiesCacheDropsQr({ activitySections: [{ activities: [{ id: "viator-ebike-tour", qrUrl: "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png" }] }] }) <> false
        print "FAIL a cached activity with qrUrl was discarded"
        failed = failed + 1
    end if
    byId = ActivityById({
        activitySections: [{
            activities: [
                { id: "viator-ebike-tour", name: "First" },
                { id: "viator-ebike-tour", name: "Second", qrUrl: "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png" }
            ]
        }]
    }, "viator-ebike-tour")
    if byId = invalid or byId.qrUrl <> "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png"
        print "FAIL detail did not resolve qrUrl by id"
        failed = failed + 1
    end if
    slot = BookQrSlot()
    if slot.domainW <> slot.cardW or slot.domainX <> slot.cardX
        print "FAIL the Book Direct domain caption is narrower than its card"
        failed = failed + 1
    end if
    if QrCaptionColor() <> AmberColor() or QrCaptionFont() <> "font:SmallestBoldSystemFont"
        print "FAIL the QR captions do not share the gold caption style"
        failed = failed + 1
    end if
    frame = BadgeFrame()
    if frame.x <> 1496 or frame.y <> 830 or frame.qrX <> 46 or frame.qrY <> 42 or frame.qr <> 128
        print "FAIL the corner badge left the build 18 size and position"
        failed = failed + 1
    end if
    if frame.captionY <> 172 or frame.captionH <> 28 or frame.captionY < frame.qrY + frame.qr
        print "FAIL the gold caption is not directly under the corner QR"
        failed = failed + 1
    end if
    if RectsClear(BadgeCaptionRect(), CheckoutTileRect(), 24) <> true
        print "FAIL the badge caption overlaps the Checkout tile"
        failed = failed + 1
    end if
    if ActivitiesCacheShouldDiscard("not-modified", raw304) <> true
        print "FAIL a 304 activities response was kept"
        failed = failed + 1
    end if
    if ActivitiesCacheShouldDiscard("ok", raw304) <> false
        print "FAIL a 200 activities document was discarded"
        failed = failed + 1
    end if
    if ActivitiesCacheShouldDiscard("http", stale304) <> true
        print "FAIL a 304 cache missing qrUrl was kept"
        failed = failed + 1
    end if
    if ActivitiesCacheShouldDiscard("timeout", invalid) <> false
        print "FAIL a failed fetch with no cache was treated as a wipe"
        failed = failed + 1
    end if

    book = NormalizeBookDirect({
        bookDirect: {
            photoTvUrl: "/images/tv/book-direct-living.jpg",
            photoUrl: "living-room-1.jpg",
            qrImageUrl: "/data/qr/book-direct-site.png",
            bookingQrImageUrl: "/data/qr/book-direct-booking.png"
        }
    })
    if book.photo <> "https://sunrivertownhome.com/images/tv/book-direct-living.jpg"
        print "FAIL book photoTvUrl stayed relative"
        failed = failed + 1
    end if
    if book.qrImageUrl <> "https://sunrivertownhome.com/data/qr/book-direct-site.png?v=rgb2"
        print "FAIL site QR stayed relative"
        failed = failed + 1
    end if
    if book.bookingQrImageUrl <> "https://sunrivertownhome.com/data/qr/book-direct-booking.png?v=rgb2"
        print "FAIL booking QR stayed relative"
        failed = failed + 1
    end if
    if Instr(1, book.savingsText, "up to about 10% less") < 1
        print "FAIL default savings text changed"
        failed = failed + 1
    end if
    if book.bookingUrl <> "https://book.sunrivertownhome.com"
        print "FAIL booking URL changed"
        failed = failed + 1
    end if
    if HomePromptTitle({ homePromptTitle: "Book direct & save" }) <> "Book your next stay direct and save!"
        print "FAIL the home strip kept the short title"
        failed = failed + 1
    end if
    if HomePromptTitle({ homePromptTitle: "Come back in the fall" }) <> "Come back in the fall"
        print "FAIL a custom home title was replaced"
        failed = failed + 1
    end if
    if WifiLines("coming-soon", "", "").mode <> "coming-soon"
        print "FAIL Wi-Fi lines ignored coming-soon"
        failed = failed + 1
    end if
    if WifiLines("", "Cabin", "secret").password <> "secret"
        print "FAIL Wi-Fi lines dropped the password"
        failed = failed + 1
    end if
    if NetworkValue("Network name: Cabin") <> "Cabin" or NetworkValue("Cabin") <> "Cabin"
        print "FAIL the network label prefix stayed on the value"
        failed = failed + 1
    end if
    if WifiFallbackMessage() <> "Wi-Fi details couldn't load right now. Please check your booking welcome message or contact your host (see Help)."
        print "FAIL the Wi-Fi fallback message changed"
        failed = failed + 1
    end if

    if DisplayDomain() <> "sunrivertownhome.com"
        print "FAIL QR caption is not the marketing host"
        failed = failed + 1
    end if

    if WifiScreenMode(200, false) <> "show" or WifiScreenMode(304, true) <> "show"
        print "FAIL a fresh Wi-Fi response did not show"
        failed = failed + 1
    end if
    if WifiScreenMode(503, true) <> "cache"
        print "FAIL a 503 dropped a cached Wi-Fi copy"
        failed = failed + 1
    end if
    if WifiScreenMode(503, false) <> "coming-soon"
        print "FAIL a 503 without cache was not coming-soon"
        failed = failed + 1
    end if
    if WifiScreenMode(404, false) <> "fallback" or WifiScreenMode(404, true) <> "cache"
        print "FAIL a 404 Wi-Fi mode was wrong"
        failed = failed + 1
    end if
    if ComingSoonWifi() <> "Wi-Fi details coming soon"
        print "FAIL coming-soon copy changed"
        failed = failed + 1
    end if

    fixes = IssuesForFixes([{ issue: "WiFi not connecting" }, { issue: "Hot tub" }])
    if fixes.Count() <> 1 or fixes[0].issue <> "Hot tub"
        print "FAIL the Wi-Fi how-to was still in Quick Fixes"
        failed = failed + 1
    end if

    if failed = 0 then print "brs phase2 checks passed"
end sub

function Sample(id as string, url as string) as object
    return {
        id: id,
        name: "Electric Bike Tour",
        url: url,
        imageTvUrl: "/images/tv/" + id + ".jpg",
        qrUrl: "/data/qr/" + id + ".png"
    }
end function

function ExpectSeason(seconds as integer, month as integer, hour as integer, season as string) as integer
    parts = PacificLocalParts(seconds)
    if parts = invalid or parts.month <> month or parts.hour <> hour or CalendarSeasonForMonth(parts.month) <> season
        print "FAIL pacific "; seconds
        return 1
    end if
    return 0
end function

function ExpectHour(seconds as integer, month as integer, day as integer, hour as integer, offset as integer) as integer
    parts = PacificLocalParts(seconds)
    if parts = invalid or parts.month <> month or parts.day <> day or parts.hour <> hour or parts.offsetHours <> offset
        print "FAIL dst "; seconds
        return 1
    end if
    return 0
end function

function ExpectDay(seconds as integer, year as integer, month as integer, day as integer, hour as integer) as integer
    parts = PacificLocalParts(seconds)
    if parts = invalid or parts.year <> year or parts.month <> month or parts.day <> day or parts.hour <> hour
        print "FAIL year boundary "; seconds
        return 1
    end if
    return 0
end function

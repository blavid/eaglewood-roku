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
    if linked <> "https://sunrivertownhome.com/data/qr/cafe.png"
        print "FAIL qrUrl was not resolved from url"
        failed = failed + 1
    end if
    derived = ActivityQr({ id: "cafe", url: "https://cafe.example" })
    if derived <> "https://sunrivertownhome.com/data/qr/cafe.png"
        print "FAIL a missing qrUrl was not derived"
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
    if book.bookingQrImageUrl <> "https://sunrivertownhome.com/data/qr/book-direct-booking.png"
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

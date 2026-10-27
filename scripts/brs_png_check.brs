sub Main()
    failed = 0
    rgb = ExpandPngBytes(FixtureRgbPng())
    if rgb.ok <> true or rgb.converted <> false or rgb.color <> 2 or rgb.bit <> 8
        print "FAIL an RGB PNG was rewritten"
        failed = failed + 1
    end if

    source = FixtureGrayPng()
    gray = ExpandPngBytes(source)
    if gray.ok <> true or gray.converted <> true or gray.color <> 0 or gray.width <> 4 or gray.height <> 3
        print "FAIL grayscale PNG convert header"
        print gray.reason
        failed = failed + 1
    else
        header = ReadPng(gray.bytes)
        original = ReadPng(AsBuf(source))
        if header.ok <> true or header.color <> 3 or header.bit <> 8 or header.interlace <> 0
            print "FAIL converted PNG is not 8-bit indexed"
            failed = failed + 1
        else if header.plte = invalid or header.plte.n <> 768 or BufAt(header.plte, 30) <> 10
            print "FAIL gray palette"
            failed = failed + 1
        else if header.idat.n <> original.idat.n or BufAt(header.idat, 0) <> BufAt(original.idat, 0)
            print "FAIL IDAT was recompressed"
            failed = failed + 1
        end if
    end if

    masked = SafeUri("https://sunrivertownhome.com/tv/examplekey/wifi.png?t=1")
    if masked <> "https://sunrivertownhome.com/tv/***/wifi.png"
        print "FAIL a path key stayed in a logged URL"
        failed = failed + 1
    end if
    if SafeUri("https://sunrivertownhome.com/data/qr/cafe.png") <> "https://sunrivertownhome.com/data/qr/cafe.png"
        print "FAIL a public QR URL was rewritten"
        failed = failed + 1
    end if
    if SafeUri("") <> "none"
        print "FAIL an empty URI was logged"
        failed = failed + 1
    end if

    if failed = 0 then print "brs png checks passed"
end sub

function FixtureGrayPng() as object
    return [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 4, 0, 0, 0, 3, 8, 0, 0, 0, 0, 145, 159, 241, 26, 0, 0, 0, 23, 73, 68, 65, 84, 120, 218, 99, 224, 18, 145, 211, 96, 228, 146, 227, 226, 98, 249, 118, 227, 127, 35, 0, 15, 136, 3, 244, 69, 243, 121, 204, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]
end function

function FixtureRgbPng() as object
    return [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 4, 0, 0, 0, 3, 8, 2, 0, 0, 0, 59, 150, 57, 145, 0, 0, 0, 40, 73, 68, 65, 84, 120, 156, 99, 224, 226, 226, 18, 17, 17, 145, 147, 147, 211, 208, 208, 96, 0, 114, 128, 148, 145, 145, 145, 141, 141, 13, 3, 4, 252, 255, 255, 191, 161, 161, 1, 0, 88, 44, 7, 138, 25, 211, 130, 39, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]
end function

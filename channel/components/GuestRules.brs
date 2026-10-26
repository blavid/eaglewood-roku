function FallbackGreeting() as string
    return "Welcome to Eaglewood"
end function

function NamePartLimit() as integer
    return 32
end function

function GreetingFontSizes() as object
    return [64, 52, 42, 34]
end function

function GreetingLabelWidth() as integer
    return 1760
end function

function GreetingBarBottom() as integer
    return 960
end function

function GreetingBarMinHeight() as integer
    return 160
end function

function GreetingBarPad() as integer
    return 48
end function

function GreetingMinTop() as integer
    return 48
end function

function BlankGuestResult(generation as integer) as object
    return {
        generation: generation,
        ok: "no",
        firstName: "",
        lastName: "",
        checkout: "",
        checkoutPresent: "no"
    }
end function

function GuestFields(parsed as object, generation as integer) as object
    result = BlankGuestResult(generation)
    if parsed = invalid then return result
    if type(parsed) <> "roAssociativeArray" then return result
    result.ok = "yes"
    result.firstName = ReadJsonString(parsed, "firstName", 80)
    result.lastName = ReadJsonString(parsed, "lastName", 80)
    checkoutKind = ReadCheckout(parsed)
    if checkoutKind = invalid
        result.checkoutPresent = "yes"
        result.checkout = "bad"
    else if checkoutKind = ""
        result.checkoutPresent = "no"
        result.checkout = ""
    else
        result.checkoutPresent = "yes"
        result.checkout = checkoutKind
    end if
    return result
end function

function ReadJsonString(parsed as object, key as string, limit as integer) as string
    value = parsed.Lookup(key)
    if value = invalid then return ""
    kind = type(value)
    if kind <> "String" and kind <> "roString" then return ""
    if Len(value) > limit then return Left(value, limit)
    return value
end function

function ReadCheckout(parsed as object) as object
    value = parsed.Lookup("checkout")
    if value = invalid then return ""
    kind = type(value)
    if kind <> "String" and kind <> "roString" then return invalid
    if Len(value) > 80 then return Left(value, 80)
    return value
end function

function GreetingFromGuest(firstName as object, lastName as object, checkout as object, checkoutPresent as boolean) as string
    return GreetingFromGuestAt(firstName, lastName, checkout, checkoutPresent, NowSeconds())
end function

function GreetingFromGuestAt(firstName as object, lastName as object, checkout as object, checkoutPresent as boolean, clockSeconds as integer) as string
    first = SanitizeNamePart(firstName)
    if first = "" then return FallbackGreeting()
    if not StayIsCurrent(checkout, checkoutPresent, clockSeconds) then return FallbackGreeting()
    last = SanitizeNamePart(lastName)
    if last = "" then return "Welcome, " + first
    return "Welcome, " + first + " " + last
end function

function NowSeconds() as integer
    clock = CreateObject("roDateTime")
    if clock = invalid then return 0
    return clock.AsSeconds()
end function

function StayIsCurrent(checkout as object, checkoutPresent as boolean, clockSeconds as integer) as boolean
    if checkoutPresent = false then return true
    if checkout = invalid then return false
    if type(checkout) <> "String" and type(checkout) <> "roString" then return false
    if checkout = "" then return true
    instant = CheckoutSeconds(checkout)
    if instant = invalid then return false
    if clockSeconds < instant then return true
    return false
end function

function CheckoutSeconds(raw as object)
    if raw = invalid then return invalid
    if type(raw) <> "String" and type(raw) <> "roString" then return invalid
    text = raw.Trim()
    if Len(text) < 10 or Len(text) > 40 then return invalid
    yearText = Left(text, 4)
    if not IsDigits(yearText) then return invalid
    if CharAt(text, 5) <> "-" then return invalid
    monthText = Slice(text, 6, 2)
    if not IsDigits(monthText) then return invalid
    if CharAt(text, 8) <> "-" then return invalid
    dayText = Slice(text, 9, 2)
    if not IsDigits(dayText) then return invalid
    year = yearText.ToInt()
    month = monthText.ToInt()
    day = dayText.ToInt()
    ' roDateTime.AsSeconds() is a 32-bit integer, so a later year can wrap
    ' and look like the past. Reject those instead of greeting the wrong stay.
    if year < 2000 or year > 2037 then return invalid
    if month < 1 or month > 12 then return invalid
    if day < 1 or day > DaysInMonth(year, month) then return invalid

    timeText = "23:59:59"
    offsetText = ""
    if Len(text) = 10
        offsetText = "Z"
    else
        rest = Right(text, Len(text) - 10)
        sep = Left(rest, 1)
        if sep <> "T" and sep <> "t" and sep <> " " then return invalid
        if Len(rest) < 9 then return invalid
        timeText = Slice(rest, 2, 8)
        if not IsClock(timeText) then return invalid
        tail = ""
        if Len(rest) > 9 then tail = Right(rest, Len(rest) - 9)
        tail = DropFraction(tail)
        if tail = invalid then return invalid
        offsetText = tail
    end if

    zoneSeconds = 0
    if offsetText <> ""
        parsedZone = ZoneOffsetSeconds(offsetText)
        if parsedZone = invalid then return invalid
        zoneSeconds = parsedZone
    end if

    iso = yearText + "-" + monthText + "-" + dayText + "T" + timeText
    hour = Left(timeText, 2).ToInt()
    minute = Slice(timeText, 4, 2).ToInt()
    second = Right(timeText, 2).ToInt()
    utcSeconds = ParsedWallSeconds(iso, year, month, day, hour, minute, second)
    if utcSeconds = invalid then return invalid
    return utcSeconds - zoneSeconds
end function

function DropFraction(tail as string)
    if tail = "" then return ""
    if Left(tail, 1) <> "." then return tail
    if Len(tail) < 2 then return invalid
    index = 2
    while index <= Len(tail)
        code = Asc(CharAt(tail, index))
        if code < 48 or code > 57 then exit while
        index = index + 1
    end while
    if index = 2 then return invalid
    if index > Len(tail) then return ""
    return Right(tail, Len(tail) - (index - 1))
end function

function ParsedWallSeconds(iso as string, year as integer, month as integer, day as integer, hour as integer, minute as integer, second as integer)
    clock = CreateObject("roDateTime")
    if clock = invalid then return invalid
    parsed = clock.FromISO8601String(iso)
    kind = type(parsed)
    if kind = "Boolean"
        if parsed = false then return invalid
    else if kind <> "Invalid"
        return invalid
    end if
    if clock.GetYear() <> year then return invalid
    if clock.GetMonth() <> month then return invalid
    if clock.GetDayOfMonth() <> day then return invalid
    if clock.GetHours() <> hour then return invalid
    if clock.GetMinutes() <> minute then return invalid
    if clock.GetSeconds() <> second then return invalid
    return clock.AsSeconds()
end function

function ZoneOffsetSeconds(text as string)
    if text = "Z" or text = "z" then return 0
    if Len(text) <> 5 and Len(text) <> 6 then return invalid
    signText = Left(text, 1)
    sign = 0
    if signText = "+" then sign = 1
    if signText = "-" then sign = -1
    if sign = 0 then return invalid
    rest = Right(text, Len(text) - 1)
    hourText = ""
    minuteText = ""
    if Len(rest) = 5
        if CharAt(rest, 3) <> ":" then return invalid
        hourText = Left(rest, 2)
        minuteText = Right(rest, 2)
    else if Len(rest) = 4
        hourText = Left(rest, 2)
        minuteText = Right(rest, 2)
    else
        return invalid
    end if
    if not IsDigits(hourText) or not IsDigits(minuteText) then return invalid
    hour = hourText.ToInt()
    minute = minuteText.ToInt()
    if hour > 23 or minute > 59 then return invalid
    return sign * ((hour * 3600) + (minute * 60))
end function

function IsClock(text as string) as boolean
    if Len(text) <> 8 then return false
    if CharAt(text, 3) <> ":" or CharAt(text, 6) <> ":" then return false
    hourText = Left(text, 2)
    minuteText = Slice(text, 4, 2)
    secondText = Right(text, 2)
    if not IsDigits(hourText) or not IsDigits(minuteText) or not IsDigits(secondText) then return false
    hour = hourText.ToInt()
    minute = minuteText.ToInt()
    second = secondText.ToInt()
    if hour > 23 or minute > 59 or second > 59 then return false
    return true
end function

function IsDigits(text as string) as boolean
    if text = "" then return false
    index = 1
    while index <= Len(text)
        code = Asc(CharAt(text, index))
        if code < 48 or code > 57 then return false
        index = index + 1
    end while
    return true
end function

function DaysInMonth(year as integer, month as integer) as integer
    if month = 2
        if IsLeapYear(year) then return 29
        return 28
    end if
    if month = 4 or month = 6 or month = 9 or month = 11 then return 30
    return 31
end function

function IsLeapYear(year as integer) as boolean
    if (year mod 400) = 0 then return true
    if (year mod 100) = 0 then return false
    if (year mod 4) = 0 then return true
    return false
end function

function SanitizeNamePart(raw as object) as string
    if raw = invalid then return ""
    kind = type(raw)
    if kind <> "String" and kind <> "roString" then return ""
    text = NormalizeName(raw.Trim())
    text = CollapseSpaces(text)
    if text = "" then return ""
    if not NameCharsOk(text) then return ""
    if not HasLetter(text) then return ""
    if Len(text) > NamePartLimit()
        text = StripTrailingPunct(Left(text, NamePartLimit()))
    end if
    if text = "" or not HasLetter(text) then return ""
    return text
end function

function NormalizeName(text as string) as string
    out = ""
    index = 1
    while index <= Len(text)
        ch = CharAt(text, index)
        code = Asc(ch)
        if code = 8217 or code = 8216 or code = 700
            out = out + "'"
        else if code = 8211 or code = 8212
            out = out + "-"
        else if code = 160
            out = out + " "
        else
            out = out + ch
        end if
        index = index + 1
    end while
    return out
end function

function CollapseSpaces(text as string) as string
    out = ""
    index = 1
    while index <= Len(text)
        ch = CharAt(text, index)
        if ch <> " "
            if out <> "" and CharAt(text, index - 1) = " " then out = out + " "
            out = out + ch
        end if
        index = index + 1
    end while
    return out
end function

function NameCharsOk(text as string) as boolean
    index = 1
    while index <= Len(text)
        code = Asc(CharAt(text, index))
        if not IsNameLetter(code) and not IsNamePunct(code) then return false
        index = index + 1
    end while
    return true
end function

function HasLetter(text as string) as boolean
    index = 1
    while index <= Len(text)
        if IsNameLetter(Asc(CharAt(text, index))) then return true
        index = index + 1
    end while
    return false
end function

function IsNameLetter(code as integer) as boolean
    if code >= 65 and code <= 90 then return true
    if code >= 97 and code <= 122 then return true
    if code >= 192 and code <= 255
        if code = 215 or code = 247 then return false
        return true
    end if
    if code >= 256 and code <= 383 then return true
    return false
end function

function IsNamePunct(code as integer) as boolean
    if code = 32 or code = 39 or code = 45 or code = 46 then return true
    return false
end function

function StripTrailingPunct(text as string) as string
    while Len(text) > 0
        last = CharAt(text, Len(text))
        if last = " " or last = "-" or last = "'" or last = "."
            text = Left(text, Len(text) - 1)
        else
            exit while
        end if
    end while
    return text
end function

function CharAt(text as string, index as integer) as string
    if text = invalid or index < 1 or index > Len(text) then return ""
    ' The first character is Left(), not Right(Left(), 1). The brs
    ' interpreter returns an empty string for Right() of a one-character
    ' string; the device does not, and Left() agrees on both.
    if index = 1 then return Left(text, 1)
    return Right(Left(text, index), 1)
end function

function Slice(text as string, start as integer, length as integer) as string
    if text = invalid or start < 1 or length < 1 or start > Len(text) then return ""
    trimmed = text
    if start > 1 then trimmed = Right(text, Len(text) - (start - 1))
    if Len(trimmed) <= length then return trimmed
    return Left(trimmed, length)
end function

' Break on spaces and hyphens, matching Label wrap. A token wider than the
' line breaks mid-word. font may be invalid; charWidth is the fallback.
function WrapGreeting(text as string, maxWidth as integer, font as object, charWidth as integer) as object
    lines = []
    if text = invalid then return lines
    if type(text) <> "String" and type(text) <> "roString" then return lines
    if text = "" or maxWidth < 1 then return lines
    remaining = text
    guard = 0
    while Len(remaining) > 0
        guard = guard + 1
        if guard > 12
            lines.Push("overflow")
            exit while
        end if
        if MeasureText(remaining, font, charWidth) <= maxWidth
            lines.Push(remaining)
            exit while
        end if
        count = LongestPrefix(remaining, maxWidth, font, charWidth)
        if count < 1 then count = 1
        breakAt = PreferredBreak(remaining, count)
        if breakAt < 1 then breakAt = 1
        piece = Left(remaining, breakAt)
        if Len(piece) > 1 and Right(piece, 1) = " " then piece = Left(piece, Len(piece) - 1)
        if piece = "" or piece = " "
            piece = Left(remaining, 1)
            breakAt = 1
        end if
        lines.Push(piece)
        if breakAt >= Len(remaining) then exit while
        remaining = Right(remaining, Len(remaining) - breakAt)
        while Len(remaining) > 0 and Left(remaining, 1) = " "
            remaining = Right(remaining, Len(remaining) - 1)
        end while
    end while
    return lines
end function

function LongestPrefix(text as string, maxWidth as integer, font as object, charWidth as integer) as integer
    if MeasureText(Left(text, 1), font, charWidth) > maxWidth then return 1
    best = 1
    index = 2
    limit = Len(text)
    while index <= limit
        if MeasureText(Left(text, index), font, charWidth) > maxWidth then return best
        best = index
        index = index + 1
    end while
    return best
end function

function PreferredBreak(text as string, count as integer) as integer
    if count > Len(text) then count = Len(text)
    if count < 1 then return 1
    index = count
    while index >= 1
        ch = CharAt(text, index)
        if ch = " " or ch = "-" then return index
        index = index - 1
    end while
    return count
end function

function MeasureText(text as string, font as object, charWidth as integer) as integer
    if text = invalid or text = "" then return 0
    if font <> invalid
        width = font.GetOneLineWidth(text, 20000)
        if width <> invalid and width > 0 then return width
    end if
    if charWidth < 1 then charWidth = 1
    return Len(text) * charWidth
end function

function FallbackCharWidth(size as integer) as integer
    width = (size * 3) \ 4
    if width < 1 then return 1
    return width
end function

function GreetingBarBox(lineCount as integer, lineHeight as integer) as object
    if lineCount < 1 then lineCount = 1
    if lineCount > 2 then lineCount = 2
    if lineHeight < 1 then lineHeight = 64
    barHeight = (lineCount * lineHeight) + GreetingBarPad()
    if barHeight < GreetingBarMinHeight() then barHeight = GreetingBarMinHeight()
    top = GreetingBarBottom() - barHeight
    if top < GreetingMinTop()
        top = GreetingMinTop()
        barHeight = GreetingBarBottom() - top
    end if
    return { barTop: top, barHeight: barHeight }
end function

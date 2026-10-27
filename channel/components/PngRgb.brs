' Indexed rewrite for QR PNGs.
' Production QR files are 8-bit grayscale (color type 0). Poster draws color
' type 2, 3, and 6, and leaves color type 0 blank. Color type 0 and color type 3
' use the same scanlines, so a gray palette is enough. IDAT stays compressed.

function ExpandPngBytes(src as object) as object
    buf = AsBuf(src)
    result = PngResult()
    parsed = ReadPng(buf)
    if parsed.ok <> true
        result.reason = parsed.reason
        return result
    end if
    result.width = parsed.width
    result.height = parsed.height
    result.bit = parsed.bit
    result.color = parsed.color
    result.interlace = parsed.interlace
    if parsed.interlace <> 0
        result.reason = "interlace"
        return result
    end if
    if parsed.bit <> 8
        result.reason = "bitdepth"
        return result
    end if
    if parsed.color = 2 or parsed.color = 3 or parsed.color = 6
        result.ok = true
        result.reason = "ok"
        result.converted = false
        result.bytes = buf
        return result
    end if
    if parsed.color <> 0
        result.reason = "colortype"
        return result
    end if
    built = RewriteGrayPng(buf, parsed)
    if built = invalid
        result.reason = "encode"
        return result
    end if
    result.ok = true
    result.reason = "ok"
    result.converted = true
    result.bytes = built
    return result
end function

function ExpandPngFile(srcPath as string, destPath as string) as object
    wrapped = ReadFileBytes(srcPath)
    if wrapped = invalid
        result = PngResult()
        result.reason = "bad-png"
        result.path = ""
        return result
    end if
    result = ExpandPngBytes(wrapped)
    result.path = ""
    if result.ok <> true then return result
    if result.converted <> true and srcPath = destPath
        result.path = destPath
        return result
    end if
    stored = StorePngBytes(result.bytes, destPath, TmpFallbackPath(destPath))
    if stored <> ""
        result.path = stored
        return result
    end if
    result.ok = false
    result.reason = "cache-write"
    result.path = ""
    return result
end function

function SafeUri(url as string) as string
    if url = invalid or url = "" then return "none"
    text = url
    query = Instr(1, text, "?")
    if query > 0 then text = Left(text, query - 1)
    marker = "/tv/"
    at = Instr(1, text, marker)
    if at < 1 then return text
    head = Left(text, at + Len(marker) - 1)
    rest = ""
    cut = at + Len(marker) - 1
    if cut < Len(text) then rest = Right(text, Len(text) - cut)
    slash = Instr(1, rest, "/")
    if slash > 1 then return head + "***" + Mid(rest, slash)
    return head + "***"
end function

function PngResult() as object
    return {
        ok: false,
        reason: "bad-png",
        width: 0,
        height: 0,
        bit: 0,
        color: -1,
        interlace: 0,
        converted: false,
        bytes: invalid,
        path: ""
    }
end function

function RewriteGrayPng(buf as object, parsed as object) as object
    if parsed.idat = invalid or parsed.idat.n < 1 then return invalid
    plte = MakeBuf(768)
    for shade = 0 to 255
        at = shade * 3
        BufSet(plte, at, shade)
        BufSet(plte, at + 1, shade)
        BufSet(plte, at + 2, shade)
    end for
    header = MakeBuf(13)
    WriteLongBuf(header, 0, parsed.width)
    WriteLongBuf(header, 4, parsed.height)
    BufSet(header, 8, 8)
    BufSet(header, 9, 3)
    idatBytes = IdatsRawSize(buf)
    if idatBytes < 12 then return invalid
    out = MakeBuf(8 + 25 + 12 + 768 + idatBytes + 12)
    writer = { buf: out, at: 0, table: CrcTable() }
    WriteBytes(writer, [137, 80, 78, 71, 13, 10, 26, 10])
    WriteChunk(writer, [73, 72, 68, 82], header)
    WriteChunk(writer, [80, 76, 84, 69], plte)
    if CopyIdatChunks(writer, buf) <> true then return invalid
    WriteChunk(writer, [73, 69, 78, 68], MakeBuf(0))
    if writer.at <> out.n then return invalid
    return out
end function

function IdatsRawSize(buf as object) as integer
    total = 0
    cursor = 8
    guard = 0
    while cursor + 8 <= buf.n and guard < 64
        guard = guard + 1
        length = LongAt(buf, cursor)
        if length < 0 or cursor + 12 + length > buf.n then return 0
        if ChunkName(buf, cursor + 4) = "IDAT" then total = total + 12 + length
        if ChunkName(buf, cursor + 4) = "IEND" then exit while
        cursor = cursor + 12 + length
    end while
    return total
end function

function CopyIdatChunks(writer as object, buf as object) as boolean
    cursor = 8
    guard = 0
    copied = 0
    while cursor + 8 <= buf.n and guard < 64
        guard = guard + 1
        length = LongAt(buf, cursor)
        if length < 0 or cursor + 12 + length > buf.n then return false
        kind = ChunkName(buf, cursor + 4)
        if kind = "IDAT"
            last = 11 + length
            for index = 0 to last
                WriteByte(writer, BufAt(buf, cursor + index))
            end for
            copied = copied + 1
        end if
        if kind = "IEND" then exit while
        cursor = cursor + 12 + length
    end while
    if copied > 0 then return true
    return false
end function

function ReadFileBytes(path as string) as object
    raw = CreateObject("roByteArray")
    if raw = invalid then return invalid
    if raw.ReadFile(path) <> true then return invalid
    if raw.Count() < 8 then return invalid
    return AsBuf(raw)
end function

function TmpFallbackPath(cachePath as string) as string
    marker = "cachefs:/"
    if cachePath = invalid or cachePath = "" then return "tmp:/eaglewood/qr-fallback.png"
    if Left(cachePath, Len(marker)) = marker then return "tmp:/" + Mid(cachePath, Len(marker) + 1)
    return "tmp:/eaglewood/qr-fallback.png"
end function

function StorePngBytes(buf as object, cachePath as string, tmpPath as string) as string
    if WriteBufToFile(cachePath, buf) = true then return cachePath
    if tmpPath <> invalid and tmpPath <> "" and tmpPath <> cachePath
        if WriteBufToFile(tmpPath, buf) = true then return tmpPath
    end if
    return ""
end function

' RGB files stay as the bytes roUrlTransfer wrote. ReadFile then WriteFile is the
' copy that already works for wifi.png. A grayscale file is still rewritten.
function PlacePngFile(srcPath as string, destPath as string) as object
    raw = CreateObject("roByteArray")
    failed = PngResult()
    failed.reason = "bad-png"
    if raw = invalid or raw.ReadFile(srcPath) <> true or raw.Count() < 24 then return failed
    parsed = ExpandPngBytes(AsBuf(raw))
    if parsed.ok <> true then return parsed
    stored = ""
    if parsed.converted = true
        stored = StorePngBytes(parsed.bytes, destPath, TmpFallbackPath(destPath))
    else
        stored = WriteRawPng(raw, destPath)
        if stored = "" then stored = WriteRawPng(raw, TmpFallbackPath(destPath))
    end if
    if stored = ""
        parsed.ok = false
        parsed.reason = "cache-write"
        parsed.path = ""
        return parsed
    end if
    parsed.path = stored
    return parsed
end function

function WriteRawPng(raw as object, path as string) as string
    if raw = invalid or path = invalid or path = "" then return ""
    if EnsureParentDir(path) <> true then return ""
    fs = CreateObject("roFileSystem")
    if fs <> invalid then fs.Delete(path)
    wrote = raw.WriteFile(path)
    print "Eaglewood: file write path="; path; " result="; WriteResultText(wrote); " bytes="; raw.Count()
    if wrote <> true then return ""
    if FileSize(path) = 0 then return ""
    return path
end function

function WriteBufToFile(path as string, buf as object) as boolean
    if buf = invalid or path = invalid or path = "" or buf.n < 8 then return false
    EnsureParentDir(path)
    out = CopyToByteArray(buf)
    if out = invalid
        print "Eaglewood: file write path="; path; " result=no-bytes"
        return false
    end if
    fs = CreateObject("roFileSystem")
    if fs <> invalid then fs.Delete(path)
    wrote = out.WriteFile(path)
    print "Eaglewood: file write path="; path; " result="; WriteResultText(wrote); " bytes="; out.Count()
    if wrote <> true then return false
    size = FileSize(path)
    if size = 0 then return false
    return true
end function

function CopyToByteArray(buf as object) as object
    if buf = invalid or buf.n < 1 then return invalid
    out = CreateObject("roByteArray")
    if out = invalid then return invalid
    last = buf.n - 1
    for index = 0 to last
        out.Push(BufAt(buf, index))
        if out.Count() <> index + 1 then return ByteArrayFromHex(buf)
    end for
    if out.Count() = buf.n then return out
    return ByteArrayFromHex(buf)
end function

function ByteArrayFromHex(buf as object) as object
    hex = ""
    last = buf.n - 1
    if last < 0 then return invalid
    for index = 0 to last
        hex = hex + HexByte(BufAt(buf, index))
    end for
    out = CreateObject("roByteArray")
    if out = invalid then return invalid
    out.FromHexString(hex)
    if out.Count() <> buf.n then return invalid
    return out
end function

function HexByte(value as integer) as string
    digits = "0123456789ABCDEF"
    hi = value \ 16
    lo = value mod 16
    if hi < 0 or hi > 15 then hi = 0
    if lo < 0 or lo > 15 then lo = 0
    return Mid(digits, hi + 1, 1) + Mid(digits, lo + 1, 1)
end function

function EnsureParentDir(path as string) as boolean
    parent = ParentPath(path)
    if parent = "" then return false
    fs = CreateObject("roFileSystem")
    if fs = invalid
        print "Eaglewood: file write path="; parent; " result=no-fs"
        return false
    end if
    if fs.Stat(parent) <> invalid
        print "Eaglewood: file write path="; parent; " result=exists"
        return true
    end if
    made = fs.CreateDirectory(parent)
    print "Eaglewood: file write path="; parent; " result="; WriteResultText(made)
    if made = true then return true
    if fs.Stat(parent) <> invalid then return true
    return false
end function

function ParentPath(path as string) as string
    if path = invalid or path = "" then return ""
    slash = 0
    index = Len(path)
    while index > 0
        if Mid(path, index, 1) = "/"
            slash = index
            exit while
        end if
        index = index - 1
    end while
    if slash < 2 then return ""
    return Left(path, slash - 1)
end function

function FileSize(path as string) as integer
    fs = CreateObject("roFileSystem")
    if fs = invalid then return -1
    stat = fs.Stat(path)
    if stat = invalid or stat.size = invalid then return -1
    return stat.size
end function

function QrContentFileName(slot as string, tag as string) as string
    clean = DigestTagFromHex(tag)
    if clean = "" or slot = invalid or slot = "" then return ""
    return "qr-" + slot + "-" + clean + ".png"
end function

function QrTempFileName(slot as string, tag as string) as string
    clean = DigestTagFromHex(tag)
    if clean = "" or slot = invalid or slot = "" then return ""
    return "qr-" + slot + "-" + clean + ".tmp"
end function

' First 8 hex chars of an MD5. Empty input stays empty so a missed digest
' cannot become qr-book-.tmp or qr-book-00000000.png.
function DigestTagFromHex(hex as string) as string
    if hex = invalid then return ""
    clean = LCase(hex)
    if Len(clean) < 8 then return ""
    return Left(clean, 8)
end function

function PngDigestTag(raw as object) as string
    if raw = invalid then return ""
    digest = CreateObject("roEVPDigest")
    if digest = invalid then return ""
    ready = digest.Setup("md5")
    if ready = false or ready = 0 or ready = invalid then return ""
    digest.Process(raw)
    sum = digest.Final()
    if sum = invalid then return ""
    return DigestTagFromHex(sum.ToHexString())
end function

function QrReadLength(path as string) as integer
    if path = invalid or path = "" then return -1
    raw = CreateObject("roByteArray")
    if raw = invalid then return -1
    if raw.ReadFile(path) <> true then return -1
    count = raw.Count()
    if count = invalid then return -1
    return count
end function

function PathIsBusy(path as string, busy as string) as boolean
    if path = invalid or path = "" or busy = invalid or busy = "" then return false
    return Instr(1, "|" + busy + "|", "|" + path + "|") > 0
end function

' Write tmp, then Rename. roFileSystem has no MoveFile. An existing content
' file is reused. A file named in busy is never deleted or replaced.
function CommitQrBytes(slot as string, raw as object, busy as string) as string
    if raw = invalid or slot = invalid or slot = "" then return ""
    count = raw.Count()
    if count = invalid or count < 8 then return ""
    tag = PngDigestTag(raw)
    fileName = QrContentFileName(slot, tag)
    tempName = QrTempFileName(slot, tag)
    if fileName = "" or tempName = "" then return ""
    stored = PlaceNewPng(raw, "cachefs:/eaglewood/" + fileName, "cachefs:/eaglewood/" + tempName, busy, slot)
    if stored <> "" then return stored
    return PlaceNewPng(raw, "tmp:/eaglewood/" + fileName, "tmp:/eaglewood/" + tempName, busy, slot)
end function

function PlaceNewPng(raw as object, finalPath as string, tmpPath as string, busy as string, slot as string) as string
    count = raw.Count()
    if EnsureParentDir(finalPath) <> true then return ""
    existing = QrReadLength(finalPath)
    if existing = count
        print "Eaglewood: qr "; slot; " file bytes="; count; " read="; existing
        return finalPath
    end if
    if existing > 0
        if PathIsBusy(finalPath, busy) then return ""
        fs = CreateObject("roFileSystem")
        if fs <> invalid then fs.Delete(finalPath)
    end if
    if EnsureParentDir(tmpPath) <> true then return ""
    wrote = raw.WriteFile(tmpPath)
    readBack = QrReadLength(tmpPath)
    print "Eaglewood: qr "; slot; " file bytes="; count; " read="; readBack
    if wrote <> true or readBack <> count then return ""
    if PathIsBusy(finalPath, busy) then return ""
    fs = CreateObject("roFileSystem")
    if fs = invalid then return ""
    renamed = fs.Rename(tmpPath, finalPath)
    if renamed = false or renamed = 0 or renamed = invalid then return ""
    if QrReadLength(finalPath) <> count then return ""
    return finalPath
end function

function WriteResultText(value as object) as string
    if value = invalid then return "invalid"
    if value = true then return "true"
    if value = false then return "false"
    return value.ToStr()
end function

' Drop old QR files before any fetch starts. wifi.png stays. A path a Poster
' is using is left in place.
sub ClearStaleQrCache(busy as string)
    version = "rgb2"
    if busy = invalid then busy = ""
    DeleteStaleQrFiles("cachefs:/eaglewood", busy)
    DeleteStaleQrFiles("tmp:/eaglewood", busy)
    DeleteStaleQrFiles("tmp:/", busy)
    section = CreateObject("roRegistrySection", "EaglewoodGuide")
    if section <> invalid
        section.Write("qrCacheVersion", version)
        section.Flush()
    end if
    print "Eaglewood: qr cache cleared version="; version
end sub

sub DeleteStaleQrFiles(dir as string, busy as string)
    fs = CreateObject("roFileSystem")
    if fs = invalid or dir = invalid or dir = "" then return
    known = ["qr-badge.png", "qr-book.png", "qr-detail.png", "qr-next.png", "qr-badge.url", "qr-book.url", "qr-detail.url", "qr-badge.path", "qr-book.path", "qr-detail.path", "qr-fallback.png"]
    last = known.Count() - 1
    for index = 0 to last
        DeleteOneQrFile(fs, JoinFs(dir, known[index]), busy)
    end for
    listing = fs.GetDirectoryListing(dir)
    if listing = invalid then return
    count = listing.Count()
    if count = invalid or count < 1 then return
    last = count - 1
    for index = 0 to last
        name = listing[index]
        if StaleQrCacheName(name) then DeleteOneQrFile(fs, JoinFs(dir, name), busy)
    end for
end sub

function JoinFs(dir as string, name as string) as string
    if dir = invalid or dir = "" then return name
    if Right(dir, 1) = "/" then return dir + name
    return dir + "/" + name
end function

function StaleQrCacheName(name as object) as boolean
    if name = invalid then return false
    kind = type(name)
    if kind <> "String" and kind <> "roString" then return false
    if Instr(1, name, "/") > 0 or Instr(1, name, ":") > 0 then return false
    lower = LCase(name)
    if Left(lower, 4) = "wifi" then return false
    if Instr(1, lower, "qr") < 1 then return false
    if Right(lower, 4) = ".png" then return true
    if Right(lower, 4) = ".url" then return true
    if Right(lower, 4) = ".tmp" then return true
    if Right(lower, 5) = ".path" then return true
    return false
end function

sub DeleteOneQrFile(fs as object, path as string, busy as string)
    if fs = invalid or path = invalid or path = "" then return
    if fs.Stat(path) = invalid then return
    if PathIsBusy(path, busy) then return
    removed = fs.Delete(path)
    print "Eaglewood: qr cache delete path="; path; " result="; WriteResultText(removed)
end sub

function LiveQrPathList() as string
    text = ""
    text = AppendLivePath(text, FieldPath(m.badgeFile))
    text = AppendLivePath(text, FieldPath(m.bookFile))
    text = AppendLivePath(text, FieldPath(m.detailFile))
    text = AppendLivePath(text, FieldPath(m.wifiFile))
    text = AppendLivePath(text, NodeUri(m.badgePoster))
    text = AppendLivePath(text, NodeUri(m.bookQr))
    text = AppendLivePath(text, NodeUri(m.detailQr))
    text = AppendLivePath(text, NodeUri(m.wifiPoster))
    return text
end function

function AppendLivePath(text as string, path as string) as string
    if path = invalid or path = "" then return text
    if PathIsBusy(path, text) then return text
    if text = "" then return path
    return text + "|" + path
end function

function FieldPath(value as object) as string
    if value = invalid then return ""
    kind = type(value)
    if kind <> "String" and kind <> "roString" then return ""
    return value
end function

function NodeUri(node as object) as string
    if node = invalid then return ""
    uri = node.uri
    if uri = invalid then return ""
    return uri
end function


function AsBuf(src as object) as object
    if src = invalid then return { data: [], n: 0 }
    if type(src) = "roAssociativeArray" then return src
    count = src.Count()
    if count = invalid then count = 0
    return { data: src, n: count }
end function

function MakeBuf(size as integer) as object
    if size < 0 then size = 0
    raw = CreateObject("roByteArray")
    if raw <> invalid
        raw.SetResize(size, true)
        if raw.Count() >= size then return { data: raw, n: size }
    end if
    return { data: CreateObject("roArray", size, false), n: size }
end function

function BufAt(buf as object, index as integer) as integer
    if buf = invalid or index < 0 or index >= buf.n then return 0
    value = buf.data[index]
    if value = invalid then return 0
    return value
end function

sub BufSet(buf as object, index as integer, value as integer)
    if buf = invalid or index < 0 or index >= buf.n then return
    buf.data[index] = value
end sub

function ReadPng(buf as object) as object
    parsed = { ok: false, reason: "bad-png", width: 0, height: 0, bit: 0, color: -1, interlace: 0, idat: AsBuf([]), plte: invalid }
    if buf = invalid or buf.n < 8 then return parsed
    if BufAt(buf, 0) <> 137 or BufAt(buf, 1) <> 80 or BufAt(buf, 2) <> 78 or BufAt(buf, 3) <> 71 then return parsed
    if BufAt(buf, 4) <> 13 or BufAt(buf, 5) <> 10 or BufAt(buf, 6) <> 26 or BufAt(buf, 7) <> 10 then return parsed
    idat = []
    plte = []
    sawHeader = false
    cursor = 8
    guard = 0
    while cursor + 8 <= buf.n and guard < 64
        guard = guard + 1
        length = LongAt(buf, cursor)
        if length < 0 or cursor + 12 + length > buf.n then return parsed
        kind = ChunkName(buf, cursor + 4)
        dataAt = cursor + 8
        if kind = "IHDR"
            if length <> 13 then return parsed
            parsed.width = LongAt(buf, dataAt)
            parsed.height = LongAt(buf, dataAt + 4)
            parsed.bit = BufAt(buf, dataAt + 8)
            parsed.color = BufAt(buf, dataAt + 9)
            parsed.interlace = BufAt(buf, dataAt + 12)
            sawHeader = true
        else if kind = "IDAT"
            last = length - 1
            if last >= 0
                for index = 0 to last
                    idat.Push(BufAt(buf, dataAt + index))
                end for
            end if
        else if kind = "PLTE"
            last = length - 1
            if last >= 0
                for index = 0 to last
                    plte.Push(BufAt(buf, dataAt + index))
                end for
            end if
        else if kind = "IEND"
            exit while
        end if
        cursor = cursor + 12 + length
    end while
    if sawHeader <> true then return parsed
    parsed.ok = true
    parsed.reason = "ok"
    parsed.idat = AsBuf(idat)
    if plte.Count() > 0 then parsed.plte = AsBuf(plte)
    return parsed
end function

function LongAt(buf as object, index as integer) as integer
    return (BufAt(buf, index) * 16777216) + (BufAt(buf, index + 1) * 65536) + (BufAt(buf, index + 2) * 256) + BufAt(buf, index + 3)
end function

function ChunkName(buf as object, index as integer) as string
    return Chr(BufAt(buf, index)) + Chr(BufAt(buf, index + 1)) + Chr(BufAt(buf, index + 2)) + Chr(BufAt(buf, index + 3))
end function

sub WriteChunk(writer as object, typeBytes as object, data as object)
    dataN = 0
    if data <> invalid then dataN = data.n
    WriteLong(writer, dataN)
    start = writer.at
    WriteBytes(writer, typeBytes)
    if dataN > 0
        last = dataN - 1
        for index = 0 to last
            WriteByte(writer, BufAt(data, index))
        end for
    end if
    crc = CrcRange(writer.buf, start, writer.at - start, writer.table)
    WriteByte(writer, crc.hi \ 256)
    WriteByte(writer, crc.hi mod 256)
    WriteByte(writer, crc.lo \ 256)
    WriteByte(writer, crc.lo mod 256)
end sub

sub WriteBytes(writer as object, bytes as object)
    last = bytes.Count() - 1
    if last < 0 then return
    for index = 0 to last
        WriteByte(writer, bytes[index])
    end for
end sub

sub WriteByte(writer as object, value as integer)
    BufSet(writer.buf, writer.at, value)
    writer.at = writer.at + 1
end sub

sub WriteLong(writer as object, value as integer)
    WriteByte(writer, value \ 16777216)
    rest = value mod 16777216
    WriteByte(writer, rest \ 65536)
    rest = rest mod 65536
    WriteByte(writer, rest \ 256)
    WriteByte(writer, rest mod 256)
end sub

sub WriteLongBuf(buf as object, index as integer, value as integer)
    BufSet(buf, index, value \ 16777216)
    rest = value mod 16777216
    BufSet(buf, index + 1, rest \ 65536)
    rest = rest mod 65536
    BufSet(buf, index + 2, rest \ 256)
    BufSet(buf, index + 3, rest mod 256)
end sub

function CrcTable() as object
    table = []
    for value = 0 to 255
        hi = 0
        lo = value
        for bit = 0 to 7
            if (lo mod 2) = 1
                shifted = ShrPair(hi, lo)
                hi = Xor16(shifted.hi, 60856)
                lo = Xor16(shifted.lo, 33568)
            else
                shifted = ShrPair(hi, lo)
                hi = shifted.hi
                lo = shifted.lo
            end if
        end for
        table.Push(hi)
        table.Push(lo)
    end for
    return table
end function

function CrcRange(buf as object, start as integer, length as integer, table as object) as object
    hi = 65535
    lo = 65535
    if length > 0
        last = start + length - 1
        for index = start to last
            mixed = XorByte(lo mod 256, BufAt(buf, index))
            entry = mixed * 2
            shiftedLo = (lo \ 256) + ((hi mod 256) * 256)
            shiftedHi = hi \ 256
            hi = Xor16(shiftedHi, table[entry])
            lo = Xor16(shiftedLo, table[entry + 1])
        end for
    end if
    return { hi: Xor16(hi, 65535), lo: Xor16(lo, 65535) }
end function

function ShrPair(hi as integer, lo as integer) as object
    return { hi: hi \ 2, lo: (lo \ 2) + ((hi mod 2) * 32768) }
end function

function Xor16(left as integer, right as integer) as integer
    return (XorByte(left \ 256, right \ 256) * 256) + XorByte(left mod 256, right mod 256)
end function

function XorByte(left as integer, right as integer) as integer
    return (XorNibble(left \ 16, right \ 16) * 16) + XorNibble(left mod 16, right mod 16)
end function

function XorNibble(left as integer, right as integer) as integer
    result = 0
    place = 1
    for bit = 0 to 3
        if (left mod 2) <> (right mod 2) then result = result + place
        left = left \ 2
        right = right \ 2
        place = place * 2
    end for
    return result
end function

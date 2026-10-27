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
        return result
    end if
    result = ExpandPngBytes(wrapped)
    if result.ok <> true then return result
    if result.converted <> true and srcPath = destPath then return result
    if WriteBufToFile(destPath, result.bytes) <> true
        result.ok = false
        result.reason = "cache-write"
    end if
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
        bytes: invalid
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

function WriteBufToFile(path as string, buf as object) as boolean
    if buf = invalid then return false
    raw = buf.data
    if type(raw) = "roByteArray" and raw.Count() = buf.n
        wrote = raw.WriteFile(path)
        if wrote = true then return true
        return false
    end if
    out = CreateObject("roByteArray")
    if out = invalid then return false
    out.SetResize(buf.n, true)
    if out.Count() < buf.n then return false
    last = buf.n - 1
    if last >= 0
        for index = 0 to last
            out[index] = BufAt(buf, index)
        end for
    end if
    wrote = out.WriteFile(path)
    if wrote = true then return true
    return false
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

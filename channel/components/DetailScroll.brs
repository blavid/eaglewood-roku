sub init()
    m.frame = m.top.findNode("frame")
    m.text = m.top.findNode("bodyText")
    m.hint = m.top.findNode("hint")
    m.top.scrollText = m.text
    onFrame()
end sub

sub onFrame()
    if m.frame = invalid or m.text = invalid then return
    wide = m.top.frameWidth
    tall = m.top.frameHeight
    if wide = invalid or wide < 80 then wide = 1132
    if tall = invalid or tall < 80 then tall = 412
    padding = 20
    m.frame.width = wide
    m.frame.height = tall
    m.text.width = wide - (padding * 2)
    m.text.height = tall - 92
    m.text.translation = [padding, padding]
    if m.hint <> invalid
        m.hint.translation = [padding, tall - 52]
        m.hint.width = m.text.width
    end if
end sub

sub onBody()
    if m.text <> invalid then m.text.text = m.top.body
end sub

sub focusBody()
    if m.text <> invalid then m.text.setFocus(true)
end sub

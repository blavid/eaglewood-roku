sub init()
    m.list = m.top.findNode("list")
    m.top.list = m.list
    m.list.observeField("itemSelected", "onSelected")
    m.list.observeField("itemFocused", "onFocused")
    m.top.observeField("focusedChild", "onFocusedChild")
end sub

' LabelListPanel: when the panel is in the focus chain, the list takes the remote.
sub onFocusedChild()
    if m.top.isInFocusChain()
        if m.list.hasFocus() <> true then m.list.setFocus(true)
    end if
end sub

sub onSelected()
    m.top.selectedIndex = m.list.itemSelected
end sub

sub onFocused()
    m.top.focusedIndex = m.list.itemFocused
end sub

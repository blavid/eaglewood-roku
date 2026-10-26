sub Main()
    tests = [
        { input: "", expect: "" },
        { input: "   ", expect: "" },
        { input: "Alex", expect: "Alex" },
        { input: "Alex Rivera", expect: "Alex" },
        { input: "Mary-Jane", expect: "Mary-Jane" },
        { input: "O'Brien", expect: "O'Brien" },
        { input: "A", expect: "A" },
        { input: "Alex123", expect: "" },
        { input: "-Alex", expect: "" },
        { input: "Alex-", expect: "" },
        { input: "O'", expect: "" },
        { input: "Jose!", expect: "" },
        { input: "ABCDEFGHIJKLMNOPQRS-X", expect: "ABCDEFGHIJKLMNOPQRS" }
    ]
    failed = 0
    for each item in tests
        actual = SanitizeFirstName(item.input)
        if actual <> item.expect
            print "FAIL [" ; item.input ; "] got [" ; actual ; "] want [" ; item.expect ; "]"
            failed = failed + 1
        end if
    end for
    if BuildGreeting() <> "Welcome to Eaglewood"
        print "FAIL default greeting"
        failed = failed + 1
    end if
    if failed = 0
        print "brs greeting checks passed"
    else
        print "brs greeting checks failed"
    end if
end sub

' Package replaces the placeholder with the short git commit.
function BuildCommit() as string
    return "unknown"
end function

function BuildStampLine() as string
    return "build 17 · " + BuildCommit()
end function

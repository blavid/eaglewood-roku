# Zip the channel with manifest at the archive root.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$channel = Join-Path $root "channel"
$out = Join-Path $root "dist"
$zipPath = Join-Path $out "eaglewood.zip"
$limit = 4MB

New-Item -ItemType Directory -Force -Path $out | Out-Null
if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    Get-ChildItem -Path $channel -Recurse -File | ForEach-Object {
        if ($_.Name -eq ".DS_Store") { return }
        $relative = $_.FullName.Substring($channel.Length).TrimStart("\", "/").Replace("\", "/")
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $_.FullName,
            $relative,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $archive.Dispose()
}

$bytes = (Get-Item $zipPath).Length
Write-Host "Packaged $zipPath ($bytes bytes)"
if ($bytes -gt $limit) {
    Write-Error "Package is $bytes bytes, over the 4 MB certification limit."
    exit 1
}

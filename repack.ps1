# repack.ps1 - Windows build for FS25_ValleyLife
# FS25 loads mods from Documents\My Games\FarmingSimulator2025\mods, NOT this repo folder.
# Windows equivalent of repack.sh (which targets macOS). Run from anywhere:  .\repack.ps1
#
# NOTE: builds the zip entry-by-entry with forward-slash ('/') paths on purpose.
# PowerShell's Compress-Archive writes backslash separators, which the GIANTS engine
# can fail to resolve for files in subfolders (e.g. source("src/scripts/...")).
$ErrorActionPreference = 'Stop'

$Project = $PSScriptRoot
$ModsDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\FarmingSimulator2025\mods'
$Dest    = Join-Path $ModsDir 'FS25_ValleyLife.zip'

# Exclusions mirror repack.sh: VCS, editor, dev-only docs/notes, prior zips, build scripts.
$excludeDirs  = @('.git', '.claude', '.cursor', 'journals', 'docs', 'memory')
$excludeFiles = @('repack.sh', 'repack.ps1', '.DS_Store')

$files = Get-ChildItem -Path $Project -Recurse -File | Where-Object {
    $rel = $_.FullName.Substring($Project.Length).TrimStart('\')
    $top = ($rel -split '\\')[0]
    ($excludeDirs -notcontains $top) -and
    ($excludeFiles -notcontains $_.Name) -and
    ($_.Extension -ne '.zip')
}

New-Item -ItemType Directory -Path $ModsDir -Force | Out-Null
if (Test-Path $Dest) { Remove-Item $Dest -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($Dest, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($f in $files) {
        $entryName = $f.FullName.Substring($Project.Length).TrimStart('\').Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $f.FullName, $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}
finally {
    $zip.Dispose()
}

Write-Host "Packed $($files.Count) files -> $Dest"
Get-Item $Dest | Select-Object Name, Length, LastWriteTime | Format-List

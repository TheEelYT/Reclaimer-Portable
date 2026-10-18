param (
    [string] $Version = '2.1.1644.1',
    [string] $OutputDirectory = (Join-Path $PSScriptRoot '../artifacts')
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$studioRoot = Join-Path (Split-Path $repoRoot -Parent) 'Studio'
$studioCommit = '3c3b68a4e0bd330d31f8ec41e85c6751e46bfe86'
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)

if (!(Test-Path (Join-Path $studioRoot 'Studio/Studio.csproj'))) {
    if (Test-Path $studioRoot) { throw "Studio directory exists but does not contain Studio/Studio.csproj: $studioRoot" }
    git clone https://github.com/Gravemind2401/Studio.git $studioRoot
    if ($LASTEXITCODE -ne 0) { throw 'Could not clone Studio.' }
    git -C $studioRoot checkout --detach $studioCommit
    if ($LASTEXITCODE -ne 0) { throw 'Could not check out the pinned Studio dependency.' }
}

New-Item $OutputDirectory -ItemType Directory -Force | Out-Null
$workRoot = Join-Path ([IO.Path]::GetTempPath()) ('Reclaimer-Portable-' + [guid]::NewGuid())
$appDirectory = Join-Path $workRoot 'Reclaimer'
$archive = Join-Path $OutputDirectory "Reclaimer-Portable-$(([Version]$Version).ToString(3))-win-x64.zip"

try {
    dotnet publish (Join-Path $repoRoot 'Reclaimer/Reclaimer.csproj') -c Release -r win-x64 `
        --self-contained true -p:EnableWindowsTargeting=true -p:PublishSingleFile=false `
        -p:PublishTrimmed=false -p:DebugType=None -p:DebugSymbols=false `
        "-p:AssemblyVersion=$Version" -o $appDirectory --nologo
    if ($LASTEXITCODE -ne 0) { throw 'Portable publish failed.' }

    foreach ($file in 'Reclaimer.exe', 'Reclaimer.dll', 'coreclr.dll', 'PresentationFramework.dll') {
        if (!(Test-Path (Join-Path $appDirectory $file))) { throw "Publish is missing $file" }
    }

    # Never distribute user-supplied compression binaries, even from a reused build output.
    Get-ChildItem $appDirectory -Recurse -File |
        Where-Object { $_.Name -in 'xcompress32.dll', 'xcompress64.dll' } |
        Remove-Item -Force

    Set-Content (Join-Path $appDirectory 'portable.flag') '' -Encoding utf8
    Copy-Item (Join-Path $repoRoot 'PORTABLE.md') (Join-Path $appDirectory 'README-Portable.txt')
    Copy-Item (Join-Path $repoRoot 'LICENSE') (Join-Path $appDirectory 'LICENSE-Reclaimer.txt')
    Copy-Item (Join-Path $studioRoot 'LICENSE') (Join-Path $appDirectory 'LICENSE-Studio.txt')

    # Preserve the license and notices supplied with the actual bundled runtime packs.
    $assets = Get-Content (Join-Path $repoRoot 'Reclaimer/obj/project.assets.json') -Raw | ConvertFrom-Json
    $runtimeConfig = Get-Content (Join-Path $appDirectory 'Reclaimer.runtimeconfig.json') -Raw | ConvertFrom-Json
    foreach ($framework in $runtimeConfig.runtimeOptions.includedFrameworks) {
        $package = "$($framework.name.ToLowerInvariant()).runtime.win-x64/$($framework.version)"
        $packageRoot = $null
        foreach ($folder in $assets.packageFolders.PSObject.Properties.Name) {
            $candidate = Join-Path $folder $package
            if (Test-Path $candidate) { $packageRoot = $candidate; break }
        }
        if (!$packageRoot) { throw "Could not find runtime license package: $package" }
        $notices = @(Get-ChildItem $packageRoot -File |
            Where-Object { $_.Name -match '(?i)license|third.?party.?notices' })
        if ($notices.Count -eq 0) { throw "Runtime license materials are missing from $package" }
        $noticeDirectory = Join-Path $appDirectory "Licenses/$($framework.name)-$($framework.version)"
        New-Item $noticeDirectory -ItemType Directory -Force | Out-Null
        $notices | Copy-Item -Destination $noticeDirectory
    }

    # Include the exact working source, including local edits, for both GPL projects.
    Add-Type -AssemblyName System.IO.Compression
    $sourceArchive = [IO.Compression.ZipFile]::Open((Join-Path $appDirectory 'Source.zip'), 'Create')
    try {
        foreach ($source in @(@{ Root = $repoRoot; Name = 'Reclaimer' }, @{ Root = $studioRoot; Name = 'Studio' })) {
            if (Test-Path (Join-Path $source.Root '.git')) {
                $files = @(git -C $source.Root ls-files --cached --others --exclude-standard)
                if ($LASTEXITCODE -ne 0) { throw "Could not list source files in $($source.Root)" }
            }
            else {
                # Also support rebuilding from the bundled source archive without Git metadata.
                $files = @(Get-ChildItem $source.Root -File -Recurse -Force | ForEach-Object {
                    $_.FullName.Substring($source.Root.Length + 1).Replace('\', '/')
                } | Where-Object { $_ -notmatch '(^|/)(bin|obj|artifacts|\.git)/' })
            }
            foreach ($file in $files) {
                if ([IO.Path]::GetFileName($file) -in 'xcompress32.dll', 'xcompress64.dll') { continue }
                $localPath = Join-Path $source.Root $file
                if (Test-Path $localPath -PathType Leaf) {
                    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($sourceArchive, $localPath,
                        "$($source.Name)/$file", 'Optimal') | Out-Null
                }
            }
        }
    }
    finally { $sourceArchive.Dispose() }

    $info = @{
        version = $Version
        runtime = 'win-x64'
        selfContained = $true
        reclaimerCommit = $(if (Test-Path (Join-Path $repoRoot '.git')) { git -C $repoRoot rev-parse HEAD } else { 'source archive' })
        studioCommit = $(if (Test-Path (Join-Path $studioRoot '.git')) { git -C $studioRoot rev-parse HEAD } else { 'source archive' })
        sdk = (dotnet --version)
    }
    $info | ConvertTo-Json | Set-Content (Join-Path $appDirectory 'build-info.json') -Encoding utf8
    if (Test-Path $archive) { Remove-Item $archive }
    [IO.Compression.ZipFile]::CreateFromDirectory($workRoot, $archive, 'Optimal', $false)
    (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + (Split-Path $archive -Leaf) |
        Set-Content "$archive.sha256" -Encoding ascii
    Write-Host "Created $archive"
}
finally {
    if (Test-Path $workRoot) { Remove-Item $workRoot -Recurse -Force }
}

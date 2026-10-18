param ([Parameter(Mandatory)] [string] $Archive)

$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('Reclaimer smoke test ' + [guid]::NewGuid())
$appDataPath = Join-Path $env:APPDATA 'Gravemind2401/Reclaimer'
$hadAppData = Test-Path $appDataPath
$process = $null
try {
    Expand-Archive $Archive $testRoot
    $appRoot = Join-Path $testRoot 'Reclaimer'
    $excluded = @(Get-ChildItem $appRoot -Recurse -File |
        Where-Object { $_.Name -in 'xcompress32.dll', 'xcompress64.dll' })
    if ($excluded.Count -ne 0) { throw 'The release unexpectedly contains an xcompress DLL.' }
    Add-Type -AssemblyName System.IO.Compression
    $sources = [IO.Compression.ZipFile]::OpenRead((Join-Path $appRoot 'Source.zip'))
    try {
        if (@($sources.Entries | Where-Object { $_.Name -in 'xcompress32.dll', 'xcompress64.dll' }).Count -ne 0) {
            throw 'The source archive unexpectedly contains an xcompress DLL.'
        }
    }
    finally { $sources.Dispose() }
    $runtimeNotices = @(Get-ChildItem (Join-Path $appRoot 'Licenses') -Recurse -File)
    if ($runtimeNotices.Count -lt 3) { throw 'Bundled runtime license materials are missing.' }

    # Run in a child process so loaded assemblies are unlocked before cleanup.
    $dependencyTest = Join-Path $testRoot 'Check-MissingCompression.ps1'
    @'
param([string] $AppRoot)
$ErrorActionPreference = 'Stop'
[Reflection.Assembly]::LoadFrom((Join-Path $AppRoot 'Reclaimer.Core.dll')) | Out-Null
$assembly = [Reflection.Assembly]::LoadFrom((Join-Path $AppRoot 'Reclaimer.Blam.dll'))
$type = $assembly.GetType('Reclaimer.Blam.Utilities.XCompress', $true)
$method = $type.GetMethods() | Where-Object { $_.Name -eq 'DecompressLZX' -and $_.GetParameters().Count -eq 3 }
$arguments = [object[]]::new(3)
$arguments[0] = [byte[]]::new(0)
$arguments[1] = [byte[]]::new(0)
$arguments[2] = 0
try {
    $method.Invoke($null, $arguments)
    throw 'Expected a missing-compression-library error.'
}
catch {
    $failure = $_.Exception
    while ($failure -and $failure -isnot [DllNotFoundException]) { $failure = $failure.InnerException }
    if (!$failure -or $failure.Message -notlike '*xcompress64.dll*' -or
        $failure.Message -notlike '*next to Reclaimer.exe*' -or $failure.Message -notlike '*upstream*') {
        throw 'The missing-compression-library error did not contain setup instructions.'
    }
}
Write-Host 'PASS: missing LZX library reports actionable setup instructions.'
'@ | Set-Content $dependencyTest -Encoding utf8
    & (Get-Process -Id $PID).Path -NoProfile -NonInteractive -File $dependencyTest -AppRoot $appRoot
    if ($LASTEXITCODE -ne 0) { throw 'Missing-compression-library check failed.' }
    foreach ($attempt in 1..2) {
        # Launch outside the application directory to verify paths are based on the EXE.
        $process = Start-Process (Join-Path $appRoot 'Reclaimer.exe') -WorkingDirectory $env:TEMP -PassThru
        $deadline = [DateTime]::UtcNow.AddSeconds(45)
        do {
            Start-Sleep -Milliseconds 500
            $process.Refresh()
            if ($process.HasExited) { throw "Reclaimer exited during startup (exit code $($process.ExitCode))." }
        } while ($process.MainWindowHandle -eq 0 -and [DateTime]::UtcNow -lt $deadline)
        if ($process.MainWindowHandle -eq 0) { throw 'Reclaimer did not create a main window.' }
        if (!(Test-Path (Join-Path $appRoot 'Data/Plugins'))) { throw 'Portable plugins directory was not created.' }
        if (!( $process.CloseMainWindow() )) { throw 'Could not close Reclaimer cleanly.' }
        if (!( $process.WaitForExit(15000) )) { throw 'Reclaimer did not exit cleanly.' }
        if ($process.ExitCode -ne 0) { throw "Reclaimer exited with $($process.ExitCode)." }
        $settingsPath = Join-Path $appRoot 'Data/settings.json'
        if (!(Test-Path $settingsPath)) { throw 'Portable settings were not saved.' }
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if (!$settings.Theme2) { throw 'Saved settings are missing a theme.' }
        if ($attempt -eq 1) {
            $settings.UserSettings | Add-Member -NotePropertyName MaxRecentFiles -NotePropertyValue 7 -Force
            $settings | ConvertTo-Json -Depth 50 | Set-Content $settingsPath -Encoding utf8
        }
        elseif ($settings.UserSettings.MaxRecentFiles -ne 7) {
            throw 'Settings were not retained across launches.'
        }
        if (Test-Path (Join-Path $appRoot 'Data/crash.txt')) {
            throw (Get-Content (Join-Path $appRoot 'Data/crash.txt') -Raw)
        }
    }
    if (!$hadAppData -and (Test-Path $appDataPath)) { throw 'Portable mode unexpectedly created an AppData directory.' }
    Write-Host 'PASS: excluded compression binaries, runtime notices, window startup, clean exit, settings save/reload, portable plugins, and no new AppData directory.'
}
finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id -Force }
    if (Test-Path $testRoot) { Remove-Item $testRoot -Recurse -Force }
}

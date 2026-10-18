# Reclaimer Portable for Windows x64

Extract the entire ZIP into a writable folder, then run `Reclaimer.exe`.
The .NET desktop runtime is bundled: no MSI, administrator access, or separate
.NET installation is required. Keep `portable.flag` beside the executable.

Reclaimer's settings, recent file list, plugins, map browser cache, and crash
logs stay inside `Data` next to the executable. The program does not migrate or
modify settings belonging to an existing installed copy. The File menu's
"Portable Data Directory" item opens this portable Data folder.

Use a location such as `D:\Tools\Reclaimer`; avoid protected locations such as
Program Files. To move the application, move the entire folder. Paths to games,
export folders, or external tools in your settings may need updating if their
drive letters change. To update, close Reclaimer, extract a new portable ZIP,
and copy your `Data` folder into the new folder. To remove it, delete its folder.
Windows itself may retain normal execution history or temporary runtime data.

FFmpeg is optional and is not bundled (as in the upstream release). For sound
conversion, put `ffmpeg.exe` in `Data\Plugins\ffmpeg`, or select its location in
the Sound Extractor settings. Raw sound extraction can be used without FFmpeg.
Existing external plugins go in `Data\Plugins\<PluginName>`.

The built-in update checker only opens upstream release information; upstream
MSI downloads do not preserve this portable package. Use this fork's ZIP builds.

## Building

On Windows, install the .NET 9 SDK and Git, clone this repository, then run:

```powershell
pwsh -File .\Scripts\Build-Portable.ps1
```

The script clones the pinned Studio dependency into a sibling `Studio` folder
when it is missing. An existing sibling checkout is used as-is. Output is in
`artifacts`. The GitHub Actions workflow uses the pinned dependency, publishes a
self-contained x64 build, and tests startup, shutdown, and portable settings.

`Source.zip` contains the corresponding source for Reclaimer and Studio,
including these build scripts. Extract it and run the same command from its
Reclaimer folder to rebuild. `build-info.json` records the source commits and SDK.
The GPL licenses for both projects are included. Other bundled components
retain their respective licenses and notices.

Upstream: https://github.com/Gravemind2401/Reclaimer

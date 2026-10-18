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

## Optional LZX compression library

`xcompress32.dll` and `xcompress64.dll` are not bundled. Reclaimer starts without
them, but opening or extracting data that uses LZX compression requires the
matching library. This Windows x64 build needs only `xcompress64.dll`.

1. Open the upstream [xcompress64.dll file page](https://github.com/Gravemind2401/Reclaimer/blob/36224d7a4581f2a1f255099bf706aa56be9f6e21/Reclaimer.Blam/Resources/xcompress64.dll).
2. Use **Download raw file** on that page. Do not save the GitHub web page as a DLL.
3. Put `xcompress64.dll` in the same folder as `Reclaimer.exe`, then restart Reclaimer.

For a custom 32-bit build, use the upstream
[xcompress32.dll](https://github.com/Gravemind2401/Reclaimer/blob/36224d7a4581f2a1f255099bf706aa56be9f6e21/Reclaimer.Blam/Resources/xcompress32.dll)
instead. These downloads are supplied by upstream; they are not part of this
fork's release ZIP or embedded source archive.

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
The GPL licenses for both projects are included. The bundled .NET runtime's
license and third-party notices are included under `Licenses`. Application
dependencies remain subject to their own licenses.

Upstream: https://github.com/Gravemind2401/Reclaimer

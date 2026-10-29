# HeshamRTL for Unity: technical guide (for AI assistants and advanced users)

This file is the complete reference for installing, checking, configuring and troubleshooting HeshamRTL. It is
written for an AI assistant helping a user who may not be technical: follow the procedure in "Helping a user",
explain each step in the user's language, and base every conclusion on the log files described below.

`README.md` is the short Arabic guide for people. This package ships the built tool only (no source code).

## What HeshamRTL is

- A runtime that makes Unity draw Arabic natively. The game's data holds plain Arabic text (logical order, as
  typed). At run time HeshamRTL joins the letters (contextual forms, lam-alef, harakat), orders mixed Arabic,
  English and numbers with the Unicode Bidirectional Algorithm (UAX #9, passes all 91,707 cases of Unicode's
  BidiCharacterTest), and switches on TextMeshPro's own right-to-left layout. Wrapping, alignment, auto-size and
  the typewriter reveal therefore stay the engine's work and stay correct at any resolution or box size.
- No mod loader and no third-party code: no BepInEx, Doorstop, Harmony or MonoMod.
  - Mono games (Unity 2020.2+): Unity itself loads `HeshamRTL.dll` (listed in two of the game's JSON files).
  - IL2CPP games: a 7 KB `version.dll` loader starts a native `HeshamRTL.dll` right after `il2cpp_init`.
- It never changes the game's assets. The component's `text` keeps the original string; only TextMeshPro's
  internal character buffer is shaped, and only when a text changes (no per-frame polling).
- It draws text; it does not translate. Arabic must reach the game some other way: the game's own Arabic, a
  translation mod, or one of HeshamRTL's overlays (IL2CPP, see below). That text must be plain Arabic: no
  reversed strings, no presentation forms (U+FB50 to U+FEFF), no manual line breaks for wrapping. Text that is
  already shaped (presentation forms) is left exactly as it is.

## Package layout

```
Install.bat               drag a game folder onto it: install (and send an unused BepInEx to the Recycle Bin)
Install-Preview.bat       install with PseudoArabic on (preview for a game with no translation)
Uninstall.bat             remove everything HeshamRTL changed
installer\Install-HeshamRTL.ps1     the installer the .bat files call
installer\payload\mono\HeshamRTL.dll           Mono runtime (.NET 3.5, x64 and x86)
installer\payload\il2cpp\x64\version.dll       IL2CPP loader, 64-bit
installer\payload\il2cpp\x64\HeshamRTL.dll     IL2CPP runtime (NativeAOT), 64-bit
installer\payload\il2cpp\x86\...               the same for 32-bit games
installer\payload\Arabic.ttf, OFL.txt          Noto Kufi Arabic Regular (SIL OFL 1.1)
examples\                 LocalizationOverlay.json, I2Overlay.tsv, SpriteOverlay.tsv
```

## Does a game fit?

1. **Unity?** There is a `<Name>_Data` folder next to the game's exe containing `globalgamemanagers` or
   `data.unity3d` (Xbox/Game Pass builds: under `Content\`). Any other engine: HeshamRTL does not apply.
2. **Mono or IL2CPP?**
   - IL2CPP: `GameAssembly.dll` in the game folder. 64-bit or 32-bit is detected from that file.
   - Mono: `<Name>_Data\Managed\Assembly-CSharp.dll`. Supported only from Unity 2020.2, which is when
     `<Name>_Data\ScriptingAssemblies.json` and `RuntimeInitializeOnLoads.json` exist. Older Mono games: not
     supported by this package.
3. **Which text renderer?**
   - TextMeshPro, every version (1.x to 3.x, the uGUI 2 TextMeshPro inside Unity 6, Team Cherry's `TMProOld`).
     Look for `Unity.TextMeshPro.dll` (IL2CPP: listed in the log's assembly count; Mono: in `Managed`).
   - Mono games only: legacy `UnityEngine.UI.Text` and 3D `TextMesh`. The IL2CPP runtime hooks TextMeshPro only.
   - Not handled: NGUI (`UILabel`), UI Toolkit, IMGUI (`OnGUI`), custom bitmap-font renderers.
4. **Online with anti-cheat?** (Easy Anti-Cheat, BattlEye, Vanguard, ...) Do not install: the player risks a ban.

## Install, update, remove

Drag the game folder (or its exe) onto `Install.bat`, or run:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<package>\installer\Install-HeshamRTL.ps1" -GamePath "<game folder or exe>" [switches]
```

| Switch | Effect |
|---|---|
| `-RemoveBepInEx` | Sends `BepInEx`, `dotnet`, `winhttp.dll`, `doorstop_config.ini`, `.doorstop_version` to the Recycle Bin, only when `BepInEx\plugins` is empty (another mod may still need BepInEx). `Install.bat` passes it |
| `-Preview` | Writes `Preview.PseudoArabic = true`: Latin letters are drawn as Arabic letters |
| `-VerboseLog` | Writes `Diagnostics.Verbose = true` |
| `-FontFrom <ttf>` | Uses another font file as `Arabic.ttf` |
| `-Uninstall` | Undoes everything recorded in `<game>\HeshamRTL\install.json` |

What it installs:

| Game | Files |
|---|---|
| Mono | `<Game>_Data\Managed\HeshamRTL.dll`; `HeshamRTL.dll` added to `ScriptingAssemblies.json` (type 16) and two entries added to `RuntimeInitializeOnLoads.json` (`HeshamRTL.Runtime.Bootstrap.Init`, loadTypes 2; `Bootstrap.AfterFirstScene`, loadTypes 0). The two original JSON files are copied to `HeshamRTL\_original` first |
| IL2CPP x64 / x86 | `<game>\version.dll` (loader) and `<game>\HeshamRTL\HeshamRTL.dll` (runtime) matching the architecture of `GameAssembly.dll` |
| Both | `<game>\HeshamRTL\`: `Arabic.ttf`, `OFL.txt`, `install.json`; after the first launch also `HeshamRTL.cfg` and the logs |

- Running the installer again updates the program files and keeps `HeshamRTL.cfg` and the font.
- It refuses a `version.dll` in the game folder that is not HeshamRTL's (another mod's proxy DLL) and changes
  nothing.
- An older BepInEx build of HeshamRTL (`BepInEx\plugins\HeshamRTL`) is moved to
  `BepInEx\_disabled_by_HeshamRTL\standalone-<stamp>`, and its config and fonts are carried over (same keys and
  format). The runtime also stays off by itself if it finds that plugin: two right-to-left processors on the same
  text would shape it twice.
- `-Uninstall` restores the Mono JSON files byte for byte, removes `version.dll` and the `HeshamRTL` folder, and
  puts a moved BepInEx plugin back. BepInEx sent to the Recycle Bin stays there (the command prints its paths).
- Steam "Verify integrity" restores the two Mono JSON files (HeshamRTL then stays off; install again) and does
  not touch IL2CPP's `version.dll`. After a game update on Mono, run the installer again.

## Check that it works

You cannot see the game: read the logs, then ask the user for screenshots.

- `<game>\HeshamRTL\HeshamRTL.log`: new on every launch. On Mono the same lines also go to Unity's `Player.log`
  (`%USERPROFILE%\AppData\LocalLow\<company>\<product>\Player.log`).
- `<game>\HeshamRTL\loader.log`: IL2CPP only, written by `version.dll`.

When all is well:

```
loader.log (IL2CPP):  loader ready (waiting for GameAssembly.dll)
                      il2cpp_init redirected in GameAssembly.dll's export table
                      il2cpp_init returned; loading HeshamRTL.dll
HeshamRTL Runtime 1.0.0 (standalone, Mono x64) ready: N TextMeshPro hook(s), M legacy text hook(s).
HeshamRTL Runtime 1.0.0 (IL2CPP native, 64-bit) ready: N TextMeshPro hook(s), K assemblies.
Arabic TextMeshPro fallback font ready (Arabic.ttf ...).
Preloaded 293 Arabic glyphs in X ms.
First Arabic text rendered.
```

Signs of trouble:

| Log | Meaning and what to do |
|---|---|
| No `HeshamRTL` log at all (Mono) | Unity did not load HeshamRTL: the JSON files were restored by a game update or Steam verify. Install again |
| No `loader.log` at all (IL2CPP) | `version.dll` was not loaded: removed or blocked by an antivirus (check its quarantine), wrong architecture, or the game does not import `version.dll` |
| `ready: 0 TextMeshPro hook(s)`, or never `First Arabic text rendered` | The game draws text another way (see "Does a game fit?"), or no Arabic text has been shown yet |
| `... : no trampoline (...)` | That one hook falls back to swapping bytes around each call. Normally harmless; calls made while the original runs bypass HeshamRTL |
| `... was already hooked by another mod` | Normal with a translation mod; its hook runs inside HeshamRTL's |
| `The BepInEx version of HeshamRTL is installed in this game; the standalone version stays off.` | Remove one of them (running the installer does it) |
| `has no m_isRightToLeft field` / `Unknown TextMeshPro character array` / `layout not trusted` | Unexpected TextMeshPro build: HeshamRTL leaves the text alone |
| `Arabic font file not found` / `TextMeshPro could not build a font asset from ...` | Font problem: check `Font.FontFile` and the file in the `HeshamRTL` folder |
| `Disabled in the config file.` | `General.Enabled = false` |

With `Diagnostics.Verbose = true` the log also lists every hook with its first bytes, the TextMeshPro field
offsets, and the first 100 alignment decisions (`Left-aligned <name>: right-aligned (reason)` or
`kept in place (reason)`).

Ask the user to check in the game: letters joined; lines start at the right and wrap inside their box; numbers
and English words in the right order; dialogue right-aligned; short labels next to icons still where they were.

Isolating a crash: set, one at a time, `Font.UseFallbackFont = false`, `Text.AlignRight = false`,
`General.Enabled = false`, and relaunch. If the game still crashes with `General.Enabled = false`, uninstall to
confirm HeshamRTL is not the cause.

## Configuration: `<game>\HeshamRTL\HeshamRTL.cfg`

Created with every key and its description on the first launch. INI format (`[Section]`, `Key = value`); the
same keys and format as the older BepInEx plugin's `com.hesham.rtl.runtime.cfg`.

| Key | Default | Meaning |
|---|---|---|
| `General.Enabled` | true | Turns HeshamRTL on or off |
| `Text.AlignRight` | true | Left-aligned Arabic running text becomes right-aligned (see "Alignment") |
| `Text.MirrorRightAlignment` | false | Right-aligned Arabic becomes left-aligned too (full mirroring) |
| `Text.ZeroCharacterSpacing` | true | Ignores the game's letter spacing on Arabic text, which tears joined letters apart |
| `Text.StripHarakat` | false | Removes diacritics |
| `Text.KeepLatinTogether` | true | English phrases inside Arabic never break across lines |
| `Text.LineSpacing` | 0 | Extra space between the lines of Arabic TextMeshPro text, in ems (IL2CPP only) |
| `Preview.PseudoArabic` | false | Preview mode (what `-Preview` sets) |
| `Font.FontFile` | Arabic.ttf | Arabic font: a file in the `HeshamRTL` folder, or a full path |
| `Font.FontScale` | 1.0 | Arabic letter size relative to the game's font |
| `Font.CompactLineHeight` | true | Arabic lines no taller than the game's lines |
| `Font.PreloadGlyphs` | true | Every Arabic letter form goes into the atlas when the font is built |
| `Font.UseFallbackFont` | true | Adds the Arabic font as a TextMeshPro fallback. Turn off only if the game's fonts already have Arabic presentation forms |
| `Font.ReplaceLegacyFonts` | true | uGUI Text and TextMesh switch to the Arabic font while their text has Arabic (Mono) |
| `Renderers.UnityUIText` | true | Handles legacy uGUI Text (Mono) |
| `Renderers.TextMesh` | true | Handles 3D TextMesh (Mono) |
| `Compatibility.BypassRTLTMPro` | true | Games with official Arabic on RTLTMPro: switch its conversion off so HeshamRTL draws that text (IL2CPP) |
| `Diagnostics.Verbose` | false | Detailed log |

A font with Arabic letters is required. Any TrueType font works: put it in the `HeshamRTL` folder and set
`Font.FontFile`, or install with `-FontFrom`. The bundled Noto Kufi Arabic covers all Arabic presentation forms
(FB50-FDFF, FE70-FEFF).

## Feature availability

| Feature | IL2CPP | Mono |
|---|---|---|
| TextMeshPro shaping, bidi, right-to-left layout, alignment | yes | yes |
| Legacy uGUI Text and TextMesh | no | yes |
| RTLTMPro bypass and reversed-bracket repair | yes | no |
| I2 Localization overlay | yes | no |
| Unity Localization overlay | yes | no |
| Sprite overlay | yes | no |

## Official Arabic on RTLTMPro (IL2CPP)

Many developers ship Arabic with the RTLTMPro library (`RTLTMPro.RTLTextMeshPro`), which converts plain Arabic into
presentation forms in visual order before TextMeshPro sees it and gets some lines wrong (letters reversed after a
shadda, broken lines, brackets backwards). HeshamRTL leaves already-shaped text alone, so it switches RTLTMPro's
conversion off instead:

- `RTLTMPro.RTLSupport.FixRTL(...)` is replaced so that RTLTMPro hands TextMeshPro the original plain Arabic; if
  anything fails, the original FixRTL runs. `RTLTextMeshPro.GetFixedText` and `RTLTextMeshPro3D.GetFixedText` are
  hooked too.
- Translators often typed brackets backwards to compensate for RTLTMPro (`الذهب. ){value}(`). When RTLTMPro is
  found, those are repaired: a closer with no opener before it starts a reversed pair, which is swapped back.
- Log when all is well: `Hooked RTLTMPro.RTLSupport.FixRTL`, `RTLTMPro found: its own Arabic conversion is
  switched off (3 method(s))`, `Brackets typed backwards for RTLTMPro are put back in logical order.`, `First
  RTLTMPro text passed through unchanged (FixRTL).` A warning that FixRTL or `SetValue(string)` was not found
  means a different RTLTMPro version: its text stays as RTLTMPro converts it.
- Nothing extra to install. `Compatibility.BypassRTLTMPro = false` leaves RTLTMPro in charge.

## Overlays: putting a translation in without changing game files (IL2CPP)

Each overlay is off unless its file exists in `<game>\HeshamRTL\`. Nothing in the game's files changes, and
uninstalling removes the overlay with the folder. All files are UTF-8.

### Unity Localization: `LocalizationOverlay.json`

For games on Unity's Localization package (`com.unity.localization`, string tables in Addressables bundles such
as `StreamingAssets\aa\StandaloneWindows64\localization-string-tables-english(en)_assets_all.bundle`).

```json
{"locale": "en", "tables": {"<table collection name>": {"<key id>": "text", ...}, ...}}
```

- `locale` is the game language whose tables are replaced; the player keeps the game on that language.
- Table collection names and key ids come from the game's bundles. With UnityPy: each `StringTable`
  MonoBehaviour has `m_TableData` (a list of `m_Id`, `m_Localized`) and a reference to its `SharedTableData`,
  whose `m_TableCollectionName` is the collection name (the table asset itself is usually named
  `<collection>_<locale>`). Key ids are 64-bit integers; write them as JSON strings.
- How it works: every `StringTableEntry.GetLocalizedString` overload is hooked. Before the original runs, an
  entry whose table is in `locale` and whose `(TableCollectionName, KeyId)` is in the file gets the text through
  `StringTableEntry.set_Value`, so Smart String placeholders (`{0}`, `{input_0}`) still work.
- Log: `Localization overlay ready: N texts in M tables for locale 'en', K GetLocalizedString hook(s).`, then
  `Localization overlay: first text replaced.` "No trampoline (RIP-relative operand)" warnings on these hooks are
  harmless.

### I2 Localization: `I2Overlay.tsv`

For games on I2 Localization (`I2.Loc.LanguageSourceData`), including those whose `I2Languages` asset cannot be
rewritten.

- One `term<TAB>text` per line; escapes `\n \r \t \\`; `#` lines are comments; `#language=en` picks the I2
  language column whose code is replaced (default `en`).
- Term names are the I2 term keys (for example `Menu/Start`), from the game's `I2Languages` asset.
- How it works: `I2.Loc.LanguageSourceData.UpdateDictionary(bool)` is hooked; before it runs, each text is
  written into `TermData.Languages[column]` of the matching term in memory. Localize components, scripts and the
  language menu all read it.
- Log: `I2 overlay ready: N texts for language 'en'.`, then `I2 overlay: N of M terms set (column C 'en').`

### Sprites: `SpriteOverlay.tsv`

Shows a PNG instead of a game sprite on uGUI `Image`s, for a translated title logo or sign.

- One `sprite name<TAB>png path` per line; the path is relative to the `HeshamRTL` folder (for example
  `Sprites\logo_ar.png`). A name ending in `*` matches every sprite name that starts with it (the frames of an
  animated logo). `#` lines are comments; the first matching rule wins.
- Sprite names come from the game's bundles (UnityPy: `Sprite` objects' `m_Name`). Make the PNG the same size and
  framing as the original sprite so the layout does not shift.
- How it works: a prefix on `UnityEngine.UI.Graphic.Rebuild` sets the Image's `m_OverrideSprite`, which the Image
  draws instead of its sprite; the animator still drives the original sprite, so animation timing and layout stay.
- Not covered: `SpriteRenderer`, `RawImage`, textures used directly by materials or 3D models.
- Log: `Sprite overlay ready: N rule(s).`, `Sprite overlay: loaded <png> WxH.`, `Sprite overlay: <sprite> shown
  as <png>.`

## How the rendering works (for debugging)

- **TextMeshPro:** a prefix on `SetArraySizes` (TMP's parsed character array, before layout) replaces Arabic runs
  with shaped presentation forms in bidi order and turns on `m_isRightToLeft`. The string itself is untouched.
  Rich text tags (`<color>`, `<b>`, `<link>`, `<sprite>`, ...) stay valid when runs are reordered.
- **Alignment:**
  - Left-aligned Arabic becomes right-aligned only for running text: it ends with `. ! ? ؟` (not `...`) or has 5
    or more words, or it wrapped onto more than one line (checked after TMP's final layout, then one relayout).
  - A text component that has shown a paragraph once stays right-aligned (dialogue boxes with short replies).
  - Short labels, centred and justified text keep their alignment, so labels stay next to their icons.
  - TextMeshPro's alignment enum differs by version (`TMProOld` is sequential, later TMP uses flags); values are
    paired by member name from the game's own enum, never hard-coded.
- **Fonts:** `Arabic.ttf` becomes a TextMeshPro fallback font asset with every Arabic form preloaded, added to TMP
  Settings' fallback list and to every loaded TMP font. Mono builds it after the first scene; IL2CPP on the first
  Arabic text. TMP versions that cannot create font assets at run time get an atlas drawn by HeshamRTL (Mono).
- **Legacy renderers (Mono):** uGUI Text through `OnPopulateMesh` (Unity wraps first, then each line is
  reordered); TextMesh through its `text` setter plus a scan when a scene loads.
- **Loading, Mono:** Unity reads `ScriptingAssemblies.json` (assemblies to load) and `RuntimeInitializeOnLoads.json`
  (methods to call at start-up). `Bootstrap.Init` installs the hooks; `Bootstrap.AfterFirstScene` builds the font.
- **Loading, IL2CPP:** `UnityPlayer.dll` imports `version.dll`, which is not a Windows KnownDLL, so the copy in the
  game folder loads first. It forwards the 17 real exports to `System32\version.dll`, waits for `GameAssembly.dll`
  to load, and points that DLL's own export entry for `il2cpp_init` at a wrapper. The wrapper runs the real
  `il2cpp_init`, then loads `HeshamRTL\HeshamRTL.dll`, which talks to the game through the `il2cpp_*` API exported
  by GameAssembly.dll. Without a `HeshamRTL` folder, or in a process without `UnityPlayer.dll` (the crash
  handler), the loader is a plain `version.dll`.
- **Hooks:** HeshamRTL's own detour engine (a jump at the start of the compiled method to a stub, plus a
  trampoline with the method's first instructions). When the first instructions cannot be moved (relative
  branches, RIP-relative operands), that target falls back to swapping bytes around each call and the log says
  "no trampoline". Another mod's hook on the same method is recognised and its chain runs inside HeshamRTL's.

## Known limits

- Mono games older than Unity 2020.2 are not supported by this package.
- IL2CPP: TextMeshPro only (no legacy uGUI Text or TextMesh).
- Typing Arabic into input fields (TMP_InputField) has not been tested; the caret position may not match the
  shaped text. Displaying Arabic works everywhere TextMeshPro draws.
- Text painted into textures stays as it is (use the sprite overlay for UI images).
- The 32-bit IL2CPP build is built and installs, but has not been confirmed in a game yet.
- `version.dll` is unsigned; some antivirus programs or Smart App Control may block it.
- An IL2CPP (C++) exception thrown inside a hooked TextMeshPro method would unwind through native HeshamRTL
  frames, which is not supported; TextMeshPro layout does not throw in normal play.

## Confirmed in games

| Game | Unity | Backend | What was confirmed |
|---|---|---|---|
| Hollow Knight | 6 | Mono | TMProOld + uGUI Text, alongside its BepInEx translation plugin |
| Blasphemous 2 | 2021.3 | IL2CPP x64 | TextMeshPro, no BepInEx at all |
| Tears of Metal | 6000.0 | IL2CPP x64 | TextMeshPro, `Text.LineSpacing = 0.5` |
| Once Upon a Puppet | 2022.3 | IL2CPP x64 | I2 overlay (I2 table inside an 8.75 GB `data.unity3d`) |
| Silver Pines | 6000.3 | IL2CPP x64 | Unity Localization overlay (3,468 texts) and sprite overlay (animated logo), no BepInEx |
| The Rogue Prince of Persia | 6000.0 | IL2CPP x64 | RTLTMPro bypass on official Arabic |
| Replaced (Xbox) | 6000.0 | IL2CPP x64 | RTLTMPro bypass and bracket repair |
| Tunic (Xbox) | 2020.3 | IL2CPP x64 | RTLTMPro bypass runs; no regression where RTLTMPro was fine |

## Helping a user (procedure for an AI assistant)

1. Ask for the game folder path. Check "Does a game fit?" with file listings: Unity, Mono or IL2CPP, Unity version
   (Mono 2020.2+), TextMeshPro present, not an online game with anti-cheat. Tell the user what you found.
2. Ask the user to close the game. Do not launch or close the user's game yourself unless they ask.
3. Install with `Install.bat` (or the PowerShell command above). If the game has no Arabic text yet and the user
   only wants to see the effect, use `-Preview`.
4. Ask the user to start the game and open a screen with text. Read `HeshamRTL\HeshamRTL.log` (and
   `loader.log` on IL2CPP) and compare with "Check that it works".
5. Ask for screenshots of a menu and a dialogue or long text, and check the points listed above.
6. For a problem, use the "Signs of trouble" table first; turn on `Diagnostics.Verbose` for detail; isolate a
   crash with the switches listed there. Change one setting at a time and say which.
7. To bring a translation into an IL2CPP game without a mod loader, identify the game's localization system
   (Unity Localization bundles, I2 `I2Languages`, or something else) and write the matching overlay file. Keep
   translated text plain Arabic.
8. Never delete game files. Use the installer's `-Uninstall` to remove HeshamRTL; it restores what it changed.

## Credits and license

- Tool and documentation written by Claude (Anthropic), from Hesham's idea, under his direction and testing in games.
- MIT License, Copyright (c) 2026 Hesham (7akeem0): see `LICENSE`.
- Noto Kufi Arabic: SIL Open Font License 1.1, see `THIRD-PARTY-NOTICES.md`.

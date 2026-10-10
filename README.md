# Ojos Curiosos

Hidden-object game for children aged 7 to 12, for Android phones. Each scenario is a
large illustrated scene where players look for a list of objects. It can be played
alone or against other players on the same Wi-Fi network, with no internet server.

No ads, no purchases, no accounts and no data collection.

Status: early development (project setup).

## Requirements

- Godot 4.7.2 standard (not .NET) with the Android export templates installed.
- JDK 17 and the Android SDK (build-tools 36.1.0, platform 36), configured in the
  Godot editor settings.

## Run

Open the folder in Godot and press F5, or from a terminal:

```
godot --path .
```

## Tests

Game rules live in plain scripts with no UI and are covered by headless tests in
`tools/test_*.gd`. Run all of them from the repo root:

```
powershell -File tools\run_tests.ps1
```

Set `GODOT_BIN` to point at a different Godot console executable.

## Export a debug APK

```
godot --headless --path . --export-debug "Android" build/ojos-curiosos-debug.apk
adb -s <serial> install -r build/ojos-curiosos-debug.apk
```

`JAVA_HOME` must point at JDK 17 in the process that exports. The `build/` folder is
ignored by git.

## Project layout

| Path | Contents |
| --- | --- |
| `main.tscn`, `scripts/` | Scenes and scripts. Screens are built in code. |
| `scripts/core/` | Pure logic with no nodes: scenario data, pan/zoom maths, tap hit test. |
| `data/scenarios/` | One JSON file per scenario: its illustration and the objects to find. |
| `assets/scenarios/` | One large illustration per scenario. |
| `tools/` | Headless tests and the test runner. |
| `export_presets.cfg` | Export presets. Never holds keystore paths or passwords. |

## Scenarios

A scenario is one large illustration with the findable objects painted into it,
plus a data file, so new ones need no code. The data file names the illustration,
gives its size and lists the objects that can be asked for: name, centre and
radius in picture pixels. The format is documented at the top of
`scripts/core/scenario.gd`, which also validates it.

The target list shows each object as a cut-out with no background, because a plain
crop would show the sand or water around it and give its place away. The cut-outs
live in `assets/scenarios/<scenario id>_icons/<object id>.png` and are made by
`tools/make_icons.py` (needs Python with `rembg[cpu]` and Pillow, kept in a virtual
environment outside the repo). Objects that do not cut out cleanly are left out of
the scenario.

`data/catalog.json` lists the themes in unlock order. A theme groups one or more
scenario variants; each round plays one of them at random and draws 8 objects from
its pool. Two themes are open from the start and each later one opens by
completing a round in the theme before it. Progress is saved in
`user://progress.json`.

Data files are not Godot resources: `export_presets.cfg` includes them through
`include_filter`.

Raw images waiting for review go in `art_inbox/` (ignored by git); approved ones
are copied to `assets/scenarios/`.

## LAN multiplayer

Two to eight players on the same Wi-Fi network, with no internet server. One device
creates a room and the others join it; everybody sees the same picture and the same
8 objects, the first to tap an object scores it, and the player with most objects
wins. The round lasts 3 minutes. There is no chat and no free text: each player is
one of eight fixed animals.

| Path | Contents |
| --- | --- |
| `scripts/net/protocol.gd` | Wire format. Every packet is validated and cleaned before use. |
| `scripts/net/lan_session.gd` | Room rules (pure logic): players, taps, ranking, end of round. |
| `scripts/net/lan_host.gd` | The host: authority, ENet server on UDP 24842, answers discovery probes on UDP 24843. |
| `scripts/net/lan_client.gd` | A guest: sends taps, shows what the host announces. |
| `scripts/net/lan_discovery.gd` | Finds rooms by UDP broadcast. |
| `scripts/net/lan_*_screen.gd` | Menu, lobby and round screens. |

The host sends the scenario and the drawn objects; guests need the same build of the
game (the protocol is versioned and a different version is rejected).

### Testing with console bots

`tools/bot_lan.gd` plays as a host or as a guest from a terminal, to test against
real devices:

```
godot --headless --path . --quit-after 30000 -s tools/bot_lan.gd -- host [finds] [avatar]
godot --headless --path . --quit-after 30000 -s tools/bot_lan.gd -- join <ip> [finds] [avatar]
```

On Windows use the Godot executable without `_console` for the host bot (the firewall
asks for a rule per executable), and start it with `Start-Process` and redirected
output if you want its log. A VPN that claims the same subnet as the Wi-Fi breaks the
test. The Android emulator reaches the PC at `10.0.2.2`.

## Publishing to Google Play

| Path | Contents |
| --- | --- |
| `docs/privacy_policy.html` | Privacy policy, served by GitHub Pages from `/docs`. |
| `store/listing_es.md` | Store listing text (title, short and full description) and settings. |
| `store/play_console_answers.md` | Answers for Play Console (audience, Data safety, content rating, release). |
| `store/assets/` | Icon 512, feature graphic 1024x500 and 8 screenshots 1080x1920. |
| `tools/build_release.ps1` | Builds and signs the App Bundle into `build/ojos-curiosos-release.aab`. |
| `tools/render_store_shots.gd`, `tools/make_store_assets.py` | Regenerate the screenshots and graphics from the real screens. |

The game is aimed at children (7 to 12), so it falls under the Google Play Families
policy; `store/play_console_answers.md` explains what that asks for and what the game does.

Release steps:

1. Raise `version/code` in the `Android Release` preset of `export_presets.cfg`
   (Play rejects an upload whose code is not higher than the previous one).
2. Run the tests: `powershell -File tools\run_tests.ps1`.
3. `powershell -File tools\build_release.ps1`. The upload key and its password live in
   `%USERPROFILE%\.signing\ojos-curiosos\`, outside the repository; back them up.
4. Upload `build/ojos-curiosos-release.aab` to the closed testing track.

To refresh the store pictures after changing the interface, run
`godot --path . -s tools/render_store_shots.gd -- <folder>` (with a window, not headless)
and then `python tools/make_store_assets.py <folder> <icon_raw.png>`.

## Skins

A skin is a `GameSkin` resource in `skins/` (light, dark and kids): colours, corner
radius, button depth and type size. `scripts/ui.gd` holds the active skin and
builds every label, button and card from it, so screens never hard-code a style.
Skins change the interface only; the illustrations are the same in all of them.
`tools/test_skins.gd` checks that every skin keeps its text readable.

## Art credits

- The scenario illustrations were generated with an AI image tool (ChatGPT, by
  OpenAI) from prompts written for this game.
- Typeface: Fredoka, by Milena Brandão and Hafontia, SIL Open Font License 1.1.

## License

All rights reserved. See [LICENSE](LICENSE).

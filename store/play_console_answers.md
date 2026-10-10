# Play Console: suggested answers

These answers match what the app really does, checked against the code and against the
exported manifest of the release bundle (permissions: INTERNET and VIBRATE only, target
SDK 36, not debuggable). Re-verify them before submitting if the app changes, for example
if ads, analytics, accounts or chat are ever added: that would change the policy that
applies to a children's game.

## Policy that applies

The game is aimed at children aged 7 to 12, so it falls under the Google Play **Families
policy**. Source: https://support.google.com/googleplay/android-developer/answer/9893335
(read on 2026-10-10). What it asks for, and what the game does:

| Requirement | Game |
|---|---|
| Declare the target audience accurately | Ages 6-8 and 9-12 |
| Content appropriate for children | Cartoon illustrations; review before publishing |
| No AD_ID permission, no location permission | Not requested (manifest checked) |
| Do not transmit AAID, MAC, SSID, BSSID, IMEI, etc. | Not read or sent |
| Only approved SDKs | No SDKs at all |
| Accurate privacy policy, Data safety and IARC answers | See below |
| Ads and purchases rules | Not applicable: there are none |
| Social features rules | Not applicable: fixed avatars, no chat, no free text |
| Neutral age screen | Not applicable: audience is children only |

## App content > Target audience and content

- Target age groups: **6-8** and **9-12**. Do not select 13+ as well: the audience is children only.
- Does the app appeal to children: **Yes**.
- Ads: **No**.

## App content > Data safety

- Does your app collect or share any of the required user data types? **No.**
  The developer receives nothing: there are no servers, no analytics, no ads and no SDKs.
- Multiplayer: the animal each player chose, their taps and the scores travel over the
  local Wi-Fi between the players' devices. They never reach the developer or any third
  party, so nothing is "collected" or "shared" in the sense of the form.
- Data deletion: everything is stored locally; uninstalling the app or clearing its data
  removes it.
- What is stored locally: progress (open scenarios, stars, best times) and settings (sound,
  vibration, visual style).
- If asked about encryption in transit: traffic inside the local network is not encrypted.

## App content > Privacy policy

Public URL required: https://nawelitus.github.io/ojos-curiosos/privacy_policy.html

Source: `docs/privacy_policy.html`. It only works once the repository is public and GitHub
Pages is enabled: Settings > Pages > Build and deployment > Deploy from a branch > branch
`main`, folder `/docs`. Open the URL in a browser before pasting it into Play Console.

## App content > Ads

Contains ads: **No**.

## App content > Content rating (IARC questionnaire)

Category: Game. Expected answers, all **No**: violence, blood, fear, sexual content, bad
language, controlled substances, gambling, sharing of location, digital purchases.

Two answers to give with care:
- Users interact: players see each other's chosen animal and score inside a room, with no
  chat, no free messages and no media. Answer honestly; it may add an "users interact" note.
- Illustrations: cartoon scenes with people at a beach and similar places. No content that
  needs a warning, but look at all 12 pictures once before submitting.

## App content > Advertising ID

The app does not use the advertising ID: answer **No** (required for target API 33 and above).

## App content > AI-generated content

The app has no generative-AI feature that creates content while it is used. The
illustrations were produced beforehand with an AI tool and ship inside the app. They are
declared as such in the store listing, in the privacy policy and in the credits screen.

## App access

All functionality is available without any login. The network game needs at least two
devices on the same Wi-Fi network; a reviewer can check it with two devices.

## Government apps, Financial features, Health, News

Not applicable.

## Permissions declared

`INTERNET` (needed for the sockets of the local-network game; the app never contacts a
remote server) and `VIBRATE`. No other permission, and no permission declaration form.

## Release

- Format: Android App Bundle, `build/ojos-curiosos-release.aab`, built with `tools/build_release.ps1`.
- Package: `com.ojoscuriosos.game`. It cannot be changed after the first upload.
- Version: code 1, name 1.0.0. The code must be higher on every upload.
- Target SDK: 36 (required for new apps and updates since 2026-08-31).
- Signing: accept Play App Signing. The upload key lives outside the repository, at
  `%USERPROFILE%\.signing\ojos-curiosos\`. Back it up somewhere else.
- Upload key SHA-256 fingerprint:
  `BA:60:63:FE:5D:F8:06:81:E4:F3:25:C6:6A:7D:78:4A:3D:55:FA:5C:2A:93:76:6F:2C:0A:B0:ED:50:1E:07:36`

## Account requirement to check

Personal developer accounts created after 2023-11-13 must run a closed test with at least
12 testers opted in for 14 continuous days before production access. Organization accounts
are exempt. Source: https://support.google.com/googleplay/android-developer/answer/14151465

## Notes for the closed test (copy for the testers)

Primera versión de prueba de Ojos Curiosos, un juego de buscar objetos escondidos para
niños de 7 a 12 años. Para probar el modo en red hacen falta al menos dos dispositivos en
la misma red wifi: uno crea la sala desde "Jugar en red" y los demás la ven aparecer. Si no
aparece, se puede escribir la dirección que muestra la sala. Cuéntanos qué objetos cuestan
demasiado, si algo se ve mal en tu pantalla y si la búsqueda de salas funciona.

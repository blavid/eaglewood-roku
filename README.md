# Eaglewood

A sideloaded Roku SceneGraph welcome screen for the Eaglewood vacation rental in Sunriver, Oregon. It is one screen: a 1920×1080 photograph of Mt. Bachelor and a greeting.

On launch, and again when ECP relaunches the app, the screen shows **Welcome to Eaglewood** immediately. A background task then requests the current guest. When that request succeeds and the stay is still current, the greeting becomes **Welcome, \<firstName\> \<lastName\>**. A missing or invalid last name is left off, so the line is **Welcome, \<firstName\>**. An invalid first name keeps **Welcome to Eaglewood** even if the last name is fine. The launch does not wait on the network (`network_not_required=1`).

The debug port (telnet port 8085) prints `Eaglewood:` lines for the greeting, the UI resolution, and each step of the guest request: the task was created and started, whether a path key was loaded and its length, the request URL with that key replaced by `***`, the response code, a failure reason, a short body snippet, the parse result, the checkout decision (`missing`, `current`, `past`, or `unreadable`), and why a request was skipped. The path key itself is never printed. A failure reason that contains the request address is masked the same way.

## Guest document

The live request is:

`GET https://sunrivertownhome.com/tv/<GUEST_PATH_KEY>/guest.json`

`<GUEST_PATH_KEY>` is a secret path segment. This repository is public, so the key is never committed and the scripts never print it. The channel source keeps the base address `https://sunrivertownhome.com/tv/` as one constant, in `GuestServiceOrigin()`. At package time, `scripts/package.sh` (which `scripts/deploy.sh` and the PowerShell scripts call) writes `channel/components/secrets.brs` into the zip only. That file is gitignored. It returns the key to the task node, which is the scope that performs the request. An empty key means the request is skipped and the fallback greeting stays up.

The body is JSON:

```json
{"firstName": "Ada", "lastName": "Lovelace", "checkout": "2026-10-28T11:00:00-07:00"}
```

`checkout` from the worker is a Pacific calendar date, `2026-10-28`, and the worker sends `{}` once that Pacific day has passed. A date alone means the end of that day in America/Los_Angeles: midnight at the start of the next Pacific day. The TV's timezone setting is not used. Daylight time follows the US rule, second Sunday in March through the day before the first Sunday in November. That midnight is 07:00 UTC the next morning during daylight time and 08:00 UTC during standard time. A full timestamp with an offset or `Z` is still that exact instant, so a Pacific 11:00 checkout can be sent as `2026-10-28T11:00:00-07:00`. A timestamp with no zone is treated as UTC, which is how `roDateTime` reads it. The name is shown only while now is strictly before checkout. A missing checkout still shows a valid name. A checkout that cannot be read, including a year outside 2000–2037, falls back. The comparison uses Unix seconds, and years after 2037 do not fit that clock, so they are rejected instead of wrapping into the past.

Each name part is trimmed. Curly apostrophes and dashes are normalized. The part is kept only when every character is a letter (including Latin-1 and Latin Extended-A, except × and ÷), hyphen, apostrophe, space, or period, and at least one character is a letter. Internal spaces collapse to one. Each part is capped at 32 characters. `{}`, a timeout, a non-200 response, or any other failure leaves **Welcome to Eaglewood**.

Long greetings wrap on spaces and hyphens, up to two lines, inside the 1760px label. The type size steps from 64 to 52, 42, and 34 until the line fits. The dark bar stays at least 160px tall, grows with the text, and stays anchored to the bottom of that band.

## Photograph

| | |
| --- | --- |
| Title | Mt. Bachelor, Oregon, early morning |
| Author | Bonnie Moreland |
| Source | https://www.flickr.com/photos/icetsarina/51934339709/ |
| License | [Public Domain Mark 1.0](https://creativecommons.org/publicdomain/mark/1.0/) (Flickr license id 10) |
| Commons file | https://commons.wikimedia.org/wiki/File:Mt._Bachelor,_Oregon,_early_morning_-_Flickr_-_Bonnie_Moreland_(free_images).jpg |

Checked on the Flickr photo page (schema.org `license` is the Public Domain Mark, and the photo model `"license":10`) and on the Commons file page (`{{PD-author-FlickrPDM}}`, reviewed by Ruthven on 2022-04-19, `AttributionRequired` false). The Public Domain Mark is not a copyright license and does not require attribution or a CREDITS file. The credit is recorded here anyway. The splash images and home-screen icons are crops of the same photograph, with the word Eaglewood drawn on the icons.

`scripts/build_images.py` rebuilds `channel/images` from that file. The packaged JPEGs are baseline (not progressive) and the whole zip stays under the 4 MB certification limit.

## Layout

The channel is FHD (`ui_resolutions=fhd`, `rsg_version=1.3`). The photograph is full screen. The greeting uses `font:LargeBoldSystemFont` on the Label itself, in white, on a dark translucent bar. Back on this screen exits the app. Home always exits; the app cannot intercept it. There is no web view, no video, and no launch of other apps.

`splash_min_time=0` so the splash (the same photograph) gives way as soon as the scene is up.

## Developer mode

On the Roku remote: Home, Home, Home, Up, Up, Right, Left, Right, Left, Right. Choose **Enable installer and restart**, set a developer password, and note the IP address. That password is `ROKUPASS`. It is not stored in this repo. After the restart the TV stays in developer mode. The installer page is `http://<ip>/`.

Only one sideloaded app fits on a device. Installing this one replaces whatever dev app was there. Sideloading the same `build_version` fails with an identical-version error. Bump `build_version` in `channel/manifest` when the package changes.

The house TV address used by the scripts is `192.168.86.101`.

## Deploy

`GUEST_PATH_KEY` is the secret path segment from above. Export it in the shell. Do not write it into a file in this repo.

```bash
export ROKUPASS='the-password-set-on-the-tv'
export GUEST_PATH_KEY
export ROKU_IP=192.168.86.101   # optional; this is the default
./scripts/deploy.sh
```

Without `GUEST_PATH_KEY`, packaging exits nonzero and says the key is not set. Two explicit exceptions skip the key:

```bash
./scripts/deploy.sh --no-guest
./scripts/deploy.sh --stub "http://<lan-ip>:8765/guest.json"
```

`--no-guest` packages an empty key, so the device never requests a guest document and the fallback greeting remains. `--stub` packages a development URL and does not embed `GUEST_PATH_KEY`, even if that variable is set. The stub server speaks HTTP on port 8765 and ignores the cache-busting query:

```bash
python3 scripts/stub-guest.py
```

Use the machine's LAN address in `--stub`, not `127.0.0.1`, so the TV can reach it. The sample body is a fictional guest, Alex Rivera, with a checkout in 2037.

`scripts/package.sh` zips a staged copy of `channel/` with `manifest` at the root of the archive (Roku rejects a zip that wraps the channel in a folder). The generated `components/secrets.brs` is added in that copy. A `secrets.brs` left in the working tree is not what gets packaged, and git ignores it. `scripts/deploy.sh` uploads the zip to `http://$ROKU_IP/plugin_install` as user `rokudev` with HTTP digest. The password is written to a mode-0600 curl config file and is not passed on the curl command line. The script prints **Install Success** or the device's failure text, and exits non-zero on failure. HTTP 401 means the password or developer mode is wrong.

PowerShell, same flags and environment variables:

```powershell
$env:ROKUPASS = 'the-password-set-on-the-tv'
# Set $env:GUEST_PATH_KEY in this session only. Do not save it.
.\scripts\deploy.ps1
.\scripts\deploy.ps1 --no-guest
.\scripts\deploy.ps1 --stub "http://<lan-ip>:8765/guest.json"
```

Do not leave the key in a PowerShell profile or a committed script. `scripts/package.ps1` builds the zip on its own if you only want the archive.

`scripts/check_tracked_guest_key.py` runs from packaging and from `scripts/validate.py`. It uses `git grep` and fails if a tracked file contains a concrete `sunrivertownhome.com/tv/<segment>/guest.json` URL, a key-like string returned from channel code, or a tracked `secrets.brs`. A short word of only letters is not treated as a key. The documentation form with angle brackets is not a match. The check prints file names, not the matching line.

## Check-in launch

Hubitat turns the TV on and starts the app over ECP. The commands, Fast TV start, Control by mobile apps, and a note on Guest Mode are in [docs/ECP.md](docs/ECP.md). A relaunch while the app is open fetches the guest document again.

## If this is published later

Sideloading does not go through certification. A public listing would. The manifest already sets `rsg_version=1.3`, FHD and HD icons (540×405 and 290×218), and FHD, HD, and SD splash images. The app subscribes to `roAppMemoryMonitor` warnings. In the Developer Dashboard, set the package's minimum firmware to 15.1.0 or greater. That minimum is a dashboard field, not a manifest key. The title does not contain "Roku". Bump the version for every package. The path key is injected at package time and is not part of the git history. Guest names are not in the package. This repo has not been submitted, and the Design & UX guidelines and the pre-certification checklist were not used as a review pass.

## Checks without a Roku

```bash
python3 scripts/validate.py          # manifest, image sizes, greeting rules, key check
./scripts/package.sh --no-guest      # zip layout and the 4 MB cap
./scripts/test_guest_package.sh      # key required, injected only into the zip, stub, grep
./scripts/test_deploy.sh             # installer success/failure, password not in curl's argv
npm install
npm run lint                         # bslint and the brighterscript compiler
python3 scripts/render_preview.py    # 1920×1080 previews, including a long name
./scripts/test_brs_greeting.sh       # names, checkout instants, and wrap on the brs interpreter
```

`brs` 0.45 runs the BrightScript greeting and checkout functions. It does not implement SceneGraph (`roSGScreen` is absent), and the `brs-engine` package is not published on npm, so there is no headless render of the channel. The pictures below are layout previews drawn from the same JPEG, scrim, and greeting rules. The typeface is Inter Bold standing in for the Roku system font. They are not photographs of the TV.

![Welcome screen preview, fallback greeting. Not a device capture.](docs/screenshots/welcome-fallback-preview.jpg)

![Welcome screen preview with a sample first and last name. Not a device capture.](docs/screenshots/welcome-named-preview.jpg)

![Welcome screen preview with a long name wrapped onto the dark bar. Not a device capture.](docs/screenshots/welcome-long-name-preview.jpg)

Still needs the house TV: sideload, the real system font, the live path key, Back and Home, digest install, `PowerOn` with Fast TV start, `POST /launch/dev`, `query/active-app`, relaunch while the app is open, and Guest Mode closing the app.

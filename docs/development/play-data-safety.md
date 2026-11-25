# Google Play Data safety answers

A draft of the answers for Play Console → **App content → Data safety**,
checked against the code (audit items APP-14 and the Data safety list in the
November 2026 audit). Fill the form in from this, then keep this file in step
with the form and the [privacy policy](https://groovefolio.app/privacy/).

Items marked **Check** depend on something outside this repository.

## What never leaves the phone

Play only asks about data that leaves the device. None of this does, so none
of it is declared:

- the collection: records, artists, genres, tracks, purchase dates and prices;
- play history and stats;
- cover photos taken or picked by the user, and downloaded artwork;
- NFC tag links;
- tutorial progress, settings and notifications;
- camera frames from the barcode scanner (ML Kit decodes them on the device).

Backups (Settings → Back up collection, once PR #101 is merged) are written
to a file the user picks with the system file picker. Groovefolio doesn't
upload them anywhere.

## Overview questions

| Question | Answer | Why |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | Discogs features send data to the Groovefolio server; ML Kit sends diagnostics to Google. |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | The app only talks to `https://api.groovefolio.app` and Discogs image hosts over HTTPS (`BackendTransport`, `DiscogsApiClient.downloadImage` reject anything else). Google states ML Kit sends its metrics over HTTPS. |
| Do you provide a way for users to request that their data is deleted? | **Yes** | **Settings → Discogs → Disconnect** deletes the Discogs username, account ID, credentials and the installation record from the server straight away (with PR #133). See [Deletion](#deletion). |
| Account creation | **No account** | Users don't create a Groovefolio account. Connecting Discogs links their existing Discogs account through Discogs' own sign-in. |

## Data types

### Collected only when the user connects Discogs (optional)

| Play data type | What it is | Collected | Shared | Ephemeral | Required or optional | Purpose |
|---|---|---|---|---|---|---|
| **Personal info → User IDs** | Discogs username and numeric account ID, stored on the server with the connection | Yes | No | No | Optional | App functionality |
| **App activity → In-app search history** | Artist/title searches and scanned barcode values, sent to the server and passed on to Discogs | Yes | No¹ | **Yes**² | Optional | App functionality |
| **Device or other IDs** | The random Groovefolio installation ID and its token, created when the user taps Connect | Yes | No | No | Optional | App functionality; Fraud prevention, security, and compliance |

¹ The server passes searches to Discogs only because the user asked it to
search Discogs. Play doesn't count a transfer the user starts themselves, and
expects, as sharing.
² The server doesn't store search terms or barcodes, and its access log is
switched off (`server.tomcat.accesslog.enabled: false` in the backend's
`application.yaml`). **Check** that production keeps it off, and that
Cloudflare isn't set to log query strings.

### Collected by Google ML Kit when the user scans a barcode (optional)

The barcode scanner (`mobile_scanner`, bundled ML Kit model) sends technical
data to Google. Our privacy policy, section 4, already lists it: device and OS
details, app and package versions, an SDK installation identifier, performance
measurements, scanner configuration, event types and error codes.

| Play data type | Collected | Shared | Ephemeral | Required or optional | Purpose |
|---|---|---|---|---|---|
| **App info and performance → Diagnostics** | Yes | No | No | Optional | Analytics |
| **App info and performance → Other app performance data** | Yes | No | No | Optional | Analytics |
| **Device or other IDs** (SDK installation identifier) | Yes | No | No | Optional | Analytics |

**Check** these rows against Google's own list at
<https://developers.google.com/ml-kit/android-data-disclosure> before
submitting. Google publishes the exact Data safety answers for each ML Kit
API there, and they can change. (I couldn't open that page from the cloud
session that wrote this draft.) Mark the scanner optional: people can add
records by hand or by search without ever scanning.

When filling in **Device or other IDs**, tick all the purposes from both
tables above. Play asks once per data type, not once per source.

### Not collected

Location, contacts, financial info (purchase prices stay on the phone),
health, messages, photos and videos, audio, files and docs, calendar, web
browsing, and other personal info.

**IP addresses.** Like any internet request, the server, Cloudflare and
Discogs' image hosts see the phone's IP address. The server keeps only a
hash of it, to limit how many installations one network can register. Play
doesn't ask about IP addresses as a data type unless they're used to work out
location, which Groovefolio doesn't do. The privacy policy already mentions
this.

## Deletion

- **Disconnect** (Settings → Discogs) deletes the connection, Discogs
  username, account ID and encrypted credentials from the server, then the
  installation record itself (random ID, token hash, expiry), and forgets the
  installation on the phone (PR #133). If the second step can't reach the
  server, the installation is deleted automatically when it expires, within
  about a minute of expiry.
- If the user never disconnects, an unused installation is deleted when it
  expires.
- Uninstalling the app or clearing its data deletes everything on the phone.
  Android backup is off, so nothing is restored on reinstall.
- ML Kit's diagnostics are held by Google under Google's terms.

## Security practices section

| Question | Answer |
|---|---|
| Data is encrypted in transit | Yes |
| Users can request that data be deleted | Yes (above) |
| Committed to follow the Play Families Policy | No (not aimed at children) |
| Independent security review | No |

## Before submitting

1. Check the ML Kit rows against Google's page (above).
2. Check production logging (footnote 2).
3. Make sure the published privacy policy matches these answers. The audit's
   wording fixes still apply: P27 should say the connection renews when the
   app is used while connected (true with the Discogs keep-alive, PR #122,
   and backend PR #17); P13 should say the IP hash is used only for
   registration limits.
4. Re-check this file whenever a PR adds a network call, an SDK, or a new
   kind of data sent off the phone.

# Notes for testers

## Old test builds are a separate app (APP-33)

Builds from before the permanent app ID was chosen are installed as
`com.huntergoller.vinyl_app`. Current builds are `app.groovefolio`. Android
treats them as two different apps:

- installing a new build does **not** upgrade or replace the old one, so both
  icons can appear;
- the old app's collection, plays and NFC tag links **stay in the old app**.
  There's no way to move them across, because old builds have no backup or
  export;
- NFC tags written by the old app still point at the old app.

### What to ask each tester

Send this to anyone who had a build from before the ID change:

> **Groovefolio test build: please remove the old version**
>
> If you have an older Groovefolio test build, you may now see two Groovefolio
> icons. The old one won't get updates. Please:
>
> 1. Open the **old** Groovefolio and note any records you want to keep
>    (or take screenshots). Its data can't be moved to the new version.
> 2. Uninstall the old one: long-press its icon → **Uninstall**. If you're not
>    sure which is old, go to **Settings → Apps**: the old one's package is
>    `com.huntergoller.vinyl_app`.
> 3. In the new version, add your records again. **Re-link any NFC tags** from
>    each record's page (they still point at the old app until you do).
>
> If you connected Discogs in the old version, uninstalling it also removes
> the old Discogs sign-in stored on your phone. You can import your Discogs
> collection into the new version: **Settings → Discogs → Connect Discogs**,
> then **Import Discogs collection**.

### Checking which build someone has

**Settings → About** in the app shows the version. On the phone,
**Settings → Apps → Groovefolio → App details** shows the package name.

## Before reporting a bug

- Say which build (version and number from **Settings → About**).
- Say whether Discogs is connected.
- For NFC problems, say whether the app was open, in the background or closed.

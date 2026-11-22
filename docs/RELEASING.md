# Releasing Unchair

Unchair is distributed as a free beta: a DMG on GitHub Releases, signed to run
locally (ad hoc), with automatic updates through [Sparkle](https://sparkle-project.org).
Developer ID signing and notarization come later, with an Apple Developer account.

## One-time setup

1. Build the project in Xcode once, so the Sparkle package (and its tools) is downloaded.
2. Create the update signing keys:

   ```sh
   scripts/generate-update-keys.sh
   ```

   This writes the public key into `Config/Unchair-Info.plist` (commit that change)
   and exports the private key to `~/.unchair/sparkle_private_key`. Keep it safe:
   anyone with it can publish updates to your users.

3. Add the private key to GitHub:

   ```sh
   gh secret set SPARKLE_PRIVATE_KEY < ~/.unchair/sparkle_private_key
   ```

4. Turn on GitHub Pages for the repository: **Settings → Pages → Deploy from a
   branch → `main` / `docs`**. This serves the website, the privacy policy, and
   `appcast.xml` at `https://lukazovic.github.io/unchair/`.

## Publishing a release

```sh
git tag v0.2.0
git push origin v0.2.0
```

The **Release** workflow builds the DMG, creates a GitHub release (marked as a
pre-release), signs the update, and commits the new `docs/appcast.xml`. Apps
with automatic checks on will offer the update within a day, or right away from
**More → Check for Updates…**.

Without the `SPARKLE_PRIVATE_KEY` secret, the workflow still publishes the DMG
but skips the appcast, so existing installs won't be offered the update.

## Building a DMG locally

```sh
scripts/make-dmg.sh 0.2.0
```

The DMG lands in `build/`. Share it with testers along with the install
instructions on the website (the first launch needs **Open Anyway** in System
Settings because the app isn't notarized yet).

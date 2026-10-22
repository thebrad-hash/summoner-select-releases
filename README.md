# Summoner Select: test builds

Summoner Select runs your League of Legends lobby and champ select from your phone, with a draft coach built in. This repository holds the **closed test builds for Windows**. The source code is private.

These are early test builds for a small group of testers. They are **not signed yet**, so expect rough edges.

## Install

Open PowerShell (right-click Start → Terminal) and paste:

```powershell
irm https://raw.githubusercontent.com/thebrad-hash/summoner-select-releases/main/install.ps1 | iex
```

The command:
1. downloads the newest installer from [Releases](https://github.com/thebrad-hash/summoner-select-releases/releases);
2. checks it against the SHA-256 published with that release;
3. installs Summoner Select for your Windows user only, with no admin prompt;
4. starts the app.

You can [read the script](install.ps1) before running it.

**If you'd rather click:** download `SummonerSelect-…-setup.exe` from the [latest release](https://github.com/thebrad-hash/summoner-select-releases/releases/latest) and run it. Because the build is new and unsigned, Windows will show "Windows protected your PC": choose **More info → Run anyway**.

## Verify this build

From v0.9.2 on, every installer here is built by [GitHub Actions](.github/workflows/release.yml) on GitHub's own Windows machines from a tagged version of the private source, never on a developer's PC. GitHub signs a record of each build (a build provenance attestation) and locks each release, so its files can't be swapped afterwards.

To check a download yourself, install the [GitHub CLI](https://cli.github.com) (2.81 or newer), sign in once with `gh auth login`, and run these in the folder that holds the installer. Replace `0.9.2` with your version.

```powershell
gh attestation verify SummonerSelect-0.9.2-setup.exe --repo thebrad-hash/summoner-select-releases --signer-workflow thebrad-hash/summoner-select-releases/.github/workflows/release.yml --source-ref refs/heads/main --deny-self-hosted-runners
gh release verify v0.9.2 --repo thebrad-hash/summoner-select-releases
gh release verify-asset v0.9.2 SummonerSelect-0.9.2-setup.exe --repo thebrad-hash/summoner-select-releases
```

1. The first checks the build provenance: this exact file came from this repository's release workflow, running on a GitHub-hosted runner.
2. The second checks that the release is immutable: its files and tag can't change.
3. The third checks that your file is byte-for-byte the one in that release.

Each release's notes link to its build log and name the source commit it was built from. Without the GitHub CLI you can still compare checksums: `Get-FileHash .\SummonerSelect-0.9.2-setup.exe` should print the SHA-256 shown on the release page. The install command does this for you.

v0.9.0 and v0.9.1 were built before this was set up, so they can't be checked this way.

## First run

1. **Allow network access.** Windows asks once whether the app may use your network. The prompt may say "Node.js JavaScript Runtime". Allow it on **private networks**, or your phone can't connect.
2. **Pair your phone.** Summoner Select shows a pairing QR code. Scan it with a phone on the same Wi-Fi.
3. **Play as usual.** Start League; the app follows your lobby and champ select.
4. **Voice control (optional).** Tap the mic on your phone. The first time, the app shows how to let the phone trust your PC (Settings → Voice), once per phone. The certificate it trusts is made on your PC and never leaves it.

On Windows 11 PCs with **Smart App Control** turned on, unsigned apps are blocked outright. Signed builds come later.

## What it connects to

- **The League client on your PC**, through the client's own local connection. It never asks for your Riot password.
- **Champion art** from CommunityDragon. The app keeps a copy on your PC.
- **Draft data** from the Summoner Select draft site.
- **Push notifications** through ntfy.sh, only if you turn them on.

## Update or uninstall

- **Update:** run the same command again. It installs the newest release over the old one and keeps your settings and paired phones.
- **Uninstall:** Settings → Apps → Installed apps → Summoner Select → Uninstall. Your settings stay in `%LOCALAPPDATA%\SummonerSelect`; delete that folder for a clean removal.

## Legal

Summoner Select isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties. Riot Games, and all associated properties are trademarks or registered trademarks of Riot Games, Inc.

All rights reserved. These builds are shared for testing only.

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

## First run

1. **Allow network access.** Windows asks once whether the app may use your network. The prompt may say "Node.js JavaScript Runtime". Allow it on **private networks**, or your phone can't connect.
2. **Pair your phone.** Summoner Select shows a pairing QR code. Scan it with a phone on the same Wi-Fi.
3. **Play as usual.** Start League; the app follows your lobby and champ select.

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

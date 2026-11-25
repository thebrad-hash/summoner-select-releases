# Summoner Select - installer for the closed test builds
#
# Run in PowerShell:
#   irm https://raw.githubusercontent.com/thebrad-hash/summoner-select-releases/main/install.ps1 | iex
#
# What it does:
#   1. finds the latest release in this repository
#   2. downloads the installer and SHA256SUMS.txt from that release
#   3. stops unless the installer's SHA-256 matches SHA256SUMS.txt
#   4. installs Summoner Select for the current Windows user only (no admin prompt)
#   5. starts it
#
# If Windows stops the installer or the app, it says so and points to https://summonerselect.com/blocked
# (the builds aren't signed yet, and Smart App Control can block unsigned apps). It only reads whether
# Smart App Control is on, after something failed. It changes no Windows setting.
#
# To download and check without installing, first run:
#   $env:SUMMONER_SELECT_DOWNLOAD_ONLY = '1'

& {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

  $repo = 'thebrad-hash/summoner-select-releases'
  $headers = @{ 'User-Agent' = 'summoner-select-installer'; 'Accept' = 'application/vnd.github+json' }
  $helpPage = 'https://summonerselect.com/blocked'

  # Called only after the installer or the app failed. Smart App Control's state is 1 when it is on; no value there,
  # or any error reading it, means we don't know. Returns true if it explained the failure, false if it only added
  # the help address (the caller then shows the error itself). Reword this once the builds are signed.
  function Show-BlockedHelp($Headline, $What, $Details) {
    $state = $null
    try {
      $policy = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' -Name 'VerifiedAndReputablePolicyState' -ErrorAction Stop
      $state = $policy.VerifiedAndReputablePolicyState
    } catch { }

    Write-Host ''
    if ($state -ne 1) {
      Write-Host "  If Windows blocked $What, see $helpPage"
      Write-Host ''
      return $false
    }
    Write-Host "  $Headline" -ForegroundColor Yellow
    Write-Host ''
    Write-Host "  Smart App Control is on for this PC. It can block apps that aren't signed,"
    Write-Host "  and Summoner Select's builds aren't signed yet. You can wait for the signed"
    Write-Host '  build, or turn Smart App Control off yourself. This page explains both:'
    Write-Host "  $helpPage"
    Write-Host ''
    Write-Host "  Details: $Details"
    Write-Host ''
    return $true
  }

  Write-Host ''
  Write-Host '  Summoner Select - test build' -ForegroundColor Yellow
  Write-Host ''

  $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers
  $setup = $release.assets | Where-Object { $_.name -like 'SummonerSelect-*-setup.exe' } | Select-Object -First 1
  $sums = $release.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' } | Select-Object -First 1
  if (-not $setup -or -not $sums) { throw "Release $($release.tag_name) has no installer or no SHA256SUMS.txt." }

  $dir = Join-Path $env:TEMP 'SummonerSelect-install'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $file = Join-Path $dir $setup.name
  $sumsFile = Join-Path $dir 'SHA256SUMS.txt'

  Write-Host ('  Downloading {0} ({1:N1} MB) from release {2}...' -f $setup.name, ($setup.size / 1MB), $release.tag_name)
  Invoke-WebRequest -Uri $setup.browser_download_url -OutFile $file -UseBasicParsing
  Invoke-WebRequest -Uri $sums.browser_download_url -OutFile $sumsFile -UseBasicParsing

  $line = Get-Content -Path $sumsFile | Where-Object { $_ -match ('\s\*?' + [regex]::Escape($setup.name) + '\s*$') } | Select-Object -First 1
  $expected = if ($line) { ($line -split '\s+')[0].ToUpperInvariant() } else { '' }
  $actual = (Get-FileHash -Path $file -Algorithm SHA256).Hash.ToUpperInvariant()
  if (-not $expected -or $expected -ne $actual) {
    Remove-Item -Path $file, $sumsFile -Force -ErrorAction SilentlyContinue
    throw 'Checksum mismatch: this download is not the published installer. Nothing was installed.'
  }
  Write-Host '  Checksum matches the release.' -ForegroundColor Green

  if ($env:SUMMONER_SELECT_DOWNLOAD_ONLY -eq '1') {
    Write-Host "  Download-only mode: nothing installed. The installer is at $file"
    Write-Host ''
    return
  }

  Write-Host '  Installing for this Windows user...'
  $headline = 'Nothing was installed: Windows most likely blocked the installer.'
  try {
    $proc = Start-Process -FilePath $file -ArgumentList '/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-' -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
      # 1 is the installer failing before its own program ran, as when Windows blocks that program. Other codes come
      # from that program itself (someone pressed Cancel, a file was in use), so a block is less likely.
      if ($proc.ExitCode -ne 1) { $headline = 'The installer stopped before it finished. Windows may have blocked it.' }
      throw "The installer stopped with exit code $($proc.ExitCode)."
    }
  } catch {
    if (Show-BlockedHelp $headline 'the installer' $_.Exception.Message) { return }
    throw
  } finally {
    Remove-Item -Path $file, $sumsFile -Force -ErrorAction SilentlyContinue
  }

  $app = Join-Path $env:LOCALAPPDATA 'Programs\Summoner Select\Summoner Select.exe'
  if (Test-Path -Path $app) {
    try {
      Start-Process -FilePath $app
    } catch {
      if (Show-BlockedHelp 'Installed, but Windows most likely blocked Summoner Select from starting.' 'Summoner Select' $_.Exception.Message) { return }
      throw
    }
    Write-Host '  Installed. Summoner Select is starting.' -ForegroundColor Green
  } else {
    Write-Host '  Installed. Open Summoner Select from the Start menu.' -ForegroundColor Green
  }
  Write-Host ''
  Write-Host '  Windows will ask once to let it use your network (it may say "Node.js").'
  Write-Host '  Allow it on private networks, or your phone cannot connect.'
  Write-Host ''
}

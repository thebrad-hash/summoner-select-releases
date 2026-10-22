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
# To download and check without installing, first run:
#   $env:SUMMONER_SELECT_DOWNLOAD_ONLY = '1'

& {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

  $repo = 'thebrad-hash/summoner-select-releases'
  $headers = @{ 'User-Agent' = 'summoner-select-installer'; 'Accept' = 'application/vnd.github+json' }

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
    Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
    throw 'Checksum mismatch: this download is not the published installer. Nothing was installed.'
  }
  Write-Host '  Checksum matches the release.' -ForegroundColor Green

  if ($env:SUMMONER_SELECT_DOWNLOAD_ONLY -eq '1') {
    Write-Host "  Download-only mode: nothing installed. The installer is at $file"
    Write-Host ''
    return
  }

  Write-Host '  Installing for this Windows user...'
  $proc = Start-Process -FilePath $file -ArgumentList '/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-' -Wait -PassThru
  Remove-Item -Path $file, $sumsFile -Force -ErrorAction SilentlyContinue
  if ($proc.ExitCode -ne 0) { throw "The installer stopped with exit code $($proc.ExitCode)." }

  $app = Join-Path $env:LOCALAPPDATA 'Programs\Summoner Select\Summoner Select.exe'
  if (Test-Path -Path $app) {
    Start-Process -FilePath $app
    Write-Host '  Installed. Summoner Select is starting.' -ForegroundColor Green
  } else {
    Write-Host '  Installed. Open Summoner Select from the Start menu.' -ForegroundColor Green
  }
  Write-Host ''
  Write-Host '  Windows will ask once to let it use your network (it may say "Node.js").'
  Write-Host '  Allow it on private networks, or your phone cannot connect.'
  Write-Host ''
}

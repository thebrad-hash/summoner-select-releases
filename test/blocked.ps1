# Checks what install.ps1 prints when Windows stops the installer or the app, and that a normal run is unchanged.
#
#   powershell -NoProfile -File test\blocked.ps1           add -Show to print what the person reads in each case
#
# Nothing is downloaded, installed or started, and nothing appears on the screen: the script's own text runs the way
# `irm ... | iex` runs it, in a throwaway folder, with stand-ins for the web calls, Start-Process and the registry
# read. -Path runs another copy, such as the one from before a change.
param([string] $Path, [switch] $Show)

if (-not $Path) { $Path = Join-Path $PSScriptRoot '..\install.ps1' }
$text = [IO.File]::ReadAllText((Resolve-Path -Path $Path).ProviderPath).Replace("`r`n", "`n")
$passed = 0
$failed = 0
function Assert-That($name, $ok, $detail) {
  if ($ok) { $script:passed++ } else { $script:failed++; Write-Host "FAIL  $name" -ForegroundColor Red; if ($detail) { Write-Host $detail } }
}

# --- The text itself. Anything outside these lists stops the test here, before any of it runs. ---

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref] $tokens, [ref] $errors)
Assert-That 'parses with no errors' ($errors.Count -eq 0) ($errors | Out-String)
Assert-That 'plain ASCII' ($text -notmatch '[^\x00-\x7f]')

$okCommands = 'Write-Host', 'Invoke-RestMethod', 'Invoke-WebRequest', 'Where-Object', 'Select-Object', 'Join-Path', 'New-Item', 'Out-Null',
  'Get-Content', 'Get-FileHash', 'Get-ItemProperty', 'Remove-Item', 'Start-Process', 'Test-Path', 'Show-BlockedHelp'
$okMembers = 'Escape', 'ToUpperInvariant'
$commands = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true))
$members = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.InvokeMemberExpressionAst] }, $true))
$unknown = @($commands | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ -and $okCommands -notcontains $_ })
$unknown += @($members | ForEach-Object { "$($_.Member)" } | Where-Object { $okMembers -notcontains $_ })
$unnamed = @($commands | Where-Object { -not $_.GetCommandName() })
Assert-That 'only known commands, and only the outer & { }' ($unknown.Count -eq 0 -and $unnamed.Count -eq 1) "unknown: $unknown; unnamed: $($unnamed.Count)"
Assert-That 'two starts: the installer and the app' (@($commands | Where-Object { $_.GetCommandName() -eq 'Start-Process' }).Count -eq 2)
Assert-That 'one block, no parameters' ($ast.EndBlock.Statements.Count -eq 1 -and -not $ast.ParamBlock)
if ($failed) { Write-Host "$passed passed, $failed failed; nothing was run."; exit 1 }

# --- Stand-ins. Functions come before cmdlets, so the script's calls land here. ---

$setupName = 'SummonerSelect-9.9.9-setup.exe'
$refused = 'This command cannot be run due to the error: An Application Control policy has blocked this file.'
$policyKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'

function Invoke-RestMethod { param($Uri, $Headers)
  [pscustomobject] @{ tag_name = 'v9.9.9'; assets = @(
      [pscustomobject] @{ name = $setupName; size = 41500000; browser_download_url = 'setup' },
      [pscustomobject] @{ name = 'SHA256SUMS.txt'; size = 99; browser_download_url = 'sums' }) }
}
function Invoke-WebRequest { param($Uri, $OutFile, [switch] $UseBasicParsing)
  if ($Uri -eq 'setup') { [IO.File]::WriteAllText($OutFile, 'stand-in, not a program'); return }
  $hash = (Get-FileHash -Path (Join-Path (Split-Path $OutFile) $setupName) -Algorithm SHA256).Hash
  if ($script:case.Sums -eq 'wrong') { $hash = '0' * 64 }
  [IO.File]::WriteAllText($OutFile, "$hash  $setupName`n")
}
function Start-Process { [CmdletBinding()] param($FilePath, $ArgumentList, [switch] $Wait, [switch] $PassThru)
  $what = if ($FilePath -like "*\$setupName") { 'Installer' } else { 'App' }
  $script:calls.Add("start $what $ArgumentList".Trim())
  if ($script:case[$what] -eq 'throws') {
    $problem = New-Object InvalidOperationException $refused
    $PSCmdlet.ThrowTerminatingError((New-Object System.Management.Automation.ErrorRecord $problem, 'InvalidOperationException', 'InvalidOperation', $null))
  }
  if ($PassThru) { [pscustomobject] @{ ExitCode = $script:case[$what] } }
}
function Get-ItemProperty { [CmdletBinding()] param($Path, $Name)
  $script:calls.Add("read $Path $Name")
  switch ($script:case.Sac) {
    'on' { [pscustomobject] @{ VerifiedAndReputablePolicyState = 1 } }
    'off' { [pscustomobject] @{ VerifiedAndReputablePolicyState = 0 } }
    'evaluation' { [pscustomobject] @{ VerifiedAndReputablePolicyState = 2 } }
    'unreadable' { throw (New-Object System.Security.SecurityException 'Requested registry access is not allowed.') }
    'missing key' { Microsoft.PowerShell.Management\Get-ItemProperty -Path "$Path\NoSuchKey" -Name $Name -ErrorAction Stop }
    'missing value' { Microsoft.PowerShell.Management\Get-ItemProperty -Path 'HKCU:\Environment' -Name $Name -ErrorAction Stop }
  }
}

# --- One run. ---

$plain = (Write-Host '' 6>&1).MessageData.ForegroundColor   # the colour a line has when none is asked for
$root = Join-Path ([IO.Path]::GetTempPath()) ('ss-install-test-' + [guid]::NewGuid().ToString('N'))
function Test-Case($name, $setup, $lines, $problem, $calls, $kept = 0) {
  $script:case = $setup
  $script:calls = New-Object 'Collections.Generic.List[string]'
  $temp = Join-Path $root 'Temp'
  $local = Join-Path $root 'Local'
  $app = Join-Path $local 'Programs\Summoner Select\Summoner Select.exe'
  New-Item -ItemType Directory -Force -Path $temp, (Split-Path $app) | Out-Null
  if ($setup.App -ne 'not there') { [IO.File]::WriteAllText($app, 'stand-in, not a program') }

  $printed = New-Object 'Collections.Generic.List[string]'
  $thrown = $null
  $before = $env:TEMP, $env:LOCALAPPDATA, $env:SUMMONER_SELECT_DOWNLOAD_ONLY
  try {
    $env:TEMP, $env:LOCALAPPDATA, $env:SUMMONER_SELECT_DOWNLOAD_ONLY = $temp, $local, $setup.DownloadOnly
    Invoke-Expression $text 6>&1 | ForEach-Object {
      $color = if ($_ -is [System.Management.Automation.InformationRecord]) { $_.MessageData.ForegroundColor } else { 'NOT PRINTED WITH Write-Host' }
      $printed.Add($(if ($color -ne $plain) { "[$color]$_" } else { "$_" }))
    }
  } catch { $thrown = $_ } finally {
    $env:TEMP, $env:LOCALAPPDATA, $env:SUMMONER_SELECT_DOWNLOAD_ONLY = $before
  }
  $left = @(Get-ChildItem -Path $temp -Recurse -Force | Where-Object { -not $_.PSIsContainer })
  Remove-Item -Path $root -Recurse -Force

  $printedText = $printed -join "`n"
  Assert-That "$name - the lines" ($printedText -ceq ($lines -join "`n")) "--- expected`n$($lines -join "`n")`n--- printed`n$printedText"
  Assert-That "$name - the error" ("$thrown" -ceq "$problem") "expected: $problem`nthrown:   $thrown"
  Assert-That "$name - the order of things" (($script:calls -join "`n") -ceq ($calls -join "`n")) "expected: $($calls -join '; ')`ncalled:   $($script:calls -join '; ')"
  Assert-That "$name - files left" ($left.Count -eq $kept) "expected $kept, left $($left.Count)"
  if ($Show) { Write-Host "`n=== $name" -ForegroundColor Cyan; $printed | Select-Object -Skip 6 | ForEach-Object { Write-Host $_ }; if ($thrown) { Write-Host "(red error) $thrown" -ForegroundColor Red } }
}

# --- What each case should print. [Yellow] and [Green] are the line's colour. ---

$checked = @('', '[Yellow]  Summoner Select - test build', '', ('  Downloading {0} ({1:N1} MB) from release v9.9.9...' -f $setupName, (41500000 / 1MB)))
$begin = $checked + '[Green]  Checksum matches the release.', '  Installing for this Windows user...'
$end = '', '  Windows will ask once to let it use your network (it may say "Node.js").', '  Allow it on private networks, or your phone cannot connect.', ''
$success = $begin + '[Green]  Installed. Summoner Select is starting.' + $end
function Get-Blocked($headline, $details) {
  $begin + '' + "[Yellow]  $headline" + '' + "  Smart App Control is on for this PC. It can block apps that aren't signed," +
    "  and Summoner Select's builds aren't signed yet. You can wait for the signed" +
    '  build, or turn Smart App Control off yourself. This page explains both:' + '  https://summonerselect.com/blocked' + '' + "  Details: $details" + ''
}
function Get-Hint($what) { $begin + '' + "  If Windows blocked $what, see https://summonerselect.com/blocked" + '' }

$installer = 'start Installer /SILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
$read = "read $policyKey VerifiedAndReputablePolicyState"
$nothing = 'Nothing was installed: Windows most likely blocked the installer.'
$stopped = 'The installer stopped before it finished. Windows may have blocked it.'
$notStarted = 'Installed, but Windows most likely blocked Summoner Select from starting.'

foreach ($sac in 'on', 'off', 'unreadable', 'evaluation', 'missing key', 'missing value') {
  $on = $sac -eq 'on'
  Test-Case "installer fine, Smart App Control $sac" @{ Installer = 0; App = 0; Sac = $sac } $success $null ($installer, 'start App')

  Test-Case "installer will not start, Smart App Control $sac" @{ Installer = 'throws'; App = 0; Sac = $sac } `
    $(if ($on) { Get-Blocked $nothing $refused } else { Get-Hint 'the installer' }) $(if (-not $on) { $refused }) ($installer, $read)

  foreach ($code in 1, 5) {
    $said = "The installer stopped with exit code $code."
    Test-Case "installer exits $code, Smart App Control $sac" @{ Installer = $code; App = 0; Sac = $sac } `
      $(if ($on) { Get-Blocked $(if ($code -eq 1) { $nothing } else { $stopped }) $said } else { Get-Hint 'the installer' }) $(if (-not $on) { $said }) ($installer, $read)
  }

  Test-Case "app will not start, Smart App Control $sac" @{ Installer = 0; App = 'throws'; Sac = $sac } `
    $(if ($on) { Get-Blocked $notStarted $refused } else { Get-Hint 'Summoner Select' }) $(if (-not $on) { $refused }) ($installer, 'start App', $read)
}

# The rest of the script, as it was.
Test-Case 'app not there after installing' @{ Installer = 0; App = 'not there'; Sac = 'on' } ($begin + '[Green]  Installed. Open Summoner Select from the Start menu.' + $end) $null @($installer)
Test-Case 'checksum mismatch' @{ Installer = 0; App = 0; Sac = 'on'; Sums = 'wrong' } $checked 'Checksum mismatch: this download is not the published installer. Nothing was installed.' @()
Test-Case 'download only' @{ Installer = 0; App = 0; Sac = 'on'; DownloadOnly = '1' } ($checked + '[Green]  Checksum matches the release.' +
  "  Download-only mode: nothing installed. The installer is at $(Join-Path $root "Temp\SummonerSelect-install\$setupName")" + '') $null @() 2

Write-Host "$passed passed, $failed failed (PowerShell $($PSVersionTable.PSVersion))"
if ($failed) { exit 1 }

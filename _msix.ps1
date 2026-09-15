# Builds an MSIX package of a game for the Microsoft Store.
# Called by <game>\export-msix.bat after _config.bat; reads the Store values from <game>\msix.env.
#
# Steps: export the Windows .exe with Godot, make the Store logos from icon.png, write
# AppxManifest.xml, pack with makeappx.exe (Windows SDK). With -Sign it also signs the package with a
# local test certificate, so it can be installed on this PC. Upload the unsigned package to the
# Store: Microsoft signs it there.

param(
    [Parameter(Mandatory)] [string] $Project,  # game folder
    [Parameter(Mandatory)] [string] $Godot,    # Godot console executable
    [Parameter(Mandatory)] [string] $Exe,      # executable name inside the package, e.g. Queens.exe
    [switch] $Sign
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function Fail([string] $message) {
    Write-Host ""
    Write-Host "ERROR: $message" -ForegroundColor Red
    exit 1
}

# --- Settings -------------------------------------------------------------------------------------

$Project = (Resolve-Path $Project).Path
$envFile = Join-Path $Project "msix.env"
if (-not (Test-Path $envFile)) { Fail "Settings file not found: $envFile" }
$settings = @{}
foreach ($line in Get-Content $envFile -Encoding UTF8) {
    $trimmed = $line.Trim()
    if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
    $index = $trimmed.IndexOf("=")
    if ($index -lt 1) { continue }
    $settings[$trimmed.Substring(0, $index).Trim()] = $trimmed.Substring($index + 1).Trim()
}
foreach ($key in "IDENTITY_NAME", "PUBLISHER", "PUBLISHER_DISPLAY_NAME", "DISPLAY_NAME", "DESCRIPTION", "VERSION") {
    if (-not $settings.ContainsKey($key) -or $settings[$key] -eq "") { Fail "$key is missing in $envFile" }
}
$background = if ($settings["BACKGROUND_COLOR"]) { $settings["BACKGROUND_COLOR"] } else { "transparent" }
$languages = if ($settings["LANGUAGES"]) { $settings["LANGUAGES"].Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ } } else { @("en-us") }

if ($settings["IDENTITY_NAME"] -notmatch '^[A-Za-z0-9.\-]{3,50}$') { Fail "IDENTITY_NAME may only use letters, digits, '.' and '-' (3-50 characters)." }
if ($settings["VERSION"] -notmatch '^\d+\.\d+\.\d+\.0$') { Fail "VERSION must look like 1.0.0.0 (the Store needs the last number to be 0)." }
if ($settings["PUBLISHER"] -notmatch '^CN=') { Fail "PUBLISHER must start with CN=, exactly as shown in Partner Center." }
$placeholder = ($settings["IDENTITY_NAME"] + $settings["PUBLISHER"]) -match "CHANGEME"
if ($placeholder) {
    Write-Host "Note: msix.env still has placeholder values. The package works for testing, but the Store" -ForegroundColor Yellow
    Write-Host "      will reject it until IDENTITY_NAME and PUBLISHER match Partner Center." -ForegroundColor Yellow
}

# --- Windows SDK tools --------------------------------------------------------------------------------

function Find-SdkTool([string] $name) {
    $root = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
    if (-not (Test-Path $root)) { return $null }
    $found = Get-ChildItem $root -Recurse -Filter $name -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -eq "x64" } |
        Sort-Object { [version]($_.Directory.Parent.Name) } -Descending |
        Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}
$makeappx = Find-SdkTool "makeappx.exe"
if (-not $makeappx) { Fail "makeappx.exe not found. Install the Windows SDK: winget install Microsoft.WindowsSDK.10.0.26100" }

# --- Folders --------------------------------------------------------------------------------------------

$outDir = Join-Path $Project "build\msix"
$stage = Join-Path $outDir "package"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $stage "Assets") | Out-Null

# --- 1. Export the game ------------------------------------------------------------------------------------

Write-Host "Exporting $Exe with Godot..."
& $Godot --headless --path $Project --export-release "Windows" (Join-Path $stage $Exe)
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $stage $Exe))) { Fail "Godot export failed, see the messages above." }
# The console wrapper is only for running from a terminal; the Store package doesn't need it.
Get-ChildItem $stage -Filter "*.console.exe" | Remove-Item -Force

# --- 2. Store logos from icon.png ----------------------------------------------------------------------------

$iconPath = Join-Path $Project "icon.png"
if (-not (Test-Path $iconPath)) { Fail "icon.png not found in $Project" }
$icon = [System.Drawing.Image]::FromFile($iconPath)

function Save-Logo([string] $file, [int] $width, [int] $height, [double] $scale) {
    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $side = [int]([Math]::Min($width, $height) * $scale)
    $graphics.DrawImage($icon, [int](($width - $side) / 2), [int](($height - $side) / 2), $side, $side)
    $graphics.Dispose()
    $bitmap.Save((Join-Path $stage "Assets\$file"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

Write-Host "Making Store logos from icon.png..."
Save-Logo "StoreLogo.png" 50 50 1.0
Save-Logo "Square44x44Logo.png" 44 44 1.0
Save-Logo "Square71x71Logo.png" 71 71 0.8
Save-Logo "Square150x150Logo.png" 150 150 0.7
Save-Logo "Square310x310Logo.png" 310 310 0.7
Save-Logo "Wide310x150Logo.png" 310 150 0.8
Save-Logo "SplashScreen.png" 620 300 0.8
# Taskbar / Start list icons at exact sizes, without the tile plate.
foreach ($px in 16, 24, 32, 48, 256) {
    Save-Logo "Square44x44Logo.targetsize-$px.png" $px $px 1.0
    Save-Logo "Square44x44Logo.targetsize-${px}_altform-unplated.png" $px $px 1.0
}
$icon.Dispose()

# --- 3. AppxManifest.xml ------------------------------------------------------------------------------------------

function Xml([string] $text) { return [System.Security.SecurityElement]::Escape($text) }

$resources = ($languages | ForEach-Object { "    <Resource Language=`"$(Xml $_)`" />" }) -join "`r`n"
$manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<Package
  xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
  xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
  xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
  IgnorableNamespaces="uap rescap">

  <Identity
    Name="$(Xml $settings["IDENTITY_NAME"])"
    Publisher="$(Xml $settings["PUBLISHER"])"
    Version="$(Xml $settings["VERSION"])"
    ProcessorArchitecture="x64" />

  <Properties>
    <DisplayName>$(Xml $settings["DISPLAY_NAME"])</DisplayName>
    <PublisherDisplayName>$(Xml $settings["PUBLISHER_DISPLAY_NAME"])</PublisherDisplayName>
    <Logo>Assets\StoreLogo.png</Logo>
  </Properties>

  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.17763.0" MaxVersionTested="10.0.26100.0" />
  </Dependencies>

  <Resources>
$resources
  </Resources>

  <Applications>
    <Application Id="App" Executable="$(Xml $Exe)" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements
        DisplayName="$(Xml $settings["DISPLAY_NAME"])"
        Description="$(Xml $settings["DESCRIPTION"])"
        BackgroundColor="$(Xml $background)"
        Square150x150Logo="Assets\Square150x150Logo.png"
        Square44x44Logo="Assets\Square44x44Logo.png">
        <uap:DefaultTile Wide310x150Logo="Assets\Wide310x150Logo.png" Square71x71Logo="Assets\Square71x71Logo.png" Square310x310Logo="Assets\Square310x310Logo.png" />
        <uap:SplashScreen Image="Assets\SplashScreen.png" />
      </uap:VisualElements>
    </Application>
  </Applications>

  <Capabilities>
    <rescap:Capability Name="runFullTrust" />
  </Capabilities>
</Package>
"@
[System.IO.File]::WriteAllText((Join-Path $stage "AppxManifest.xml"), $manifest, (New-Object System.Text.UTF8Encoding $false))

# --- 4. Pack -----------------------------------------------------------------------------------------------------------

$baseName = "{0}_{1}_x64" -f ($Exe -replace '\.exe$', ''), $settings["VERSION"]
$msix = Join-Path $outDir "$baseName.msix"
Write-Host "Packing $baseName.msix..."
$packLog = & $makeappx pack /d $stage /p $msix /o 2>&1
if ($LASTEXITCODE -ne 0) {
    $packLog | ForEach-Object { Write-Host $_ }
    Fail "makeappx failed, see the messages above."
}

# --- 5. Optional test signature ----------------------------------------------------------------------------------------

if ($Sign) {
    $signtool = Find-SdkTool "signtool.exe"
    if (-not $signtool) { Fail "signtool.exe not found (Windows SDK)." }
    $pfx = Join-Path $outDir "test-certificate.pfx"
    $cer = Join-Path $outDir "test-certificate.cer"
    $password = "test"
    # The certificate subject must match PUBLISHER exactly, or Windows refuses the package.
    $existing = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $settings["PUBLISHER"] -and $_.HasPrivateKey } | Select-Object -First 1
    if (-not $existing) {
        Write-Host "Creating a test certificate for $($settings["PUBLISHER"])..."
        $existing = New-SelfSignedCertificate -Type Custom -Subject $settings["PUBLISHER"] -KeyUsage DigitalSignature `
            -FriendlyName "MSIX test certificate" -CertStoreLocation "Cert:\CurrentUser\My" `
            -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")
    }
    Export-PfxCertificate -Cert $existing -FilePath $pfx -Password (ConvertTo-SecureString $password -AsPlainText -Force) | Out-Null
    Export-Certificate -Cert $existing -FilePath $cer | Out-Null
    $signLog = & $signtool sign /fd SHA256 /a /f $pfx /p $password $msix 2>&1
    if ($LASTEXITCODE -ne 0) {
        $signLog | ForEach-Object { Write-Host $_ }
        Fail "signtool failed, see the messages above."
    }
    Write-Host ""
    Write-Host "Signed with a test certificate. To install the package on this PC, trust the certificate once"
    Write-Host "(PowerShell as administrator):"
    Write-Host "  Import-Certificate -FilePath `"$cer`" -CertStoreLocation Cert:\LocalMachine\TrustedPeople"
    Write-Host "then double-click the .msix. Upload the unsigned package (without 'sign') to the Store."
}

Write-Host ""
Write-Host "Done: $msix" -ForegroundColor Green

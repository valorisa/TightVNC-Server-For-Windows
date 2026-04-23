#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Affiche un rapport complet de l'état de TightVNC Server sur la machine locale.
.DESCRIPTION
    Vérifie et affiche : l'état du service Windows, le port d'écoute réseau,
    les règles de pare-feu, la version installée, les paramètres de registre clés,
    et les connexions VNC actives en cours.
.PARAMETER Detailed
    Affiche la configuration complète du registre TightVNC. Défaut : $false.
.PARAMETER ExportReport
    Exporte le rapport dans un fichier texte horodaté. Défaut : $false.
.PARAMETER ReportPath
    Chemin d'export du rapport. Défaut : C:\Logs\tightvnc-status-report.txt.
.EXAMPLE
    .\Get-TightVNCStatus.ps1
.EXAMPLE
    .\Get-TightVNCStatus.ps1 -Detailed -ExportReport $true
.NOTES
    Auteur  : valorisa
    Version : 1.0.0
    Projet  : tightvnc-2887-windows-guide
    Licence : MIT
#>

[CmdletBinding()]
param(
    [Parameter()] [switch] $Detailed,
    [Parameter()] [bool]   $ExportReport = $false,
    [Parameter()] [string] $ReportPath   = "C:\Logs\tightvnc-status-report.txt"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

$report = [System.Collections.Generic.List[string]]::new()

function Write-Section {
    param([string]$Title)
    $line = "`n$('─' * 60)"
    $section = "  $Title"
    Write-Host $line -ForegroundColor DarkGray
    Write-Host $section -ForegroundColor Cyan
    Write-Host $('─' * 60) -ForegroundColor DarkGray
    $report.Add($line); $report.Add($section); $report.Add('─' * 60)
}

function Write-Info {
    param([string]$Label, [string]$Value, [string]$Color = "White")
    $line = "  {0,-35}: {1}" -f $Label, $Value
    Write-Host $line -ForegroundColor $Color
    $report.Add($line)
}

# ── En-tête ───────────────────────────────────────────────────────────────────
$header = @"

╔══════════════════════════════════════════════════════════╗
║          TightVNC Server — Rapport d'état               ║
╚══════════════════════════════════════════════════════════╝
"@
Write-Host $header -ForegroundColor Cyan
$report.Add($header)
Write-Info "Hôte"  $env:COMPUTERNAME
Write-Info "Date"  (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Write-Info "Utilisateur" "$env:USERDOMAIN\$env:USERNAME"

# ── Section 1 : Service Windows ───────────────────────────────────────────────
Write-Section "1. SERVICE WINDOWS"

$svc = Get-Service -Name "tvnserver" -ErrorAction SilentlyContinue
if ($svc) {
    $statusColor = if ($svc.Status -eq "Running") { "Green" } else { "Red" }
    Write-Info "Nom du service"      $svc.Name
    Write-Info "Statut"              $svc.Status $statusColor
    Write-Info "Type de démarrage"   $svc.StartType
    Write-Info "Nom d'affichage"     $svc.DisplayName

    # Chemin de l'exécutable du service
    $svcWmi = Get-CimInstance -ClassName Win32_Service -Filter "Name='tvnserver'" -ErrorAction SilentlyContinue
    if ($svcWmi) {
        Write-Info "Chemin exécutable"  $svcWmi.PathName
        Write-Info "Compte service"     $svcWmi.StartName
    }
} else {
    Write-Info "Service tvnserver"   "NON TROUVÉ" "Red"
}

# ── Section 2 : Version installée ─────────────────────────────────────────────
Write-Section "2. VERSION INSTALLÉE"

$pkg = Get-Package -Name "TightVNC*" -ErrorAction SilentlyContinue
if ($pkg) {
    Write-Info "Nom"      $pkg.Name        "Green"
    Write-Info "Version"  $pkg.Version     "Green"
    Write-Info "Source"   $pkg.Source
} else {
    Write-Info "TightVNC" "Non installé via Windows Installer" "Yellow"
    # Tentative via registre uninstall
    $uninstKey = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                 Where-Object { $_.DisplayName -like "*TightVNC*" } | Select-Object -First 1
    if ($uninstKey) {
        Write-Info "Nom (registre)"    $uninstKey.DisplayName   "Green"
        Write-Info "Version (registre)" $uninstKey.DisplayVersion "Green"
        Write-Info "Installé le"       $uninstKey.InstallDate
    }
}

# ── Section 3 : Port réseau ───────────────────────────────────────────────────
Write-Section "3. PORT RÉSEAU"

$regPath = "HKLM:\SOFTWARE\TightVNC\Server"
$configuredPort = 5900
if (Test-Path $regPath) {
    $configuredPort = (Get-ItemProperty $regPath -ErrorAction SilentlyContinue).RfbPort
    if (-not $configuredPort) { $configuredPort = 5900 }
}

Write-Info "Port configuré (RFB)"  "$configuredPort/TCP"

$listener = Get-NetTCPConnection -LocalPort $configuredPort -State Listen -ErrorAction SilentlyContinue
if ($listener) {
    Write-Info "Port $configuredPort"  "EN ÉCOUTE ✓" "Green"
    $listener | ForEach-Object {
        Write-Info "  Adresse locale"   "$($_.LocalAddress):$($_.LocalPort)"
    }
} else {
    Write-Info "Port $configuredPort"  "NON EN ÉCOUTE ✗" "Yellow"
}

# Sessions VNC actives
$activeSessions = Get-NetTCPConnection -LocalPort $configuredPort -State Established -ErrorAction SilentlyContinue
if ($activeSessions) {
    Write-Info "Connexions actives"  "$($activeSessions.Count) session(s) VNC en cours" "Magenta"
    $activeSessions | ForEach-Object {
        Write-Info "  Client connecté"  "$($_.RemoteAddress):$($_.RemotePort)"
    }
} else {
    Write-Info "Connexions actives"  "Aucune session VNC en cours"
}

# ── Section 4 : Pare-feu ─────────────────────────────────────────────────────
Write-Section "4. RÈGLES PARE-FEU"

$fwRules = Get-NetFirewallRule -DisplayName "TightVNC*" -ErrorAction SilentlyContinue
if ($fwRules) {
    foreach ($rule in $fwRules) {
        $color = if ($rule.Enabled -eq "True") { "Green" } else { "Red" }
        Write-Info "Règle"    "$($rule.DisplayName) [Activée: $($rule.Enabled)]" $color
    }
} else {
    Write-Info "Règles TightVNC"  "Aucune règle trouvée dans le pare-feu" "Yellow"
}

# ── Section 5 : Configuration registre ───────────────────────────────────────
Write-Section "5. CONFIGURATION (REGISTRE)"

if (Test-Path $regPath) {
    $config = Get-ItemProperty $regPath -ErrorAction SilentlyContinue

    $keyMap = [ordered]@{
        "RfbPort"               = "Port VNC (RFB)"
        "HttpPort"              = "Port HTTP viewer"
        "EnableHttpServer"      = "HTTP viewer activé"
        "UseVncAuthentication"  = "Auth VNC activée"
        "EnableFileTransfers"   = "Transferts de fichiers"
        "BlockLocalInput"       = "Bloquer entrées locales"
        "RemoveWallpaper"       = "Masquer fond d'écran"
        "QueryOnlyIfLoggedOn"   = "Query si connecté seulement"
        "EnableIpAccessControl" = "Filtrage par IP"
    }

    foreach ($key in $keyMap.Keys) {
        $val = $config.$key
        if ($null -ne $val) {
            Write-Info $keyMap[$key]  "$val"
        }
    }

    if ($Detailed) {
        Write-Section "5b. CONFIGURATION COMPLÈTE (DÉTAIL)"
        $config | Format-List | Out-String | ForEach-Object {
            Write-Host $_ -ForegroundColor Gray
            $report.Add($_)
        }
    }
} else {
    Write-Info "Registre TightVNC"  "Clé introuvable — TightVNC Server peut-être absent" "Red"
}

# ── Section 6 : Processus en cours ───────────────────────────────────────────
Write-Section "6. PROCESSUS EN COURS"

$procs = @("tvnserver", "tvnviewer", "tvncontrol")
foreach ($pName in $procs) {
    $p = Get-Process -Name $pName -ErrorAction SilentlyContinue
    if ($p) {
        Write-Info "$pName.exe"  "En cours (PID: $($p.Id), Mémoire: $([math]::Round($p.WorkingSet64/1MB,1)) Mo)" "Green"
    } else {
        Write-Info "$pName.exe"  "Non démarré"
    }
}

# ── Export du rapport ─────────────────────────────────────────────────────────
if ($ExportReport) {
    New-Item -ItemType Directory -Path (Split-Path $ReportPath) -Force -ErrorAction SilentlyContinue | Out-Null
    $report | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Host "`n  Rapport exporté : $ReportPath`n" -ForegroundColor Green
}

Write-Host "`n$('═' * 62)`n" -ForegroundColor DarkGray

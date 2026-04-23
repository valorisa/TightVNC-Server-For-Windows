#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installation silencieuse de TightVNC 2.8.87 sur Windows 11 Enterprise.
.DESCRIPTION
    Télécharge (optionnellement) et installe TightVNC 2.8.87 en mode silencieux
    via msiexec. Permet d'installer le Server seul, le Viewer seul, ou les deux.
    Configure les mots de passe, le service Windows et les options de démarrage.
.PARAMETER MsiPath
    Chemin vers le fichier MSI local. Si absent, le script télécharge le MSI.
.PARAMETER Architecture
    Architecture cible : '64bit' (défaut) ou '32bit'.
.PARAMETER Components
    Composants à installer : 'ALL' (défaut), 'Server', 'Viewer'.
.PARAMETER VncPassword
    Mot de passe VNC pour les connexions entrantes (max 8 caractères).
.PARAMETER AdminPassword
    Mot de passe administratif pour contrôler le serveur TightVNC.
.PARAMETER RegisterAsService
    Enregistrer TightVNC Server comme service Windows. Défaut : $true.
.PARAMETER StartAsService
    Démarrer le service immédiatement après l'installation. Défaut : $true.
.PARAMETER ServiceOnly
    Interdire le démarrage en mode application (service uniquement). Défaut : $false.
.PARAMETER LogPath
    Chemin du fichier de log d'installation. Défaut : C:\Logs\tightvnc-install.log.
.EXAMPLE
    .\Install-TightVNC.ps1 -VncPassword "P@ssVNC1" -AdminPassword "Adm1nS3c!"
.EXAMPLE
    .\Install-TightVNC.ps1 -MsiPath "D:\Outils\tightvnc-2.8.87-gpl-setup-64bit.msi" -Components Server -ServiceOnly $true
.NOTES
    Auteur  : valorisa
    Version : 1.0.0
    Projet  : tightvnc-2887-windows-guide
    Licence : MIT
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$MsiPath = "",

    [Parameter()]
    [ValidateSet("64bit", "32bit")]
    [string]$Architecture = "64bit",

    [Parameter()]
    [ValidateSet("ALL", "Server", "Viewer")]
    [string]$Components = "ALL",

    [Parameter(Mandatory)]
    [ValidateLength(1, 8)]
    [string]$VncPassword,

    [Parameter()]
    [string]$AdminPassword = "",

    [Parameter()]
    [bool]$RegisterAsService = $true,

    [Parameter()]
    [bool]$StartAsService = $true,

    [Parameter()]
    [bool]$ServiceOnly = $false,

    [Parameter()]
    [string]$LogPath = "C:\Logs\tightvnc-install.log"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Constantes ────────────────────────────────────────────────────────────────
$Version    = "2.8.87"
$DownloadUrl = "https://www.tightvnc.com/download/$Version/tightvnc-$Version-gpl-setup-$Architecture.msi"
$TempMsi    = "$env:TEMP\tightvnc-$Version-gpl-setup-$Architecture.msi"
$InstallDir  = "C:\Program Files\TightVNC"

# ── Fonctions utilitaires ─────────────────────────────────────────────────────
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
    switch ($Level) {
        "INFO"    { Write-Host $line -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $line -ForegroundColor Green }
        "WARNING" { Write-Host $line -ForegroundColor Yellow }
        "ERROR"   { Write-Host $line -ForegroundColor Red }
    }
}

function Test-TightVNCInstalled {
    return (Get-Package -Name "TightVNC*" -ErrorAction SilentlyContinue) -ne $null
}

# ── Début du script ───────────────────────────────────────────────────────────
New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force -ErrorAction SilentlyContinue | Out-Null

Write-Log "=== Début de l'installation TightVNC $Version ==="
Write-Log "Composants    : $Components"
Write-Log "Architecture  : $Architecture"
Write-Log "Mode service  : RegisterAsService=$RegisterAsService | StartAsService=$StartAsService | ServiceOnly=$ServiceOnly"

# Vérifier si déjà installé
if (Test-TightVNCInstalled) {
    Write-Log "TightVNC est déjà installé sur cette machine." "WARNING"
    $confirm = Read-Host "Voulez-vous procéder quand même à une réinstallation ? (O/N)"
    if ($confirm -notmatch "^[Oo]") {
        Write-Log "Installation annulée par l'utilisateur." "WARNING"
        exit 0
    }
}

# Résoudre le chemin du MSI
if (-not $MsiPath -or -not (Test-Path $MsiPath)) {
    Write-Log "MSI local non trouvé. Téléchargement depuis : $DownloadUrl"
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempMsi -UseBasicParsing
        $MsiPath = $TempMsi
        Write-Log "MSI téléchargé : $MsiPath" "SUCCESS"
    } catch {
        Write-Log "Échec du téléchargement : $_" "ERROR"
        exit 1
    }
} else {
    Write-Log "Utilisation du MSI local : $MsiPath"
}

# Construire les arguments msiexec
$msiArgs = [System.Collections.Generic.List[string]]@(
    "/i `"$MsiPath`"",
    "/quiet",
    "/norestart",
    "/l*v `"$LogPath`"",
    "ADDLOCAL=$Components",
    "SERVER_REGISTER_AS_SERVICE=$(if ($RegisterAsService) { 1 } else { 0 })",
    "SERVER_START_AS_SERVICE=$(if ($StartAsService) { 1 } else { 0 })",
    "SERVICEONLY=$(if ($ServiceOnly) { 1 } else { 0 })",
    "SET_USEVNCAUTHENTICATION=1",
    "VALUE_OF_USEVNCAUTHENTICATION=1",
    "SET_PASSWORD=1",
    "VALUE_OF_PASSWORD=$VncPassword"
)

if ($AdminPassword) {
    $msiArgs.Add("SET_CONTROLPASSWORD=1")
    $msiArgs.Add("VALUE_OF_CONTROLPASSWORD=$AdminPassword")
}

# Lancer l'installation
Write-Log "Lancement de msiexec..."
if ($PSCmdlet.ShouldProcess("TightVNC $Version", "Installation silencieuse")) {
    $process = Start-Process -FilePath "msiexec.exe" `
        -ArgumentList ($msiArgs -join " ") `
        -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-Log "Installation réussie (ExitCode=0)." "SUCCESS"
    } elseif ($process.ExitCode -eq 3010) {
        Write-Log "Installation réussie — redémarrage requis (ExitCode=3010)." "WARNING"
    } else {
        Write-Log "Échec de l'installation (ExitCode=$($process.ExitCode)). Consultez : $LogPath" "ERROR"
        exit $process.ExitCode
    }
}

# Nettoyer le MSI temporaire
if ($MsiPath -eq $TempMsi -and (Test-Path $TempMsi)) {
    Remove-Item $TempMsi -Force
    Write-Log "Fichier MSI temporaire supprimé."
}

# Vérification post-installation
Write-Log "Vérification post-installation..."
if (Test-Path "$InstallDir\tvnserver.exe") {
    Write-Log "tvnserver.exe présent dans $InstallDir" "SUCCESS"
}
$svc = Get-Service -Name "tvnserver" -ErrorAction SilentlyContinue
if ($svc) {
    Write-Log "Service tvnserver : $($svc.Status)" "SUCCESS"
}

Write-Log "=== Installation TightVNC $Version terminée ==="

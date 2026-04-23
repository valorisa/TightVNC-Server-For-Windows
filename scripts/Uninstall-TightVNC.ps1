#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Désinstallation propre de TightVNC (toutes versions) sur Windows.
.DESCRIPTION
    Arrête le service TightVNC, désinstalle le logiciel via msiexec,
    supprime les règles de pare-feu associées et nettoie les clés de registre
    résiduelles si demandé.
.PARAMETER Force
    Désinstalle sans demander de confirmation à l'utilisateur.
.PARAMETER CleanRegistry
    Supprime également les clés de registre TightVNC après désinstallation. Défaut : $false.
.PARAMETER CleanFirewall
    Supprime les règles de pare-feu TightVNC après désinstallation. Défaut : $true.
.PARAMETER LogPath
    Chemin du fichier de log. Défaut : C:\Logs\tightvnc-uninstall.log.
.EXAMPLE
    .\Uninstall-TightVNC.ps1 -Force -CleanRegistry $true
.EXAMPLE
    .\Uninstall-TightVNC.ps1
.NOTES
    Auteur  : valorisa
    Version : 1.0.0
    Projet  : tightvnc-2887-windows-guide
    Licence : MIT
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [bool]$CleanRegistry = $false,

    [Parameter()]
    [bool]$CleanFirewall = $true,

    [Parameter()]
    [string]$LogPath = "C:\Logs\tightvnc-uninstall.log"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

# ── Début du script ───────────────────────────────────────────────────────────
New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force -ErrorAction SilentlyContinue | Out-Null

Write-Log "=== Début de la désinstallation TightVNC ==="

# Vérifier si TightVNC est installé
$package = Get-Package -Name "TightVNC*" -ErrorAction SilentlyContinue
if (-not $package) {
    Write-Log "TightVNC n'est pas installé sur cette machine." "WARNING"
    exit 0
}

Write-Log "TightVNC détecté : $($package.Name) v$($package.Version)"

# Confirmation utilisateur
if (-not $Force) {
    $confirm = Read-Host "Êtes-vous sûr de vouloir désinstaller $($package.Name) ? (O/N)"
    if ($confirm -notmatch "^[Oo]") {
        Write-Log "Désinstallation annulée par l'utilisateur." "WARNING"
        exit 0
    }
}

# ── Étape 1 : Arrêter le service ──────────────────────────────────────────────
$svc = Get-Service -Name "tvnserver" -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Write-Log "Arrêt du service tvnserver..."
    if ($PSCmdlet.ShouldProcess("tvnserver", "Stop-Service")) {
        Stop-Service -Name "tvnserver" -Force
        Start-Sleep -Seconds 2
        Write-Log "Service arrêté." "SUCCESS"
    }
}

# Tuer les processus TightVNC résiduels
$processes = @("tvnserver", "tvnviewer", "tvncontrol")
foreach ($proc in $processes) {
    $running = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($running) {
        Write-Log "Arrêt du processus : $proc (PID $($running.Id))"
        $running | Stop-Process -Force
    }
}

# ── Étape 2 : Désinstallation via msiexec ────────────────────────────────────
Write-Log "Lancement de la désinstallation msiexec..."
$productCode = $package.FastPackageReference

if ($PSCmdlet.ShouldProcess("TightVNC", "Désinstallation msiexec")) {
    $proc = Start-Process -FilePath "msiexec.exe" `
        -ArgumentList "/x `"$productCode`" /quiet /norestart /l*v `"$LogPath`"" `
        -Wait -PassThru -NoNewWindow

    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 1605) {
        Write-Log "Désinstallation réussie." "SUCCESS"
    } else {
        Write-Log "Échec de la désinstallation (ExitCode=$($proc.ExitCode))." "ERROR"
        exit $proc.ExitCode
    }
}

# ── Étape 3 : Nettoyage du pare-feu ──────────────────────────────────────────
if ($CleanFirewall) {
    Write-Log "Suppression des règles de pare-feu TightVNC..."
    $rules = Get-NetFirewallRule -DisplayName "TightVNC*" -ErrorAction SilentlyContinue
    if ($rules) {
        $rules | Remove-NetFirewallRule
        Write-Log "$($rules.Count) règle(s) de pare-feu supprimée(s)." "SUCCESS"
    } else {
        Write-Log "Aucune règle de pare-feu TightVNC trouvée."
    }
}

# ── Étape 4 : Nettoyage du registre ──────────────────────────────────────────
if ($CleanRegistry) {
    Write-Log "Nettoyage des clés de registre TightVNC..."
    $regPaths = @(
        "HKLM:\SOFTWARE\TightVNC",
        "HKCU:\SOFTWARE\TightVNC",
        "HKLM:\SOFTWARE\WOW6432Node\TightVNC"
    )
    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            if ($PSCmdlet.ShouldProcess($path, "Remove-Item -Recurse")) {
                Remove-Item $path -Recurse -Force
                Write-Log "Supprimé : $path" "SUCCESS"
            }
        }
    }
}

# ── Étape 5 : Vérification finale ─────────────────────────────────────────────
$stillInstalled = Get-Package -Name "TightVNC*" -ErrorAction SilentlyContinue
if (-not $stillInstalled) {
    Write-Log "TightVNC correctement désinstallé." "SUCCESS"
} else {
    Write-Log "TightVNC semble encore présent dans la liste des programmes." "WARNING"
}

# Vérifier si le dossier d'installation existe encore
$installDir = "C:\Program Files\TightVNC"
if (Test-Path $installDir) {
    Write-Log "Le dossier $installDir existe encore (fichiers résiduels possibles)." "WARNING"
}

Write-Log "=== Désinstallation TightVNC terminée ==="

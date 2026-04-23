#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Modifie le mot de passe VNC et/ou le mot de passe administratif de TightVNC Server.
.DESCRIPTION
    Interagit avec tvnserver.exe via -controlservice pour changer les mots de passe
    de TightVNC Server sans avoir à relancer l'installeur.
    Le service est redémarré automatiquement pour appliquer les changements.
.PARAMETER NewVncPassword
    Nouveau mot de passe VNC pour les connexions entrantes (max 8 caractères).
    Si non fourni, une saisie sécurisée (SecureString) sera demandée.
.PARAMETER NewAdminPassword
    Nouveau mot de passe administratif pour contrôler le serveur TightVNC.
    Si non fourni, une saisie sécurisée sera demandée.
.PARAMETER ChangeVnc
    Changer le mot de passe VNC. Défaut : $true.
.PARAMETER ChangeAdmin
    Changer le mot de passe administratif. Défaut : $false.
.PARAMETER RestartService
    Redémarrer le service après le changement. Défaut : $true.
.EXAMPLE
    .\Set-TightVNCPassword.ps1 -ChangeVnc $true
.EXAMPLE
    .\Set-TightVNCPassword.ps1 -ChangeVnc $true -ChangeAdmin $true
.EXAMPLE
    .\Set-TightVNCPassword.ps1 -NewVncPassword "N3wP@ss1" -ChangeVnc $true
.NOTES
    Auteur  : valorisa
    Version : 1.0.0
    Projet  : tightvnc-2887-windows-guide
    Licence : MIT
    ⚠️ Le mot de passe VNC standard est limité à 8 caractères (protocole RFB).
       Les caractères supplémentaires sont silencieusement ignorés.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateLength(1, 8)]
    [string]$NewVncPassword = "",

    [Parameter()]
    [string]$NewAdminPassword = "",

    [Parameter()]
    [bool]$ChangeVnc   = $true,

    [Parameter()]
    [bool]$ChangeAdmin = $false,

    [Parameter()]
    [bool]$RestartService = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TvnExe  = "C:\Program Files\TightVNC\tvnserver.exe"
$LogPath = "C:\Logs\tightvnc-password.log"

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

function ConvertFrom-SecureStringPlain {
    param([System.Security.SecureString]$SecureString)
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Invoke-TvnControl {
    param([string]$Arguments)
    if (-not (Test-Path $TvnExe)) {
        throw "tvnserver.exe introuvable : $TvnExe"
    }
    $proc = Start-Process -FilePath $TvnExe `
        -ArgumentList $Arguments `
        -Wait -PassThru -NoNewWindow -WindowStyle Hidden
    return $proc.ExitCode
}

# ── Début du script ───────────────────────────────────────────────────────────
New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force -ErrorAction SilentlyContinue | Out-Null

Write-Log "=== Modification des mots de passe TightVNC ==="

# Vérifier que TightVNC est installé
if (-not (Test-Path $TvnExe)) {
    Write-Log "tvnserver.exe introuvable dans $TvnExe. TightVNC est-il installé ?" "ERROR"
    exit 1
}

# ── Changement du mot de passe VNC ───────────────────────────────────────────
if ($ChangeVnc) {
    Write-Log "Changement du mot de passe VNC en cours..."

    # Saisie sécurisée si non fourni
    if (-not $NewVncPassword) {
        $secure1 = Read-Host "Nouveau mot de passe VNC (max 8 car.)" -AsSecureString
        $secure2 = Read-Host "Confirmez le mot de passe VNC"         -AsSecureString

        $plain1 = ConvertFrom-SecureStringPlain $secure1
        $plain2 = ConvertFrom-SecureStringPlain $secure2

        if ($plain1 -ne $plain2) {
            Write-Log "Les mots de passe ne correspondent pas." "ERROR"
            exit 1
        }
        if ($plain1.Length -gt 8) {
            Write-Log "Attention : le mot de passe sera tronqué à 8 caractères (limite RFB)." "WARNING"
        }
        $NewVncPassword = $plain1.Substring(0, [Math]::Min(8, $plain1.Length))
    }

    if ($PSCmdlet.ShouldProcess("TightVNC VNC Password", "tvnserver -controlservice -setpassword")) {
        $exitCode = Invoke-TvnControl "-controlservice -setpassword `"$NewVncPassword`""
        if ($exitCode -eq 0) {
            Write-Log "Mot de passe VNC mis à jour avec succès." "SUCCESS"
        } else {
            Write-Log "Échec de la mise à jour du mot de passe VNC (ExitCode=$exitCode)." "ERROR"
            exit $exitCode
        }
    }
}

# ── Changement du mot de passe administratif ─────────────────────────────────
if ($ChangeAdmin) {
    Write-Log "Changement du mot de passe administratif en cours..."

    if (-not $NewAdminPassword) {
        $secure1 = Read-Host "Nouveau mot de passe Admin" -AsSecureString
        $secure2 = Read-Host "Confirmez le mot de passe Admin" -AsSecureString

        $plain1 = ConvertFrom-SecureStringPlain $secure1
        $plain2 = ConvertFrom-SecureStringPlain $secure2

        if ($plain1 -ne $plain2) {
            Write-Log "Les mots de passe administratifs ne correspondent pas." "ERROR"
            exit 1
        }
        $NewAdminPassword = $plain1
    }

    if ($PSCmdlet.ShouldProcess("TightVNC Admin Password", "tvnserver -controlservice -setcontrolpassword")) {
        $exitCode = Invoke-TvnControl "-controlservice -setcontrolpassword `"$NewAdminPassword`""
        if ($exitCode -eq 0) {
            Write-Log "Mot de passe administratif mis à jour avec succès." "SUCCESS"
        } else {
            Write-Log "Échec de la mise à jour du mot de passe administratif (ExitCode=$exitCode)." "ERROR"
            exit $exitCode
        }
    }
}

# ── Redémarrage du service ────────────────────────────────────────────────────
if ($RestartService) {
    $svc = Get-Service -Name "tvnserver" -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Log "Redémarrage du service tvnserver pour appliquer les changements..."
        if ($PSCmdlet.ShouldProcess("tvnserver", "Restart-Service")) {
            Restart-Service -Name "tvnserver" -Force
            Start-Sleep -Seconds 2
            $svc.Refresh()
            Write-Log "Service tvnserver : $($svc.Status)" "SUCCESS"
        }
    } else {
        Write-Log "Service tvnserver introuvable — redémarrage ignoré." "WARNING"
    }
}

Write-Log "=== Modification des mots de passe terminée ==="

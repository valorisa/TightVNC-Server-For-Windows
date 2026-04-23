#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configure TightVNC Server via les clés de registre Windows.
.DESCRIPTION
    Applique un ensemble de paramètres de configuration à TightVNC Server
    en écrivant directement dans la base de registre Windows.
    Redémarre le service après modification si demandé.
.PARAMETER RfbPort
    Port d'écoute VNC (RFB). Défaut : 5900.
.PARAMETER EnableHttpServer
    Activer le viewer HTTP intégré (port 5800). Défaut : $false.
.PARAMETER HttpPort
    Port du viewer HTTP. Défaut : 5800.
.PARAMETER RemoveWallpaper
    Masquer le fond d'écran pendant les sessions VNC. Défaut : $true.
.PARAMETER EnableFileTransfers
    Autoriser le transfert de fichiers. Défaut : $true.
.PARAMETER BlockLocalInput
    Bloquer le clavier et la souris locaux pendant une session. Défaut : $false.
.PARAMETER QueryOnConnection
    Demander une confirmation à l'utilisateur local avant d'accepter une connexion. Défaut : $false.
.PARAMETER QueryOnlyIfLoggedOn
    N'envoyer la query que si un utilisateur est connecté. Défaut : $true.
.PARAMETER EnableIpAccessControl
    Activer le filtrage par IP. Défaut : $false.
.PARAMETER AllowedIPs
    Liste des IPs/plages autorisées (ex: "192.168.1.0/24 10.0.0.1"). Utilisé si EnableIpAccessControl=$true.
.PARAMETER RestartService
    Redémarrer le service TightVNC après la configuration. Défaut : $true.
.PARAMETER ExportConfig
    Exporter la configuration finale en fichier .reg dans le dossier courant. Défaut : $false.
.EXAMPLE
    .\Configure-TightVNC.ps1 -RfbPort 5901 -RemoveWallpaper $true -BlockLocalInput $true
.EXAMPLE
    .\Configure-TightVNC.ps1 -EnableIpAccessControl $true -AllowedIPs "192.168.10.0/24" -ExportConfig $true
.NOTES
    Auteur  : valorisa
    Version : 1.0.0
    Projet  : tightvnc-2887-windows-guide
    Licence : MIT
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()] [ValidateRange(1, 65535)] [int]    $RfbPort               = 5900,
    [Parameter()] [bool]                             $EnableHttpServer       = $false,
    [Parameter()] [ValidateRange(1, 65535)] [int]    $HttpPort               = 5800,
    [Parameter()] [bool]                             $RemoveWallpaper        = $true,
    [Parameter()] [bool]                             $EnableFileTransfers    = $true,
    [Parameter()] [bool]                             $BlockLocalInput        = $false,
    [Parameter()] [bool]                             $QueryOnConnection      = $false,
    [Parameter()] [bool]                             $QueryOnlyIfLoggedOn    = $true,
    [Parameter()] [bool]                             $EnableIpAccessControl  = $false,
    [Parameter()] [string]                           $AllowedIPs             = "",
    [Parameter()] [bool]                             $RestartService         = $true,
    [Parameter()] [bool]                             $ExportConfig           = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RegPath = "HKLM:\SOFTWARE\TightVNC\Server"
$LogPath = "C:\Logs\tightvnc-config.log"

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

function Set-RegDWord {
    param([string]$Name, [int]$Value)
    if ($PSCmdlet.ShouldProcess("$RegPath\$Name", "Set DWORD = $Value")) {
        Set-ItemProperty -Path $RegPath -Name $Name -Value $Value -Type DWord
        Write-Log "  Registre : $Name = $Value"
    }
}

function Set-RegString {
    param([string]$Name, [string]$Value)
    if ($PSCmdlet.ShouldProcess("$RegPath\$Name", "Set String = '$Value'")) {
        Set-ItemProperty -Path $RegPath -Name $Name -Value $Value -Type String
        Write-Log "  Registre : $Name = '$Value'"
    }
}

# ── Début du script ───────────────────────────────────────────────────────────
New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force -ErrorAction SilentlyContinue | Out-Null

Write-Log "=== Configuration TightVNC Server ==="

# Vérifier que la clé de registre existe (TightVNC installé ?)
if (-not (Test-Path $RegPath)) {
    Write-Log "Clé de registre TightVNC introuvable : $RegPath" "ERROR"
    Write-Log "TightVNC Server est-il bien installé ?" "ERROR"
    exit 1
}

Write-Log "Clé de registre trouvée : $RegPath"
Write-Log ""

# ── Application des paramètres ────────────────────────────────────────────────

Write-Log "--- Réseau ---"
Set-RegDWord -Name "RfbPort"          -Value $RfbPort
Set-RegDWord -Name "HttpPort"         -Value $HttpPort
Set-RegDWord -Name "EnableHttpServer" -Value ([int]$EnableHttpServer)
Set-RegDWord -Name "AcceptRfbConnections" -Value 1

Write-Log "--- Affichage ---"
Set-RegDWord -Name "RemoveWallpaper"     -Value ([int]$RemoveWallpaper)
Set-RegDWord -Name "SaveBackgroundColor" -Value 0

Write-Log "--- Entrées locales ---"
Set-RegDWord -Name "BlockLocalInput"     -Value ([int]$BlockLocalInput)

Write-Log "--- Transferts de fichiers ---"
Set-RegDWord -Name "EnableFileTransfers" -Value ([int]$EnableFileTransfers)

Write-Log "--- Query utilisateur ---"
Set-RegDWord -Name "QueryOnlyIfLoggedOn" -Value ([int]$QueryOnlyIfLoggedOn)
Set-RegDWord -Name "AcceptHttpConnections" -Value 0

Write-Log "--- Sécurité : Authentification ---"
Set-RegDWord -Name "UseVncAuthentication" -Value 1

Write-Log "--- Contrôle d'accès par IP ---"
Set-RegDWord -Name "EnableIpAccessControl" -Value ([int]$EnableIpAccessControl)
if ($EnableIpAccessControl -and $AllowedIPs) {
    Set-RegString -Name "IpAccessControl" -Value $AllowedIPs
    Write-Log "  IPs autorisées : $AllowedIPs"
}

# ── Export .reg de la configuration ──────────────────────────────────────────
if ($ExportConfig) {
    $exportPath = ".\TightVNC-Config-$(Get-Date -Format 'yyyyMMdd-HHmmss').reg"
    Write-Log "Export de la configuration vers : $exportPath"
    $null = & reg.exe export "HKLM\SOFTWARE\TightVNC\Server" $exportPath /y
    Write-Log "Configuration exportée." "SUCCESS"
}

# ── Redémarrage du service ────────────────────────────────────────────────────
if ($RestartService) {
    $svc = Get-Service -Name "tvnserver" -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Log "Redémarrage du service tvnserver..."
        if ($PSCmdlet.ShouldProcess("tvnserver", "Restart-Service")) {
            Restart-Service -Name "tvnserver" -Force
            Start-Sleep -Seconds 2
            $svc.Refresh()
            Write-Log "Service tvnserver : $($svc.Status)" "SUCCESS"
        }
    } else {
        Write-Log "Service tvnserver introuvable (non installé en mode service ?)." "WARNING"
    }
}

# ── Résumé de la configuration appliquée ─────────────────────────────────────
Write-Log ""
Write-Log "=== Résumé de la configuration appliquée ==="
Write-Log "Port VNC (RFB)         : $RfbPort"
Write-Log "Viewer HTTP            : $(if ($EnableHttpServer) {'Activé (port '+$HttpPort+')'} else {'Désactivé'})"
Write-Log "Masquer fond d'écran   : $RemoveWallpaper"
Write-Log "Transfert de fichiers  : $EnableFileTransfers"
Write-Log "Bloquer entrées locales: $BlockLocalInput"
Write-Log "Query utilisateur      : $QueryOnConnection (si connecté: $QueryOnlyIfLoggedOn)"
Write-Log "Filtrage IP            : $EnableIpAccessControl$(if ($EnableIpAccessControl -and $AllowedIPs) {' => '+$AllowedIPs} else {''})"
Write-Log "=== Configuration terminée ==="

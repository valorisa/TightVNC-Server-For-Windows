#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Crée, supprime ou liste les règles de pare-feu Windows pour TightVNC.
.DESCRIPTION
    Gère les règles Windows Defender Firewall nécessaires au bon fonctionnement
    de TightVNC Server (ports 5900 TCP) et optionnellement du viewer HTTP (5800 TCP)
    et des connexions inverses (5500 TCP).
.PARAMETER Action
    Action à effectuer : 'Add' (créer les règles), 'Remove' (supprimer), 'Status' (afficher).
.PARAMETER AllowVncPort
    Autoriser le port VNC principal (5900 TCP). Défaut : $true.
.PARAMETER VncPort
    Numéro du port VNC. Défaut : 5900.
.PARAMETER AllowHttpPort
    Autoriser le port HTTP viewer (5800 TCP). Défaut : $false.
.PARAMETER AllowReversePort
    Autoriser le port de connexion inverse (5500 TCP). Défaut : $false.
.PARAMETER Profile
    Profil(s) réseau concerné(s) : 'Domain', 'Private', 'Public', ou combinaison.
    Défaut : 'Domain,Private'.
.PARAMETER RemoteAddress
    Restreindre la règle à une IP ou plage d'IPs source. Ex : '192.168.1.0/24'. Défaut : 'Any'.
.EXAMPLE
    .\Enable-Firewall.ps1 -Action Add
.EXAMPLE
    .\Enable-Firewall.ps1 -Action Add -VncPort 5901 -RemoteAddress "192.168.10.0/24" -Profile "Domain"
.EXAMPLE
    .\Enable-Firewall.ps1 -Action Remove
.EXAMPLE
    .\Enable-Firewall.ps1 -Action Status
.NOTES
    Auteur  : valorisa
    Version : 1.0.0
    Projet  : tightvnc-2887-windows-guide
    Licence : MIT
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet("Add", "Remove", "Status")]
    [string]$Action,

    [Parameter()] [bool]   $AllowVncPort     = $true,
    [Parameter()] [int]    $VncPort          = 5900,
    [Parameter()] [bool]   $AllowHttpPort    = $false,
    [Parameter()] [bool]   $AllowReversePort = $false,
    [Parameter()] [string] $Profile          = "Domain,Private",
    [Parameter()] [string] $RemoteAddress    = "Any"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Définition des règles à gérer ─────────────────────────────────────────────
$rules = @(
    @{
        DisplayName = "TightVNC Server - RFB Port $VncPort (TCP In)"
        Port        = $VncPort
        Enabled     = $AllowVncPort
        Description = "Autorise les connexions VNC entrantes (protocole RFB) sur le port $VncPort"
    },
    @{
        DisplayName = "TightVNC Server - HTTP Viewer Port 5800 (TCP In)"
        Port        = 5800
        Enabled     = $AllowHttpPort
        Description = "Autorise l'accès au viewer VNC via HTTP (port 5800) — non recommandé"
    },
    @{
        DisplayName = "TightVNC Server - Reverse Connection Port 5500 (TCP In)"
        Port        = 5500
        Enabled     = $AllowReversePort
        Description = "Autorise les connexions VNC inverses (viewer initie la connexion vers le server)"
    }
)

$tvnExe = "C:\Program Files\TightVNC\tvnserver.exe"
$profileArray = $Profile -split "," | ForEach-Object { $_.Trim() }

# ── Fonctions ─────────────────────────────────────────────────────────────────
function Write-Status {
    param([string]$Msg, [string]$Color = "Cyan")
    Write-Host $Msg -ForegroundColor $Color
}

function Add-TightVNCFirewallRules {
    Write-Status "`n[ Ajout des règles de pare-feu TightVNC ]"

    # Règle sur l'exécutable
    if (Test-Path $tvnExe) {
        $ruleName = "TightVNC Server - Application (tvnserver.exe)"
        if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
            if ($PSCmdlet.ShouldProcess($ruleName, "New-NetFirewallRule (Application)")) {
                New-NetFirewallRule `
                    -DisplayName  $ruleName `
                    -Direction    Inbound `
                    -Program      $tvnExe `
                    -Action       Allow `
                    -Profile      $profileArray `
                    -Description  "Autorise tvnserver.exe à recevoir des connexions entrantes" | Out-Null
                Write-Status "  ✓ Règle créée : $ruleName" "Green"
            }
        } else {
            Write-Status "  → Déjà existante : $ruleName" "Yellow"
        }
    } else {
        Write-Status "  ⚠ tvnserver.exe introuvable dans $tvnExe — règle application ignorée." "Yellow"
    }

    # Règles par port
    foreach ($rule in $rules) {
        if (-not $rule.Enabled) { continue }

        $existing = Get-NetFirewallRule -DisplayName $rule.DisplayName -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Status "  → Déjà existante : $($rule.DisplayName)" "Yellow"
            continue
        }

        $params = @{
            DisplayName   = $rule.DisplayName
            Direction     = "Inbound"
            Protocol      = "TCP"
            LocalPort     = $rule.Port
            Action        = "Allow"
            Profile       = $profileArray
            Description   = $rule.Description
        }
        if ($RemoteAddress -ne "Any") {
            $params["RemoteAddress"] = $RemoteAddress
        }

        if ($PSCmdlet.ShouldProcess($rule.DisplayName, "New-NetFirewallRule")) {
            New-NetFirewallRule @params | Out-Null
            Write-Status "  ✓ Règle créée : $($rule.DisplayName)" "Green"
        }
    }

    Write-Status "`nRègles de pare-feu TightVNC ajoutées." "Green"
}

function Remove-TightVNCFirewallRules {
    Write-Status "`n[ Suppression des règles de pare-feu TightVNC ]"

    $existing = Get-NetFirewallRule -DisplayName "TightVNC*" -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Status "  Aucune règle TightVNC trouvée." "Yellow"
        return
    }

    foreach ($rule in $existing) {
        if ($PSCmdlet.ShouldProcess($rule.DisplayName, "Remove-NetFirewallRule")) {
            $rule | Remove-NetFirewallRule
            Write-Status "  ✓ Supprimée : $($rule.DisplayName)" "Green"
        }
    }
    Write-Status "`nToutes les règles TightVNC ont été supprimées." "Green"
}

function Show-TightVNCFirewallStatus {
    Write-Status "`n[ État des règles de pare-feu TightVNC ]"
    $existing = Get-NetFirewallRule -DisplayName "TightVNC*" -ErrorAction SilentlyContinue

    if (-not $existing) {
        Write-Status "  Aucune règle TightVNC trouvée dans le pare-feu Windows." "Yellow"
        return
    }

    $existing | ForEach-Object {
        $portFilter = $_ | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
        $addrFilter = $_ | Get-NetFirewallAddressFilter -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            "Nom"       = $_.DisplayName
            "Activée"   = $_.Enabled
            "Direction" = $_.Direction
            "Action"    = $_.Action
            "Profil"    = $_.Profile
            "Port"      = if ($portFilter) { $portFilter.LocalPort } else { "N/A" }
            "IP Source" = if ($addrFilter) { $addrFilter.RemoteAddress } else { "Any" }
        }
    } | Format-Table -AutoSize
}

# ── Dispatcher ────────────────────────────────────────────────────────────────
switch ($Action) {
    "Add"    { Add-TightVNCFirewallRules }
    "Remove" { Remove-TightVNCFirewallRules }
    "Status" { Show-TightVNCFirewallStatus }
}

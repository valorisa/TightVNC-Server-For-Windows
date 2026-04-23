#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Déploie TightVNC 2.8.87 sur une liste de machines distantes via PowerShell Remoting (WinRM).
.DESCRIPTION
    Ce script orchestre le déploiement silencieux de TightVNC sur plusieurs machines Windows
    en parallèle via Invoke-Command (WinRM). Il transfère le MSI, installe TightVNC,
    configure les règles de pare-feu et vérifie l'état post-déploiement.
    Un rapport CSV de résultats est généré à la fin.
.PARAMETER ComputerNames
    Liste des noms/IPs de machines cibles. Peut aussi être passé via -ComputerListFile.
.PARAMETER ComputerListFile
    Chemin vers un fichier texte contenant une machine par ligne.
.PARAMETER MsiPath
    Chemin local vers le fichier MSI TightVNC (obligatoire).
.PARAMETER Credential
    Identifiants administrateur pour la connexion WinRM. Si absent, une saisie est proposée.
.PARAMETER VncPassword
    Mot de passe VNC à configurer sur les machines cibles.
.PARAMETER AdminPassword
    Mot de passe administratif TightVNC (optionnel).
.PARAMETER MaxParallel
    Nombre maximum de déploiements simultanés. Défaut : 10.
.PARAMETER ReportPath
    Chemin du rapport CSV de résultats. Défaut : C:\Logs\tightvnc-deploy-report.csv.
.EXAMPLE
    .\Deploy-TightVNC.ps1 -ComputerNames "PC-001","PC-002" -MsiPath "D:\tightvnc.msi" -VncPassword "P@ss1234"
.EXAMPLE
    .\Deploy-TightVNC.ps1 -ComputerListFile "C:\listes\machines.txt" -MsiPath "D:\tightvnc.msi" -VncPassword "P@ss1234" -MaxParallel 5
.NOTES
    Auteur  : valorisa
    Version : 1.0.0
    Projet  : tightvnc-2887-windows-guide
    Licence : MIT
    Prérequis :
      - WinRM activé sur les machines cibles (Enable-PSRemoting -Force)
      - Droits administrateur sur les machines cibles
      - Réseau : ports 5985 (WinRM HTTP) ou 5986 (WinRM HTTPS) ouverts
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(ParameterSetName = "Direct")]
    [string[]]$ComputerNames,

    [Parameter(ParameterSetName = "File")]
    [string]$ComputerListFile,

    [Parameter(Mandatory)]
    [string]$MsiPath,

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory)]
    [ValidateLength(1, 8)]
    [string]$VncPassword,

    [Parameter()]
    [string]$AdminPassword = "",

    [Parameter()]
    [ValidateRange(1, 50)]
    [int]$MaxParallel = 10,

    [Parameter()]
    [string]$ReportPath = "C:\Logs\tightvnc-deploy-report.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$LogPath = "C:\Logs\tightvnc-deploy.log"

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

# ── Validation des paramètres ─────────────────────────────────────────────────
New-Item -ItemType Directory -Path (Split-Path $LogPath)   -Force -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Path (Split-Path $ReportPath)-Force -ErrorAction SilentlyContinue | Out-Null

# Résoudre la liste de machines
if ($ComputerListFile) {
    if (-not (Test-Path $ComputerListFile)) {
        Write-Log "Fichier de liste introuvable : $ComputerListFile" "ERROR"; exit 1
    }
    $ComputerNames = Get-Content $ComputerListFile | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() }
}

if (-not $ComputerNames -or $ComputerNames.Count -eq 0) {
    Write-Log "Aucune machine cible spécifiée." "ERROR"; exit 1
}

# Vérifier le MSI
if (-not (Test-Path $MsiPath)) {
    Write-Log "Fichier MSI introuvable : $MsiPath" "ERROR"; exit 1
}

# Identifiants
if (-not $Credential) {
    $Credential = Get-Credential -Message "Identifiants administrateur pour le déploiement WinRM"
}

# ── Lecture du MSI en mémoire (pour transfert) ────────────────────────────────
Write-Log "Lecture du MSI : $MsiPath ($([math]::Round((Get-Item $MsiPath).Length/1MB,2)) Mo)..."
$msiBytes  = [IO.File]::ReadAllBytes($MsiPath)
$msiBase64 = [Convert]::ToBase64String($msiBytes)
Write-Log "MSI encodé en Base64."

# ── Début du déploiement ──────────────────────────────────────────────────────
Write-Log "=== Début du déploiement TightVNC 2.8.87 ==="
Write-Log "Machines cibles  : $($ComputerNames.Count)"
Write-Log "Parallélisme max : $MaxParallel"

$results = [System.Collections.Concurrent.ConcurrentBag[PSCustomObject]]::new()

# ScriptBlock exécuté sur chaque machine distante
$remoteBlock = {
    param($MsiBase64, $VncPwd, $AdminPwd)

    $result = @{
        Computer = $env:COMPUTERNAME
        Status   = "INCONNU"
        Details  = ""
        Time     = (Get-Date -Format "HH:mm:ss")
    }

    try {
        # Écrire le MSI temporairement
        $msiPath = "$env:TEMP\tightvnc-deploy.msi"
        [IO.File]::WriteAllBytes($msiPath, [Convert]::FromBase64String($MsiBase64))

        # Construire les arguments msiexec
        $args = @(
            "/i `"$msiPath`"",
            "/quiet /norestart",
            "ADDLOCAL=Server",
            "SERVER_REGISTER_AS_SERVICE=1",
            "SERVER_START_AS_SERVICE=1",
            "SERVICEONLY=1",
            "SET_USEVNCAUTHENTICATION=1 VALUE_OF_USEVNCAUTHENTICATION=1",
            "SET_PASSWORD=1 VALUE_OF_PASSWORD=$VncPwd"
        )
        if ($AdminPwd) { $args += "SET_CONTROLPASSWORD=1 VALUE_OF_CONTROLPASSWORD=$AdminPwd" }

        $proc = Start-Process msiexec.exe -ArgumentList ($args -join " ") -Wait -PassThru -NoNewWindow

        if ($proc.ExitCode -in @(0, 3010)) {
            # Ajouter règle pare-feu
            New-NetFirewallRule `
                -DisplayName "TightVNC Server - RFB 5900 (Deploy)" `
                -Direction Inbound -Protocol TCP -LocalPort 5900 `
                -Action Allow -Profile Domain,Private `
                -ErrorAction SilentlyContinue | Out-Null

            $svc = Get-Service tvnserver -ErrorAction SilentlyContinue
            $result.Status  = "SUCCESS"
            $result.Details = "Service: $($svc.Status) | ExitCode: $($proc.ExitCode)"
        } else {
            $result.Status  = "ECHEC"
            $result.Details = "ExitCode msiexec: $($proc.ExitCode)"
        }

        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
    } catch {
        $result.Status  = "ERREUR"
        $result.Details = $_.Exception.Message
    }

    return [PSCustomObject]$result
}

# ── Exécution parallèle par lots ──────────────────────────────────────────────
$batches = [System.Collections.Generic.List[string[]]]::new()
for ($i = 0; $i -lt $ComputerNames.Count; $i += $MaxParallel) {
    $batches.Add($ComputerNames[$i..[Math]::Min($i + $MaxParallel - 1, $ComputerNames.Count - 1)])
}

$batchNum = 0
foreach ($batch in $batches) {
    $batchNum++
    Write-Log "Traitement du lot $batchNum/$($batches.Count) : $($batch -join ', ')"

    $jobs = Invoke-Command `
        -ComputerName $batch `
        -Credential   $Credential `
        -ScriptBlock  $remoteBlock `
        -ArgumentList $msiBase64, $VncPassword, $AdminPassword `
        -AsJob

    $jobResults = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    foreach ($r in $jobResults) {
        $results.Add($r)
        $color = switch ($r.Status) { "SUCCESS" { "Green" } "ECHEC" { "Red" } default { "Yellow" } }
        Write-Log "  [$($r.Status)] $($r.Computer) — $($r.Details)" (if ($r.Status -eq "SUCCESS") { "SUCCESS" } else { "ERROR" })
    }
}

# ── Rapport CSV ───────────────────────────────────────────────────────────────
$results | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
Write-Log "Rapport exporté : $ReportPath" "SUCCESS"

# ── Résumé final ──────────────────────────────────────────────────────────────
$success = ($results | Where-Object { $_.Status -eq "SUCCESS" }).Count
$failed  = ($results | Where-Object { $_.Status -ne "SUCCESS" }).Count

Write-Log "=== Résumé du déploiement ==="
Write-Log "Total    : $($ComputerNames.Count) machines"
Write-Log "Succès   : $success" "SUCCESS"
if ($failed -gt 0) {
    Write-Log "Échecs   : $failed" "ERROR"
}
Write-Log "Rapport  : $ReportPath"
Write-Log "=== Déploiement terminé ==="

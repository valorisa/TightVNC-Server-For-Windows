#Requires -Version 5.1
<#
.SYNOPSIS
    Teste la connectivité réseau VNC (TCP) vers une ou plusieurs machines distantes.
.DESCRIPTION
    Vérifie si le port VNC (défaut 5900) est accessible en TCP sur une liste de machines.
    Affiche le résultat avec la latence de connexion et génère un rapport si demandé.
    Peut aussi tester la bannière RFB (protocole VNC) pour valider que c'est bien
    un serveur VNC qui répond.
.PARAMETER Targets
    Liste des noms d'hôtes ou adresses IP à tester.
.PARAMETER TargetFile
    Chemin d'un fichier texte contenant une cible par ligne.
.PARAMETER Port
    Port TCP à tester. Défaut : 5900.
.PARAMETER TimeoutMs
    Délai d'attente de connexion en millisecondes. Défaut : 2000.
.PARAMETER CheckBanner
    Tenter de lire la bannière RFB pour confirmer que c'est un serveur VNC. Défaut : $true.
.PARAMETER ExportCsv
    Exporter les résultats en CSV. Défaut : $false.
.PARAMETER CsvPath
    Chemin du fichier CSV de résultats. Défaut : C:\Logs\tightvnc-port-test.csv.
.EXAMPLE
    .\Test-TightVNCPort.ps1 -Targets "192.168.1.10", "PC-SERVEUR-01"
.EXAMPLE
    .\Test-TightVNCPort.ps1 -TargetFile "C:\machines.txt" -Port 5901 -ExportCsv $true
.EXAMPLE
    .\Test-TightVNCPort.ps1 -Targets "10.0.0.5" -CheckBanner $true
.NOTES
    Auteur  : valorisa
    Version : 1.0.0
    Projet  : tightvnc-2887-windows-guide
    Licence : MIT
#>

[CmdletBinding()]
param(
    [Parameter(ParameterSetName = "Direct")]
    [string[]]$Targets,

    [Parameter(ParameterSetName = "File")]
    [string]$TargetFile,

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$Port = 5900,

    [Parameter()]
    [ValidateRange(100, 30000)]
    [int]$TimeoutMs = 2000,

    [Parameter()]
    [bool]$CheckBanner = $true,

    [Parameter()]
    [bool]$ExportCsv = $false,

    [Parameter()]
    [string]$CsvPath = "C:\Logs\tightvnc-port-test.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

# ── Résoudre la liste de cibles ───────────────────────────────────────────────
if ($TargetFile) {
    if (-not (Test-Path $TargetFile)) {
        Write-Error "Fichier introuvable : $TargetFile"; exit 1
    }
    $Targets = Get-Content $TargetFile | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() }
}

if (-not $Targets -or $Targets.Count -eq 0) {
    Write-Error "Aucune cible spécifiée."; exit 1
}

# ── Fonction : tester un port TCP ─────────────────────────────────────────────
function Test-TcpPort {
    param([string]$Host, [int]$Port, [int]$TimeoutMs)

    $result = [PSCustomObject]@{
        Host      = $Host
        Port      = $Port
        Status    = "INCONNU"
        LatencyMs = -1
        Banner    = ""
        RFBVersion = ""
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $sw  = [System.Diagnostics.Stopwatch]::StartNew()
        $ar  = $tcp.BeginConnect($Host, $Port, $null, $null)
        $ok  = $ar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        $sw.Stop()

        if ($ok -and $tcp.Connected) {
            $tcp.EndConnect($ar)
            $result.Status    = "OUVERT"
            $result.LatencyMs = $sw.ElapsedMilliseconds

            # Tenter de lire la bannière RFB
            if ($CheckBanner) {
                try {
                    $stream = $tcp.GetStream()
                    $stream.ReadTimeout = 1500
                    $buffer = New-Object byte[] 12
                    $read   = $stream.Read($buffer, 0, 12)
                    if ($read -gt 0) {
                        $banner = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $read).Trim("`0", "`n", "`r")
                        $result.Banner = $banner
                        # Format attendu : "RFB 003.008" ou similaire
                        if ($banner -match "^RFB\s+(\d+\.\d+)") {
                            $result.RFBVersion = $Matches[1]
                            $result.Status = "VNC OK (RFB $($Matches[1]))"
                        }
                    }
                    $stream.Close()
                } catch {
                    $result.Banner = "(bannière non lisible)"
                }
            }
        } else {
            $result.Status = "FERMÉ/TIMEOUT"
        }

        $tcp.Close()
    } catch {
        $result.Status = "ERREUR: $($_.Exception.Message -replace '\n','' | Select-Object -First 80)"
    }

    return $result
}

# ── Exécution des tests ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        TightVNC — Test de connectivité réseau           ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "  Port testé  : $Port/TCP"
Write-Host "  Timeout     : $TimeoutMs ms"
Write-Host "  Cibles      : $($Targets.Count) machine(s)"
Write-Host "  Vérif. RFB  : $CheckBanner"
Write-Host ""

$allResults = foreach ($target in $Targets) {
    Write-Host "  ⟳ Test $target`:$Port ... " -NoNewline

    $r = Test-TcpPort -Host $target -Port $Port -TimeoutMs $TimeoutMs

    $color = switch -Wildcard ($r.Status) {
        "VNC OK*"       { "Green" }
        "OUVERT"        { "Green" }
        "FERMÉ*"        { "Red" }
        "TIMEOUT*"      { "Yellow" }
        default         { "Red" }
    }

    $icon = if ($r.Status -match "^(VNC OK|OUVERT)") { "✓" } else { "✗" }
    Write-Host "$icon $($r.Status)" -ForegroundColor $color

    if ($r.LatencyMs -ge 0) {
        Write-Host "    Latence : $($r.LatencyMs) ms" -ForegroundColor Gray
    }
    if ($r.Banner) {
        Write-Host "    Bannière: $($r.Banner)" -ForegroundColor Gray
    }

    $r
}

# ── Tableau récapitulatif ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════ RÉSUMÉ ═══════════════════════════════════════════" -ForegroundColor DarkGray
$allResults | Select-Object Host, Port, Status, LatencyMs, RFBVersion | Format-Table -AutoSize

# ── Statistiques ─────────────────────────────────────────────────────────────
$open   = ($allResults | Where-Object { $_.Status -match "^(VNC OK|OUVERT)" }).Count
$closed = $allResults.Count - $open

Write-Host "  Accessibles : $open/$($allResults.Count)" -ForegroundColor $(if ($closed -eq 0) {"Green"} else {"Yellow"})
if ($closed -gt 0) {
    Write-Host "  Inaccessibles : $closed" -ForegroundColor Red
    $allResults | Where-Object { $_.Status -notmatch "^(VNC OK|OUVERT)" } |
        ForEach-Object { Write-Host "    ✗ $($_.Host) — $($_.Status)" -ForegroundColor Red }
}
Write-Host ""

# ── Export CSV ────────────────────────────────────────────────────────────────
if ($ExportCsv) {
    New-Item -ItemType Directory -Path (Split-Path $CsvPath) -Force -ErrorAction SilentlyContinue | Out-Null
    $allResults | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "  Résultats exportés : $CsvPath" -ForegroundColor Green
}

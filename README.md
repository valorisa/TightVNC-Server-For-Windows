# 🖥️ TightVNC 2.8.87 — Guide Complet Windows 11 Enterprise

<div align="center">

![TightVNC](https://img.shields.io/badge/TightVNC-2.8.87-blue?style=for-the-badge&logo=windows)
![Windows](https://img.shields.io/badge/Windows_11-Enterprise-0078D4?style=for-the-badge&logo=windows11)
![PowerShell](https://img.shields.io/badge/PowerShell-7.6.1-5391FE?style=for-the-badge&logo=powershell)
![License](https://img.shields.io/badge/License-GPL--2.0-green?style=for-the-badge)
![Maintained](https://img.shields.io/badge/Maintained-Yes-brightgreen?style=for-the-badge)

**Documentation, scripts PowerShell et bonnes pratiques pour déployer, configurer et sécuriser TightVNC 2.8.87 sous Windows 11 Enterprise.**

[📥 Télécharger TightVNC](#-téléchargement) •
[🚀 Installation rapide](#-installation-rapide) •
[⚙️ Configuration](#️-configuration-avancée) •
[🔐 Sécurité](#-sécurité-et-hardening) •
[🤖 Automatisation](#-scripts-powershell) •
[📚 FAQ](#-faq)

</div>

---

## 📋 Table des matières

- [À propos du projet](#-à-propos-du-projet)
- [À propos de TightVNC 2.8.87](#-à-propos-de-tightvnc-2887)
- [Prérequis](#-prérequis)
- [Téléchargement](#-téléchargement)
- [Installation rapide](#-installation-rapide)
- [Installation silencieuse (MSI)](#-installation-silencieuse-msi)
- [Configuration avancée](#️-configuration-avancée)
  - [Fichier de configuration INI](#fichier-de-configuration-ini)
  - [Registre Windows](#registre-windows)
  - [Gestion du service Windows](#gestion-du-service-windows)
  - [Pare-feu Windows](#pare-feu-windows)
- [Sécurité et Hardening](#-sécurité-et-hardening)
  - [Mots de passe](#mots-de-passe)
  - [Protection brute-force](#protection-brute-force)
  - [Restriction par IP](#restriction-par-ip)
  - [Tunneling SSH](#tunneling-ssh)
- [Scripts PowerShell](#-scripts-powershell)
- [Déploiement en masse](#-déploiement-en-masse)
- [Ports réseau](#-ports-réseau)
- [Différences Server / Viewer](#-différences-server--viewer)
- [Nouveautés de la version 2.8.87](#-nouveautés-de-la-version-2887)
- [Historique des versions récentes](#-historique-des-versions-récentes)
- [FAQ](#-faq)
- [Contribuer](#-contribuer)
- [Licence](#-licence)
- [Références](#-références)

---

## 🎯 À propos du projet

Ce dépôt est un **guide de référence exhaustif** pour l'installation, la configuration, la sécurisation et l'automatisation de **TightVNC 2.8.87** sous **Windows 11 Enterprise**, piloté depuis **PowerShell 7.6.1**.

Il s'adresse aussi bien aux administrateurs systèmes souhaitant déployer TightVNC sur un parc de machines, qu'aux utilisateurs avancés cherchant à maîtriser chaque paramètre de l'outil.

### Ce que vous trouverez ici

- 📄 Documentation complète et commentée
- 🤖 Scripts PowerShell prêts à l'emploi (installation, configuration, supervision)
- 🔐 Recommandations de sécurité et hardening
- 🏭 Procédures de déploiement en masse (GPO, WinRM, Intune)
- 🧪 Tests automatisés avec Pester
- 🐛 Cas d'usage courants et résolution de problèmes

### Environnement de développement

| Composant | Version / Détail |
|-----------|-----------------|
| OS | Windows 11 Enterprise |
| Shell | PowerShell 7.6.1 |
| Logiciel cible | TightVNC 2.8.87 |
| Espace de travail | `C:\Users\bbrod\Projets\TightVNC-Server-For-Windows` |
| GitHub CLI | `gh` (dernière version stable) |

---

## 🔎 À propos de TightVNC 2.8.87

**TightVNC** (Tight Virtual Network Computing) est un logiciel de **bureau à distance libre et gratuit**, développé par [GlavSoft LLC](https://glavsoft.com/). Il est basé sur le protocole **RFB (Remote Frame Buffer)** et est compatible avec tous les clients VNC standards.

### Caractéristiques principales

- **Protocole** : RFB (Remote Frame Buffer) v3.8+ avec extensions propriétaires TightVNC
- **Licence** : GNU GPL v2 (version gratuite) ou licence commerciale
- **Architecture** : Client/Serveur — le *Server* expose le bureau, le *Viewer* s'y connecte
- **Encodages supportés** : Tight, ZRLE, Hextile, CopyRect, RRE, Raw
- **Compression** : zlib 1.2.13, libjpeg (dernières versions depuis la 2.8.75)
- **Chiffrement** : Aucun natif en clair — tunneling SSH ou VPN recommandé (voir [Sécurité](#-sécurité-et-hardening))
- **Authentification** : VNC Password (challenge-response), Windows Authentication (versions commerciales)
- **Transfert de fichiers** : Intégré entre Client et Serveur TightVNC
- **Presse-papiers** : Synchronisation bidirectionnelle, support Unicode/UTF-8 (depuis 2.8.53)
- **Multi-moniteurs** : Support via `DesktopConfiguration` pseudo-encoding (depuis 2.8.81)
- **Mode service** : Fonctionne en tant que service Windows (démarrage automatique, sans session utilisateur)
- **Mode application** : Fonctionne comme une application ordinaire dans la session utilisateur
- **Compatibilité OS** : Windows XP et toutes les versions ultérieures (32 et 64 bits)
- **Résolution max** : 65 535 × 65 535 pixels (augmenté dans la v2.8.87, était 32 000)

### Composants fournis par l'installeur

| Composant | Exécutable | Rôle |
|-----------|-----------|------|
| TightVNC Server | `tvnserver.exe` | Expose le bureau à distance |
| TightVNC Viewer | `tvnviewer.exe` | Se connecte à un bureau distant |
| Service Control App | `tvncontrol.exe` | Gestion du service depuis la barre des tâches |

---

## ✅ Prérequis

Avant de commencer, assurez-vous de disposer des éléments suivants :

### Système

- Windows 11 Enterprise (64 bits recommandé)
- PowerShell 7.6.1 ou supérieur ([installer via winget](#installation-de-powershell-761))
- Droits d'administrateur local (pour l'installation du service)
- Connexion Internet (pour le téléchargement du MSI)

### Réseau

- Port **5900/TCP** ouvert sur le pare-feu hôte (VNC Server)
- Port **5800/TCP** si vous utilisez le Viewer HTTP intégré (optionnel)
- Port **5900/TCP** accessible depuis le poste client (VNC Viewer)

### Optionnel (pour le déploiement en masse)

- Windows Remote Management (WinRM) activé sur les machines cibles
- GitHub CLI (`gh`) installé : `winget install --id GitHub.cli`
- Git installé : `winget install --id Git.Git`

### Installation de PowerShell 7.6.1

```powershell
# Via winget (recommandé)
winget install --id Microsoft.PowerShell --source winget

# Vérifier la version installée
$PSVersionTable.PSVersion
```

---

## 📥 Téléchargement

Les installeurs officiels TightVNC 2.8.87 sont disponibles sur le site officiel :

| Plateforme | Lien | Taille |
|------------|------|--------|
| Windows 64 bits (MSI) | [tightvnc-2.8.87-gpl-setup-64bit.msi](https://www.tightvnc.com/download/2.8.87/tightvnc-2.8.87-gpl-setup-64bit.msi) | ~2,5 Mo |
| Windows 32 bits (MSI) | [tightvnc-2.8.87-gpl-setup-32bit.msi](https://www.tightvnc.com/download/2.8.87/tightvnc-2.8.87-gpl-setup-32bit.msi) | ~2,1 Mo |
| Code source GPL (C++) | [tightvnc-2.8.87-src-gpl.zip](https://www.tightvnc.com/download/2.8.87/tightvnc-2.8.87-src-gpl.zip) | ~2,9 Mo |

### Téléchargement depuis PowerShell

```powershell
# Définir les variables
$version    = "2.8.87"
$arch       = "64bit"   # ou "32bit"
$fileName   = "tightvnc-$version-gpl-setup-$arch.msi"
$downloadUrl = "https://www.tightvnc.com/download/$version/$fileName"
$destPath   = "$env:USERPROFILE\Downloads\$fileName"

# Télécharger le fichier
Invoke-WebRequest -Uri $downloadUrl -OutFile $destPath -UseBasicParsing
Write-Host "Téléchargé : $destPath" -ForegroundColor Green

# Vérifier la taille du fichier
$fileSize = (Get-Item $destPath).Length
Write-Host "Taille : $([math]::Round($fileSize / 1MB, 2)) Mo"
```

---

## 🚀 Installation rapide

### Installation interactive (interface graphique)

Double-cliquez sur le fichier `.msi` téléchargé et suivez l'assistant d'installation.

**Étapes de l'assistant :**
1. Accepter la licence GPL v2
2. Choisir le type d'installation : *Typical* (Server + Viewer) ou *Custom*
3. Définir le mot de passe VNC (accès distant) — **obligatoire**
4. Définir le mot de passe administratif (contrôle du serveur) — *optionnel mais recommandé*
5. Choisir si TightVNC Server démarre comme service Windows
6. Finaliser l'installation

### Vérification de l'installation

```powershell
# Vérifier que le service est installé
Get-Service -Name "tvnserver" | Select-Object Name, Status, StartType

# Vérifier que les exécutables sont présents
$tvnPath = "C:\Program Files\TightVNC"
Get-ChildItem $tvnPath -Filter "*.exe" | Select-Object Name, Length, LastWriteTime

# Vérifier le port d'écoute
netstat -ano | Select-String ":5900"
```

---

## 🔇 Installation silencieuse (MSI)

L'installation silencieuse est idéale pour les déploiements automatisés ou via scripts.

### Paramètres MSI principaux

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|------------------|
| `ADDLOCAL=Server` | Installer uniquement le Server | — |
| `ADDLOCAL=Viewer` | Installer uniquement le Viewer | — |
| `ADDLOCAL=ALL` | Installer Server + Viewer | ALL |
| `SERVER_REGISTER_AS_SERVICE=1` | Enregistrer comme service Windows | 1 |
| `SERVER_START_AS_SERVICE=1` | Démarrer le service après install | 1 |
| `SET_USEVNCAUTHENTICATION=1` | Activer l'authentification VNC | 1 |
| `VALUE_OF_USEVNCAUTHENTICATION=1` | Forcer l'auth VNC | 1 |
| `SET_PASSWORD=1` | Définir un mot de passe VNC | — |
| `VALUE_OF_PASSWORD=VotreMotDePasse` | Valeur du mot de passe VNC | — |
| `SET_CONTROLPASSWORD=1` | Définir un mot de passe admin | — |
| `VALUE_OF_CONTROLPASSWORD=AdminPass` | Valeur du mot de passe admin | — |
| `SERVICEONLY=1` | Interdire le mode application | 0 |

### Commandes d'installation silencieuse

```powershell
# Installation complète (Server + Viewer) en mode silencieux
$msiPath = "$env:USERPROFILE\Downloads\tightvnc-2.8.87-gpl-setup-64bit.msi"
$logPath = "C:\Logs\tightvnc-install.log"

# Créer le dossier de logs si nécessaire
New-Item -ItemType Directory -Path "C:\Logs" -Force | Out-Null

# Installation silencieuse avec mots de passe
$arguments = @(
    "/i `"$msiPath`"",
    "/quiet",
    "/norestart",
    "/l*v `"$logPath`"",
    "ADDLOCAL=ALL",
    "SERVER_REGISTER_AS_SERVICE=1",
    "SERVER_START_AS_SERVICE=1",
    "SET_USEVNCAUTHENTICATION=1",
    "VALUE_OF_USEVNCAUTHENTICATION=1",
    "SET_PASSWORD=1",
    "VALUE_OF_PASSWORD=P@ssw0rdVNC!",
    "SET_CONTROLPASSWORD=1",
    "VALUE_OF_CONTROLPASSWORD=Adm1nS3cur3!"
)

Start-Process -FilePath "msiexec.exe" -ArgumentList ($arguments -join " ") -Wait -NoNewWindow
Write-Host "Installation terminée. Log : $logPath" -ForegroundColor Green
```

```powershell
# Installation Server uniquement (sans Viewer) — idéal pour les serveurs
$arguments = @(
    "/i `"$msiPath`"",
    "/quiet",
    "/norestart",
    "ADDLOCAL=Server",
    "SERVER_REGISTER_AS_SERVICE=1",
    "SERVER_START_AS_SERVICE=1",
    "SERVICEONLY=1",
    "SET_USEVNCAUTHENTICATION=1",
    "VALUE_OF_USEVNCAUTHENTICATION=1",
    "SET_PASSWORD=1",
    "VALUE_OF_PASSWORD=P@ssw0rdVNC!"
)

Start-Process -FilePath "msiexec.exe" -ArgumentList ($arguments -join " ") -Wait -NoNewWindow
```

### Désinstallation silencieuse

```powershell
# Récupérer le ProductCode depuis le registre
$productCode = (Get-Package -Name "TightVNC*" -ErrorAction SilentlyContinue).FastPackageReference

if ($productCode) {
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/x `"$productCode`" /quiet /norestart" -Wait -NoNewWindow
    Write-Host "TightVNC désinstallé avec succès." -ForegroundColor Green
} else {
    # Méthode alternative via le GUID connu
    $guid = "{8B8B3259-55C5-4B5C-8E38-7A3B839E6FD6}" # exemple — vérifier dans Ajout/Suppression de programmes
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/x `"$guid`" /quiet /norestart" -Wait -NoNewWindow
}
```

---

## ⚙️ Configuration avancée

### Fichier de configuration INI

TightVNC stocke sa configuration dans le **Registre Windows** (voir ci-dessous), mais on peut exporter/importer une configuration via des fichiers `.reg`.

### Registre Windows

Toutes les clés de configuration de TightVNC Server se trouvent dans :

```
HKEY_LOCAL_MACHINE\SOFTWARE\TightVNC\Server
```

Pour la configuration par utilisateur :

```
HKEY_CURRENT_USER\SOFTWARE\TightVNC\Server
```

#### Lire la configuration actuelle

```powershell
# Lire toutes les valeurs du Server
Get-ItemProperty -Path "HKLM:\SOFTWARE\TightVNC\Server"

# Lire une valeur spécifique
Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\TightVNC\Server" -Name "RfbPort"
```

#### Modifier des paramètres par registre

```powershell
$regPath = "HKLM:\SOFTWARE\TightVNC\Server"

# Changer le port VNC (défaut : 5900)
Set-ItemProperty -Path $regPath -Name "RfbPort" -Value 5901 -Type DWord

# Désactiver le Viewer HTTP (port 5800)
Set-ItemProperty -Path $regPath -Name "HttpPort" -Value 5800 -Type DWord
Set-ItemProperty -Path $regPath -Name "EnableHttpServer" -Value 0 -Type DWord

# Activer le query sur connexion (demander autorisation à l'utilisateur local)
Set-ItemProperty -Path $regPath -Name "QueryOnlyIfLoggedOn" -Value 1 -Type DWord
Set-ItemProperty -Path $regPath -Name "AcceptRfbConnections" -Value 1 -Type DWord

# Masquer le papier peint pendant les sessions VNC
Set-ItemProperty -Path $regPath -Name "RemoveWallpaper" -Value 1 -Type DWord

# Désactiver le transfert de fichiers
Set-ItemProperty -Path $regPath -Name "EnableFileTransfers" -Value 0 -Type DWord

# Bloquer les entrées locales pendant une session VNC
Set-ItemProperty -Path $regPath -Name "BlockLocalInput" -Value 1 -Type DWord
```

#### Paramètres de registre clés

| Clé | Type | Description | Valeur par défaut |
|-----|------|-------------|------------------|
| `RfbPort` | DWORD | Port d'écoute VNC | 5900 |
| `HttpPort` | DWORD | Port du viewer HTTP | 5800 |
| `EnableHttpServer` | DWORD | Activer le viewer HTTP | 0 |
| `AcceptRfbConnections` | DWORD | Accepter les connexions VNC | 1 |
| `UseVncAuthentication` | DWORD | Activer l'auth VNC | 1 |
| `RemoveWallpaper` | DWORD | Masquer le fond d'écran | 0 |
| `EnableFileTransfers` | DWORD | Autoriser le transfert de fichiers | 1 |
| `BlockLocalInput` | DWORD | Bloquer clavier/souris local | 0 |
| `QueryOnlyIfLoggedOn` | DWORD | Query seulement si un user est connecté | 1 |
| `MaxRects` | DWORD | Nombre max de rectangles par update | 50 |
| `VideoRecognitionInterval` | DWORD | Intervalle de détection vidéo (ms) | 3000 |

### Gestion du service Windows

```powershell
# --- Contrôle du service TightVNC ---

# Démarrer le service
Start-Service -Name "tvnserver"

# Arrêter le service
Stop-Service -Name "tvnserver"

# Redémarrer le service (après modification de config)
Restart-Service -Name "tvnserver"

# Vérifier le statut
Get-Service -Name "tvnserver" | Format-List Name, Status, StartType, DisplayName

# Définir le démarrage automatique
Set-Service -Name "tvnserver" -StartupType Automatic

# Installer le service manuellement (si nécessaire)
& "C:\Program Files\TightVNC\tvnserver.exe" -install -silent

# Désinstaller le service
& "C:\Program Files\TightVNC\tvnserver.exe" -remove -silent

# Démarrer en mode application (sans service, dans la session utilisateur)
& "C:\Program Files\TightVNC\tvnserver.exe" -run
```

### Pare-feu Windows

```powershell
# --- Règles de pare-feu pour TightVNC ---

# Autoriser le port VNC entrant (5900/TCP)
New-NetFirewallRule `
    -DisplayName "TightVNC Server - RFB (5900)" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 5900 `
    -Action Allow `
    -Profile Domain,Private `
    -Description "Autorise les connexions VNC entrantes sur le port 5900"

# Autoriser l'exécutable TightVNC Server
New-NetFirewallRule `
    -DisplayName "TightVNC Server Application" `
    -Direction Inbound `
    -Program "C:\Program Files\TightVNC\tvnserver.exe" `
    -Action Allow `
    -Profile Domain,Private

# Vérifier les règles créées
Get-NetFirewallRule -DisplayName "TightVNC*" | Select-Object DisplayName, Enabled, Direction, Action

# Supprimer les règles TightVNC (nettoyage)
Remove-NetFirewallRule -DisplayName "TightVNC*"
```

---

## 🔐 Sécurité et Hardening

> ⚠️ **Avertissement :** VNC ne chiffre pas les communications par défaut. En dehors d'un réseau local de confiance, utilisez **impérativement** un tunnel SSH ou un VPN.

### Mots de passe

TightVNC utilise un mot de passe **DES** (8 caractères max pour le mot de passe VNC standard). Depuis la version 2.8.53, TightVNC supporte également les extensions de protocole propriétaires.

```powershell
# Définir le mot de passe VNC via ligne de commande
# Note : cette commande affiche brièvement le mot de passe — à utiliser avec précaution
$tvn = "C:\Program Files\TightVNC\tvnserver.exe"
& $tvn -controlservice -setpassword "NouveauP@ss"

# Via le registre (le mot de passe est stocké encodé, pas en clair)
# Il est préférable d'utiliser l'interface graphique ou tvnserver.exe -controlservice
```

### Protection brute-force

Depuis la version 2.8.53, TightVNC implémente un algorithme progressif de protection contre les attaques par force brute :

| Tentatives échouées | Délai appliqué |
|--------------------|----------------|
| 1 à 2 | Aucun délai |
| 3 à 8 | 1 seconde de délai |
| 9 à 14 | 1 minute de délai |
| 15+ | 1 heure de délai |

Cela limite à **38 tentatives maximum par IP en 24 heures**.

### Restriction par IP

```powershell
# Configurer les IPs autorisées via le registre
$regPath = "HKLM:\SOFTWARE\TightVNC\Server"

# N'accepter que certaines IPs (liste d'IPs séparées par des virgules ou espaces)
Set-ItemProperty -Path $regPath -Name "IpAccessControl" -Value "192.168.1.0/24 10.0.0.1" -Type String

# Activer le contrôle d'accès par IP
Set-ItemProperty -Path $regPath -Name "EnableIpAccessControl" -Value 1 -Type DWord
```

### Tunneling SSH

Windows 11 intègre nativement **OpenSSH**. Utilisez-le pour chiffrer vos sessions VNC.

```powershell
# --- Côté Viewer (machine cliente) ---

# Créer un tunnel SSH : le port local 5901 redirige vers le port 5900 de la machine distante
# La connexion VNC doit se faire sur localhost:5901
ssh -L 5901:localhost:5900 -N utilisateur@IP_SERVEUR_VNC

# Puis connectez tvnviewer.exe à : localhost::5901
```

```powershell
# --- Activer OpenSSH Server sur la machine hôte VNC ---

# Installer OpenSSH Server (si pas déjà présent)
Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0"

# Démarrer et activer OpenSSH Server
Start-Service -Name sshd
Set-Service -Name sshd -StartupType Automatic

# Ouvrir le port SSH dans le pare-feu (normalement déjà créé automatiquement)
New-NetFirewallRule -DisplayName "SSH Server" -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow
```

### Bonnes pratiques de sécurité récapitulées

```
✅ Utiliser un mot de passe VNC fort (min. 8 caractères complexes)
✅ Définir un mot de passe administratif différent du mot de passe VNC
✅ Tunneliser via SSH ou VPN en dehors du LAN
✅ Restreindre l'accès par IP (IpAccessControl)
✅ Désactiver le Viewer HTTP intégré (EnableHttpServer=0)
✅ Activer le Query utilisateur (demander confirmation à l'écran local)
✅ Désactiver le transfert de fichiers si non nécessaire
✅ Mettre à jour vers la dernière version de TightVNC
✅ Surveiller les logs Windows Event Viewer (Application)
❌ NE JAMAIS exposer le port 5900 directement sur Internet
❌ NE JAMAIS utiliser de mot de passe trivial ou vide
```

---

## 🤖 Scripts PowerShell

Ce dépôt contient plusieurs scripts PowerShell dans le dossier `scripts/` :

### Structure du dossier `scripts/`

```
scripts/
├── Install-TightVNC.ps1        # Installation silencieuse complète
├── Uninstall-TightVNC.ps1      # Désinstallation propre
├── Configure-TightVNC.ps1      # Configuration via registre
├── Enable-Firewall.ps1         # Règles de pare-feu
├── Get-TightVNCStatus.ps1      # Supervision : état du service et du port
├── Set-TightVNCPassword.ps1    # Changement de mot de passe
├── Deploy-TightVNC.ps1         # Déploiement multi-machines via WinRM
└── Test-TightVNCPort.ps1       # Test de connectivité réseau
```

### Exemple : `Get-TightVNCStatus.ps1`

```powershell
<#
.SYNOPSIS
    Vérifie l'état du service TightVNC et du port d'écoute.
.DESCRIPTION
    Affiche le statut du service Windows, le port d'écoute actif,
    et la configuration réseau du pare-feu pour TightVNC.
.EXAMPLE
    .\Get-TightVNCStatus.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "`n=== TightVNC Status Report ===" -ForegroundColor Cyan
Write-Host "Hôte   : $env:COMPUTERNAME"
Write-Host "Date   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# 1. État du service
try {
    $svc = Get-Service -Name "tvnserver"
    $statusColor = if ($svc.Status -eq "Running") { "Green" } else { "Red" }
    Write-Host "Service  : $($svc.DisplayName)" -NoNewline
    Write-Host " [$($svc.Status)]" -ForegroundColor $statusColor
    Write-Host "StartType: $($svc.StartType)"
} catch {
    Write-Host "Service tvnserver : NON TROUVÉ" -ForegroundColor Red
}

# 2. Port d'écoute
Write-Host ""
$port = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\TightVNC\Server" -Name "RfbPort" -ErrorAction SilentlyContinue
$port = if ($port) { $port } else { 5900 }
Write-Host "Port configuré : $port/TCP"

$listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($listener) {
    Write-Host "Port $port : EN ÉCOUTE ✓" -ForegroundColor Green
} else {
    Write-Host "Port $port : NON EN ÉCOUTE ✗" -ForegroundColor Yellow
}

# 3. Règles de pare-feu
Write-Host ""
Write-Host "Règles de pare-feu TightVNC :"
Get-NetFirewallRule -DisplayName "TightVNC*" -ErrorAction SilentlyContinue |
    Select-Object DisplayName, Enabled, Direction, Action |
    Format-Table -AutoSize

Write-Host "=== Fin du rapport ===" -ForegroundColor Cyan
```

### Exemple : `Test-TightVNCPort.ps1`

```powershell
<#
.SYNOPSIS
    Teste la connectivité VNC vers une ou plusieurs machines distantes.
.PARAMETER Targets
    Liste des noms d'hôtes ou IPs à tester.
.PARAMETER Port
    Port VNC à tester (défaut : 5900).
.EXAMPLE
    .\Test-TightVNCPort.ps1 -Targets "192.168.1.10", "PC-BUREAU-01"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$Targets,
    [int]$Port = 5900,
    [int]$TimeoutMs = 2000
)

$results = foreach ($target in $Targets) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($target, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($wait -and $tcp.Connected) {
            $tcp.EndConnect($connect)
            [PSCustomObject]@{ Host = $target; Port = $Port; Status = "OPEN"; Latency = "OK" }
        } else {
            [PSCustomObject]@{ Host = $target; Port = $Port; Status = "CLOSED/TIMEOUT"; Latency = "N/A" }
        }
        $tcp.Close()
    } catch {
        [PSCustomObject]@{ Host = $target; Port = $Port; Status = "ERREUR: $($_.Exception.Message)"; Latency = "N/A" }
    }
}

$results | Format-Table -AutoSize
```

---

## 🏭 Déploiement en masse

### Via WinRM (PowerShell Remoting)

```powershell
# Déployer TightVNC sur une liste de machines via WinRM
$machines = @("PC-001", "PC-002", "PC-003", "192.168.1.50")
$credential = Get-Credential -Message "Identifiants administrateur"

$msiContent = [Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\Downloads\tightvnc-2.8.87-gpl-setup-64bit.msi"))

Invoke-Command -ComputerName $machines -Credential $credential -ScriptBlock {
    param($msiBase64)

    $msiPath = "C:\Windows\Temp\tightvnc.msi"
    [IO.File]::WriteAllBytes($msiPath, [Convert]::FromBase64String($msiBase64))

    $args = '/i "{0}" /quiet /norestart ADDLOCAL=Server SERVER_REGISTER_AS_SERVICE=1 SERVER_START_AS_SERVICE=1 SET_USEVNCAUTHENTICATION=1 VALUE_OF_USEVNCAUTHENTICATION=1 SET_PASSWORD=1 VALUE_OF_PASSWORD=P@ssw0rdVNC!' -f $msiPath

    Start-Process msiexec.exe -ArgumentList $args -Wait -NoNewWindow
    Remove-Item $msiPath -Force

    Write-Host "$env:COMPUTERNAME : Installation terminée"
} -ArgumentList $msiContent
```

### Via une GPO (Group Policy Object)

1. Placer le fichier `.msi` dans un partage réseau accessible par les machines cibles
2. Dans **Group Policy Management Console** :
   - Créer ou éditer une GPO liée à l'OU cible
   - Aller dans : *Computer Configuration > Policies > Software Settings > Software installation*
   - Ajouter le package MSI depuis le chemin UNC : `\\SERVEUR\Partage\tightvnc-2.8.87-gpl-setup-64bit.msi`
   - Configurer les propriétés (Advanced pour personnaliser via un fichier `.mst`)
3. Forcer l'application : `gpupdate /force` sur les machines cibles

---

## 🌐 Ports réseau

| Port | Protocole | Usage | Requis |
|------|-----------|-------|--------|
| 5900 | TCP | Connexion VNC principale (RFB) | ✅ Obligatoire |
| 5800 | TCP | Viewer HTTP intégré (Java, déprécié) | ❌ Optionnel |
| 5500 | TCP | Connexion inverse (Viewer → Server) | ❌ Optionnel |
| 22 | TCP | Tunnel SSH (si utilisé pour sécuriser VNC) | ✅ Recommandé |

> **Note :** Si vous exécutez plusieurs instances de TightVNC Server sur la même machine, les ports s'incrémentent automatiquement (5900, 5901, 5902...).

---

## 🆚 Différences Server / Viewer

| Fonctionnalité | Server | Viewer |
|----------------|--------|--------|
| Expose le bureau | ✅ | ❌ |
| Reçoit les connexions | ✅ | ❌ |
| Se connecte à un bureau distant | ❌ | ✅ |
| Transfert de fichiers | ✅ (côté serveur) | ✅ (côté client) |
| Synchronisation presse-papiers | ✅ | ✅ |
| Support multi-moniteurs | ✅ (DesktopConfig) | ✅ (avec MightyViewer) |
| Mode service Windows | ✅ | ❌ |
| Exécution sans session user | ✅ (service) | ❌ |

---

## 🆕 Nouveautés de la version 2.8.87

### Server pour Windows
- **Correction bug #1647** : Fonctionnement en mode application corrigé pour les environnements avec plusieurs sessions RDP simultanées.
- **Résolution max étendue** : La résolution maximale d'écran (largeur ou hauteur) passe de **32 000 à 65 535 pixels**.

### Server et Viewer pour Windows
- **Correction de bugs** dans le calcul de la taille du tampon lors de la réception et de la conversion des données du presse-papiers.

### Installeur pour Windows
- **Désinstallation améliorée** : Le désinstallateur supprime désormais correctement l'application de contrôle du service TightVNC.

---

## 📜 Historique des versions récentes

| Version | Changement principal |
|---------|---------------------|
| **2.8.87** | Fix sessions RDP multiples, résolution max 65535px |
| **2.8.85** | Fix connexion Windows XP |
| **2.8.84** | Sécurité : désactivation connexion réseau au pipe de contrôle |
| **2.8.81** | Nouveau `DesktopConfiguration` pseudo-encoding, remplacement de `ExtendedDesktopSize` |
| **2.8.78** | Support `SetDesktopSize`, fix flickering avec TigerVNC, update zlib 1.2.13 |
| **2.8.75** | Update zlib + libjpeg, support multi-moniteurs côté serveur, nombreux correctifs |
| **2.8.63** | Amélioration du screen grabbing Windows 8+, fix encodage curseurs couleur |
| **2.8.53** | Support Unicode clipboard (UTF-8), protection brute-force améliorée, perf. CopyRect+D3D |

---

## ❓ FAQ

**Q : TightVNC est-il compatible avec d'autres clients VNC (RealVNC, UltraVNC, TigerVNC) ?**
> Oui, TightVNC implémente le protocole RFB standard et est interopérable avec la grande majorité des clients/serveurs VNC. Depuis la v2.8.78, un fix a été apporté pour la compatibilité spécifique avec TigerVNC.

**Q : Est-ce que TightVNC chiffre les connexions ?**
> Non, par défaut les connexions VNC voyagent en clair. Utilisez un tunnel SSH ou un VPN pour chiffrer vos sessions (voir [Tunneling SSH](#tunneling-ssh)).

**Q : Le mot de passe VNC est-il limité à 8 caractères ?**
> Oui, le protocole RFB standard (VNC authentication) est limité à 8 caractères. Les caractères supplémentaires sont ignorés. Pour une sécurité accrue, combinez-le avec un tunnel SSH.

**Q : Puis-je accéder à la session RDP d'un serveur Windows via TightVNC ?**
> Oui, depuis la v2.8.53. Activez cette option dans les paramètres avancés du Server. Notez que les transferts de fichiers sont désactivés pendant les sessions RDP.

**Q : Comment voir les logs de TightVNC Server ?**
> Les erreurs sont loggées dans l'Observateur d'événements Windows : *Journaux Windows > Application*, source `tvnserver`.

```powershell
# Voir les 50 derniers événements TightVNC
Get-EventLog -LogName Application -Source "tvnserver" -Newest 50 | Format-List TimeGenerated, EntryType, Message
```

**Q : Peut-on utiliser TightVNC sans l'installer (portable) ?**
> Partiellement. `tvnviewer.exe` peut fonctionner sans installation. Le Server nécessite en général des droits admin pour le service, mais peut fonctionner en mode application avec un simple exécutable.

**Q : TightVNC supporte-t-il le multi-moniteurs ?**
> Oui, depuis la v2.8.81 via le `DesktopConfiguration` pseudo-encoding. Le support complet (affichage de plusieurs moniteurs simultanément) est implémenté dans MightyViewer.

---

## 🤝 Contribuer

Les contributions sont les bienvenues ! Merci de suivre ces étapes :

1. **Forker** ce dépôt
2. Créer une branche pour votre fonctionnalité :
   ```powershell
   git checkout -b feature/ma-fonctionnalite
   ```
3. Committer vos modifications :
   ```powershell
   git commit -m "feat: ajout du script de déploiement Intune"
   ```
4. Pousser la branche :
   ```powershell
   git push origin feature/ma-fonctionnalite
   ```
5. Ouvrir une **Pull Request** sur GitHub

### Standards de codage

- Scripts PowerShell : respecter les [PowerShell Best Practices](https://poshcode.gitbook.io/powershell-practice-and-style/)
- Commentaires en français ou en anglais (cohérence au sein d'un même fichier)
- Inclure un bloc `.SYNOPSIS` / `.DESCRIPTION` / `.EXAMPLE` dans chaque script
- Tester avec `PSScriptAnalyzer` avant de soumettre :
  ```powershell
  Install-Module PSScriptAnalyzer -Force
  Invoke-ScriptAnalyzer -Path .\scripts\ -Recurse
  ```

---

## 📄 Licence

Ce projet est distribué sous la licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

TightVNC lui-même est distribué sous **GNU GPL v2** (version gratuite). Voir [tightvnc.com/licensing.php](https://www.tightvnc.com/licensing.php) pour les détails.

---

## 🔗 Références

- 🌐 [Site officiel TightVNC](https://www.tightvnc.com/)
- 📥 [Page de téléchargement TightVNC 2.8.87](https://www.tightvnc.com/download.php)
- 📋 [Changelog complet](https://www.tightvnc.com/whatsnew.php)
- 📚 [Documentation officielle](https://www.tightvnc.com/docs.php)
- 🐛 [Signaler un bug](https://www.tightvnc.com/bugs.php)
- 🔒 [Politique de confidentialité TightVNC](https://www.tightvnc.com/privacy.php)
- 🏢 [GlavSoft LLC (éditeur)](https://glavsoft.com/)
- 🖥️ [MightyViewer — Multi VNC Manager](https://mightyviewer.com/)
- 📖 [Protocole RFB — RFC 6143](https://www.rfc-editor.org/rfc/rfc6143)
- 💻 [PowerShell 7 — Documentation Microsoft](https://learn.microsoft.com/fr-fr/powershell/)
- 🐙 [GitHub CLI (`gh`) — Documentation](https://cli.github.com/manual/)

---

<div align="center">

Fait avec ❤️ par [valorisa](https://github.com/valorisa) • Windows 11 Enterprise • PowerShell 7.6.1

</div>

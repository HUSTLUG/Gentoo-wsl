#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Generate a local manifest.json for a custom Gentoo WSL distribution
  and point Windows to it via the DistributionListUrl registry key.

.EXAMPLE
  .\override-manifest.ps1 -TarPath C:\WSL\gentoo_2025-05-25.wsl
#>

[CmdletBinding(PositionalBinding = $false)]
param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$TarPath,

    [string]$Flavor       = "Gentoo",          # identifier in `wsl --list --online`
    [string]$Version      = "Gentoo",    # unique version tag
    [string]$FriendlyName = "Gentoo Linux (rolling)"
)

Set-StrictMode -Version Latest

# Resolve absolute path and compute SHA-256
$TarPath = (Resolve-Path $TarPath).Path
$Hash    = (Get-FileHash $TarPath -Algorithm SHA256).Hash

# Build manifest hashtable
$Manifest = @{
    ModernDistributions = @{
        $Flavor = @(
            @{
                Name         = $Version
                Default      = $true
                FriendlyName = $FriendlyName
                Amd64Url     = @{
                    Url    = "file://$TarPath"
                    Sha256 = "0x$Hash"
                }
            }
        )
    }
}

# Write manifest.json next to this script
$ManifestFile = Join-Path $PSScriptRoot "manifest.json"
$Manifest | ConvertTo-Json -Depth 5 | Out-File -Encoding ascii $ManifestFile

Write-Host "Manifest written to $ManifestFile" -ForegroundColor Green

# Point the WSL service to the custom manifest
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss"
Set-ItemProperty -Path $RegPath -Name DistributionListUrl -Value "file://$ManifestFile" -Type String -Force

Write-Host "`nRegistry key updated successfully." -ForegroundColor Green
Write-Host "Run  'wsl --list --online'  to verify that '$Version' appears." -ForegroundColor Yellow

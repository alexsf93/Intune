<#
=====================================================================================================
    REMEDIACIÓN: INSTALACIÓN/ACTUALIZACIÓN DE INTUNE MANAGEMENT EXTENSION (IME)
-----------------------------------------------------------------------------------------------------
Descarga e instala silenciosamente la última versión oficial del agente IME y elimina el MSI temporal
al finalizar. Al terminar, muestra en el output la versión instalada de IME.
Compatible con Intune Remediations (debe ejecutarse como SYSTEM).
-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

$installerUrl = "https://approdimedatapri.azureedge.net/IntuneWindowsAgent.msi"
$tempMsi = "$env:TEMP\IME-latest.msi"
$imeExePath = "C:\Program Files (x86)\Microsoft Intune Management Extension\Microsoft.Management.Services.IntuneWindowsAgent.exe"

try {
    Write-Output "Descargando MSI de IME desde $installerUrl ..."
    Invoke-WebRequest -Uri $installerUrl -OutFile $tempMsi -UseBasicParsing -ErrorAction Stop
    Write-Output "MSI descargado en $tempMsi"
} catch {
    Write-Output "Error descargando MSI de IME: $($_.Exception.Message)"
    if (Test-Path $tempMsi) { Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue }
    Exit 1
}

try {
    Write-Output "Instalando o reparando IME..."
    Start-Process msiexec.exe -ArgumentList "/i `"$tempMsi`" /qn /norestart" -Wait
    Write-Output "Instalación/reparación IME completada."
} catch {
    Write-Output "Error durante la instalación del MSI: $($_.Exception.Message)"
    if (Test-Path $tempMsi) { Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue }
    Exit 1
}

try {
    Write-Output "Intentando iniciar el servicio IntuneManagementExtension..."
    Start-Service -Name "IntuneManagementExtension" -ErrorAction SilentlyContinue
} catch {
    Write-Output "No se pudo iniciar el servicio IntuneManagementExtension."
}

if (Test-Path $tempMsi) {
    Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue
    Write-Output "MSI temporal eliminado."
}

# Mostrar la versión instalada de IME
if (Test-Path $imeExePath) {
    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($imeExePath)
    $imeVersion = $versionInfo.ProductVersion
    Write-Output "Versión instalada de IME: $imeVersion"
} else {
    Write-Output "No se encontró el ejecutable de IME para mostrar la versión."
}

Write-Output "Remediación IME finalizada."
Exit 0

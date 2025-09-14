<#
=====================================================================================================
    REMEDIATION SCRIPT: INSTALACIÓN/ACTUALIZACIÓN DE INTUNE MANAGEMENT EXTENSION (IME)
-----------------------------------------------------------------------------------------------------
Este script descarga e instala silenciosamente la última versión oficial del agente **Intune 
Management Extension (IME)** desde la CDN de Microsoft.  

Tras la instalación o reparación, elimina el archivo MSI temporal y muestra en la salida la versión 
de IME instalada. Está diseñado para ejecutarse como parte de **Intune Remediations** en dispositivos 
gestionados.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Compatible con PowerShell 5.1 y 7.x.
- Requiere ejecución con privilegios SYSTEM o administrador local.
- Acceso a Internet para descargar el instalador oficial.
- Acceso a `msiexec.exe` para instalación de MSI.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Descarga el MSI oficial de IME en la carpeta temporal del sistema.
- Lanza la instalación/reparación en modo silencioso (`/qn /norestart`).
- Intenta iniciar el servicio `IntuneManagementExtension`.
- Elimina el MSI temporal al finalizar.
- Muestra en salida la versión final instalada de IME.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → IME instalado/actualizado correctamente. La salida incluye la versión instalada.
- "NOK" (exit code 1) → Error al descargar o instalar IME. Se informa en la salida estándar.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar como Remediation Script en Intune.
- Combinado con un Detection Script que valide la versión de IME.
- Revisar la salida estándar para confirmar la instalación y versión.

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

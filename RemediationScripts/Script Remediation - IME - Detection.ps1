<#
=====================================================================================================
    DETECCIÓN: VERSIÓN DE INTUNE MANAGEMENT EXTENSION DESACTUALIZADA/CORRUPTA
-----------------------------------------------------------------------------------------------------
Compara la versión instalada localmente de IME con la que viene en el MSI oficial descargado.
-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

Function Get-MsiVersion($msiPath) {
    try {
        $installer = New-Object -ComObject WindowsInstaller.Installer
        $database = $installer.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $installer, @($msiPath, 0))
        $view = $database.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $database, ("SELECT Value FROM Property WHERE Property = 'ProductVersion'"))
        $view.GetType().InvokeMember("Execute", "InvokeMethod", $null, $view, $null)
        $record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)
        $version = $null
        if ($record) {
            $version = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 1)
        }
        return $version
    } catch {
        Write-Output "Error extrayendo versión del MSI: $($_.Exception.Message)"
        return $null
    }
}

$imePath = "C:\Program Files (x86)\Microsoft Intune Management Extension\Microsoft.Management.Services.IntuneWindowsAgent.exe"
$installerUrl = "https://approdimedatapri.azureedge.net/IntuneWindowsAgent.msi"
$tempMsi = "$env:TEMP\IME-latest.msi"

try {
    Write-Output "Descargando MSI de IME..."
    Invoke-WebRequest -Uri $installerUrl -OutFile $tempMsi -UseBasicParsing -ErrorAction Stop
    Write-Output "MSI descargado en $tempMsi"
} catch {
    Write-Output "Error descargando MSI de IME: $($_.Exception.Message)"
    if (Test-Path $tempMsi) { Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue }
    Exit 1
}

# Obtener versión del MSI
$msiVer = Get-MsiVersion $tempMsi
Write-Output "Versión obtenida del MSI (sin limpiar): '$msiVer'"

# Limpiar y validar versión MSI
if ($null -eq $msiVer -or $msiVer -eq "") {
    Write-Output "No se pudo obtener versión del MSI (valor nulo o vacío)."
    if (Test-Path $tempMsi) { Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue }
    Exit 1
}

$msiVer = "$msiVer"
$msiVerLimpio = $null
if ($msiVer -match '(\d+\.\d+\.\d+\.\d+)') {
    $msiVerLimpio = $matches[1]
    Write-Output "Versión numérica limpia del MSI: '$msiVerLimpio'"
} else {
    Write-Output "No se pudo extraer versión numérica limpia del MSI: '$msiVer'"
    if (Test-Path $tempMsi) { Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue }
    Exit 1
}

# Obtener versión local instalada
if (Test-Path $imePath) {
    $localVerFull = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($imePath)).ProductVersion
    Write-Output "Versión local completa: '$localVerFull'"
    $localVerLimpio = $null
    if ($localVerFull -match '(\d+\.\d+\.\d+\.\d+)') {
        $localVerLimpio = $matches[1]
        Write-Output "Versión local numérica limpia: '$localVerLimpio'"
    } else {
        Write-Output "No se pudo extraer versión local numérica: $localVerFull"
        if (Test-Path $tempMsi) { Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue }
        Exit 1
    }
} else {
    Write-Output "IME no instalado"
    if (Test-Path $tempMsi) { Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue }
    Exit 1
}

Write-Output "Comparando versiones: Local='$localVerLimpio', MSI='$msiVerLimpio'"

if ($localVerLimpio -and $msiVerLimpio) {
    try {
        if ([version]$localVerLimpio -lt [version]$msiVerLimpio) {
            Write-Output "IME ($localVerLimpio) es anterior al MSI ($msiVerLimpio)"
            if (Test-Path $tempMsi) { Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue }
            Exit 1
        }
    } catch {
        Write-Output "Error comparando versiones: $localVerLimpio / $msiVerLimpio"
        if (Test-Path $tempMsi) { Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue }
        Exit 1
    }
} else {
    Write-Output "No se pudo obtener una versión válida para comparar. Local='$localVerLimpio', MSI='$msiVerLimpio'"
    if (Test-Path $tempMsi) { Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue }
    Exit 1
}

Write-Output "IME actualizado ($localVerLimpio)"
if (Test-Path $tempMsi) { Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue }
Exit 0

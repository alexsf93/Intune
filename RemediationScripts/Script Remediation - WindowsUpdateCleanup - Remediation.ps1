<#
.SYNOPSIS
    REMEDIATION SCRIPT: Script de remediacion para la limpieza de almacenamiento.

.DESCRIPTION
    Libera bloqueos de servicios, ejecuta DISM, remueve firmas viejas de Defender
    y purga temporales, caches, informes WER y registros de recuperacion del sistema.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - WindowsUpdateCleanup - Remediation.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 3.6.1
    Date: 2026-06-15
    Context: System
#>

Write-Host "Iniciando remediacion automatica avanzada del sistema..."

try {
    # 1. Parada de servicios para liberar bloqueos de archivos
    Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "dosvc" -Force -ErrorAction SilentlyContinue

    # 2. Mantenimiento del almacen de componentes
    $dismArgs = "/Online /Cleanup-Image /StartComponentCleanup /ResetBase /NoRestart"
    Start-Process -FilePath "Dism.exe" -ArgumentList $dismArgs -NoNewWindow -Wait -ErrorAction SilentlyContinue

    # 3. Limpieza nativa de firmas antiguas de Microsoft Defender
    if (Test-Path "C:\Program Files\Windows Defender\MpCmdRun.exe") {
        Start-Process -FilePath "C:\Program Files\Windows Defender\MpCmdRun.exe" -ArgumentList "-RemoveDefinitions -All" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    }

    # 4. Definicion de rutas globales (Sistema, Optimizacion, WER, Volcados, Papelera y Logs de Recuperacion)
    $targetDirectories = @(
        "C:\Windows\SoftwareDistribution\Download",
        "C:\Windows\SoftwareDistribution\PostRebootEventCache.V2",
        "C:\Windows\Logs\WindowsUpdate",
        "C:\Windows\Temp",
        "C:\Windows\Prefetch",
        "C:\ProgramData\Microsoft\Windows\DeliveryOptimization\Cache",
        "C:\Windows\Downloaded Program Files",
        "C:\Windows\Minidump",
        "C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
        "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
        "C:\ProgramData\Microsoft\Windows\WER\Temp",
        "C:\$Recycle.Bin",
        "C:\$Windows.~BT\Sources\Rollback",
        "C:\Windows\System32\LogFiles\Setupcln"
    )

    $targetFiles = @()

    if (Test-Path "C:\Windows\MEMORY.DMP") {
        $targetFiles += "C:\Windows\MEMORY.DMP"
    }

    # 5. Mapeo de rutas de perfiles de usuario
    $userProfiles = Get-ChildItem -Path "C:\Users" -ErrorAction SilentlyContinue
    foreach ($profile in $userProfiles) {
        $userTemp = Join-Path $profile.FullName "AppData\Local\Temp"
        if (Test-Path $userTemp) { $targetDirectories += $userTemp }

        $userNetCache = Join-Path $profile.FullName "AppData\Local\Microsoft\Windows\INetCache"
        if (Test-Path $userNetCache) { $targetDirectories += $userNetCache }

        $userDirectX = Join-Path $profile.FullName "AppData\Local\D3DSCache"
        if (Test-Path $userDirectX) { $targetDirectories += $userDirectX }

        $userThumbs = Join-Path $profile.FullName "AppData\Local\Microsoft\Windows\Explorer"
        if (Test-Path $userThumbs) {
            $thumbs = Get-ChildItem -Path $userThumbs -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue
            $icons = Get-ChildItem -Path $userThumbs -Filter "iconcache_*.db" -ErrorAction SilentlyContinue
            
            foreach ($f in $thumbs) { $targetFiles += $f.FullName }
            foreach ($f in $icons) { $targetFiles += $f.FullName }
        }
    }

    # 6. Purga de directorios (mantiene carpetas raiz)
    foreach ($dir in $targetDirectories) {
        if (Test-Path $dir) {
            Get-ChildItem -Path $dir -Recurse -ErrorAction SilentlyContinue | 
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue > $null
        }
    }

    # 7. Borrado de archivos sueltos
    foreach ($file in $targetFiles) {
        if (Test-Path $file) {
            Remove-Item -Path $file -Force -ErrorAction SilentlyContinue > $null
        }
    }

} catch {
    Write-Host "Aviso: Se presentaron algunas restricciones en el vaciado pero el proceso continuo."
} finally {
    # 8. Restauracion de servicios obligatoria
    Start-Service -Name "dosvc" -ErrorAction SilentlyContinue
    Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    
    Write-Host "Remediacion avanzada completada con exito."
    exit 0
}

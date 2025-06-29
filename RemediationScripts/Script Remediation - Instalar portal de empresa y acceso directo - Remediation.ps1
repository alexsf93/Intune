<#
=====================================================================================================
    REMEDIACIÓN: INSTALAR COMPANY PORTAL Y ACCESO DIRECTO EN ESCRITORIOS DE TODOS LOS USUARIOS
-----------------------------------------------------------------------------------------------------
Este script detecta si la aplicación Company Portal está instalada. Si no lo está, la instala (usando 
Winget o PowerShell) y crea un acceso directo en el escritorio público y en todos los escritorios 
de usuarios locales existentes.

Compatible con Intune Remediations.
-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

# 1. Instalar Company Portal si no está
$cp = Get-AppxPackage -Name "Microsoft.CompanyPortal"
if (-not $cp) {
    try {
        # Usar winget si está disponible
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install -e --id Microsoft.CompanyPortal -h --accept-source-agreements --accept-package-agreements
            Start-Sleep -Seconds 8
        } else {
            Write-Host "Winget no disponible. Intentando instalar desde Microsoft Store con PowerShell..."
            # Forzar instalación desde Microsoft Store con PowerShell (sólo si el sistema lo permite)
            Add-AppxPackage -register "C:\Program Files\WindowsApps\Microsoft.CompanyPortal_*\AppxManifest.xml" -DisableDevelopmentMode
            Start-Sleep -Seconds 8
        }
    } catch {
        Write-Host "Error instalando Company Portal: $_"
    }
}

# 2. Crear acceso directo en el escritorio público (todos los usuarios)
$publicDesktop = "$env:Public\Desktop"
$shortcutPath = Join-Path $publicDesktop "Company Portal.lnk"
$target = "shell:AppsFolder\Microsoft.CompanyPortal_8wekyb3d8bbwe!App"

if (-not (Test-Path $shortcutPath)) {
    try {
        $wshell = New-Object -ComObject WScript.Shell
        $sc = $wshell.CreateShortcut($shortcutPath)
        $sc.TargetPath = $target
        $sc.Save()
    } catch {
        Write-Host "No se pudo crear el acceso directo en el escritorio público: $_"
    }
}

# 3. Crear el acceso directo en todos los escritorios de usuarios locales
$users = Get-ChildItem 'C:\Users' -Directory | Where-Object {
    Test-Path "$($_.FullName)\Desktop" -and $_.Name -notin @('Public','Default','Default User','All Users')
}

foreach ($user in $users) {
    $desktopPath = "$($user.FullName)\Desktop\Company Portal.lnk"
    if (-not (Test-Path $desktopPath)) {
        try {
            $wshell = New-Object -ComObject WScript.Shell
            $sc = $wshell.CreateShortcut($desktopPath)
            $sc.TargetPath = $target
            $sc.Save()
        } catch {
            Write-Host "No se pudo crear el acceso directo para $($user.FullName): $_"
        }
    }
}

Write-Host "Proceso de remediación de Company Portal finalizado."

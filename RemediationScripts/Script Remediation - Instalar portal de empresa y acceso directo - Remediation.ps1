<#
=====================================================================================================
    REMEDIATION SCRIPT: INSTALAR COMPANY PORTAL Y CREAR ACCESO DIRECTO PARA TODOS LOS USUARIOS
-----------------------------------------------------------------------------------------------------
Este script verifica si **Company Portal** está instalado. Si no lo está, intenta instalarlo (vía
Winget o, en su defecto, mediante PowerShell registrando el paquete si existe en el sistema) y crea
un acceso directo en el Escritorio público y en los escritorios de todos los usuarios locales.

Compatible con Intune Remediations (recomendado ejecutarlo como SYSTEM).

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Winget disponible (preferente) o paquete preinstalado de Microsoft Store.
- Permisos para escribir en `C:\Users\Public\Desktop` y en los perfiles de usuario.
- Permisos para crear accesos directos mediante `WScript.Shell` (COM).

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Comprueba si existe `Microsoft.CompanyPortal` (AppX/MSIX) con `Get-AppxPackage`.
- Si no está instalado:
  * Intenta instalación silenciosa con Winget: `Microsoft.CompanyPortal`.
  * Si Winget no está disponible, intenta registrar el paquete desde WindowsApps (si existe).
- Crea un acceso directo a la app (AppsFolder) en:
  * Escritorio público.
  * Escritorios de todos los usuarios locales existentes (excepto perfiles especiales).
- Muestra mensajes de estado en la salida estándar.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0 implícito) → Company Portal instalado (o ya presente) y accesos directos creados.
- Mensajes informativos → Detallan si la instalación o creación de accesos directos tuvo incidencias.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar como Remediation Script en Intune.
- Revisar la salida estándar para confirmar instalación y creación de accesos directos.
- Si Winget no está disponible, asegúrate de que el paquete esté presente en `WindowsApps` para el registro.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

# 1) Instalar Company Portal si no está
$cp = Get-AppxPackage -Name "Microsoft.CompanyPortal" -ErrorAction SilentlyContinue
if (-not $cp) {
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "Winget disponible. Instalando Microsoft.CompanyPortal..."
            # -e (exact), -h (ocultar salida), aceptar acuerdos
            winget install -e --id Microsoft.CompanyPortal -h --accept-source-agreements --accept-package-agreements
            Start-Sleep -Seconds 8
        } else {
            Write-Host "Winget no disponible. Intentando registro del paquete desde WindowsApps..."
            # Si el paquete ya está descargado en WindowsApps, se puede registrar
            $manifests = Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.CompanyPortal_*" -Directory -ErrorAction SilentlyContinue |
                         ForEach-Object { Join-Path $_.FullName "AppxManifest.xml" } |
                         Where-Object { Test-Path $_ }
            if ($manifests) {
                foreach ($mf in $manifests) {
                    try {
                        Add-AppxPackage -Register $mf -DisableDevelopmentMode -ErrorAction Stop
                        Write-Host "Registrado Company Portal desde: $mf"
                        break
                    } catch {
                        Write-Host "Error registrando desde $mf : $($_.Exception.Message)"
                    }
                }
            } else {
                Write-Host "No se encontró paquete de Company Portal en WindowsApps para registrar."
            }
            Start-Sleep -Seconds 8
        }
    } catch {
        Write-Host "Error instalando Company Portal: $($_.Exception.Message)"
    }
}

# Revalidar instalación
$cp = Get-AppxPackage -Name "Microsoft.CompanyPortal" -ErrorAction SilentlyContinue
if (-not $cp) {
    Write-Host "Company Portal no está instalado tras el intento de remediación."
} else {
    Write-Host "Company Portal detectado. Procediendo a crear accesos directos."
}

# 2) Crear acceso directo en el escritorio público (todos los usuarios)
$publicDesktop = Join-Path $env:Public "Desktop"
if (-not (Test-Path $publicDesktop)) {
    try { New-Item -Path $publicDesktop -ItemType Directory -Force | Out-Null } catch {}
}
$publicShortcut = Join-Path $publicDesktop "Company Portal.lnk"
$target = "shell:AppsFolder\Microsoft.CompanyPortal_8wekyb3d8bbwe!App"

if (-not (Test-Path $publicShortcut)) {
    try {
        $wshell = New-Object -ComObject WScript.Shell
        $sc = $wshell.CreateShortcut($publicShortcut)
        $sc.TargetPath = $target
        $sc.Save()
        Write-Host "Acceso directo creado en Escritorio Público."
    } catch {
        Write-Host "No se pudo crear el acceso directo en el Escritorio Público: $($_.Exception.Message)"
    }
} else {
    Write-Host "Acceso directo ya existe en Escritorio Público."
}

# 3) Crear accesos directos en todos los escritorios de usuarios locales
$excludedProfiles = @('Public','Default','Default User','All Users','WDAGUtilityAccount')
$profiles = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -notin $excludedProfiles -and (Test-Path (Join-Path $_.FullName 'Desktop'))
}

foreach ($prof in $profiles) {
    $userDesktop = Join-Path $prof.FullName 'Desktop'
    $userShortcut = Join-Path $userDesktop "Company Portal.lnk"
    if (-not (Test-Path $userShortcut)) {
        try {
            $wshell = New-Object -ComObject WScript.Shell
            $sc = $wshell.CreateShortcut($userShortcut)
            $sc.TargetPath = $target
            $sc.Save()
            Write-Host "Acceso directo creado para: $($prof.Name)"
        } catch {
            Write-Host "No se pudo crear el acceso directo para $($prof.Name): $($_.Exception.Message)"
        }
    } else {
        Write-Host "Acceso directo ya existía para: $($prof.Name)"
    }
}

Write-Host "Remediación de Company Portal completada."

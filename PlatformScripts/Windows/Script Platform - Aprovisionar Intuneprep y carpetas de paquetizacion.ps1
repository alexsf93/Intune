<#
.SYNOPSIS
    Aprovisionamiento del entorno de paquetizacion Win32 (.intunewin) e IntuneWinAppUtil.

.DESCRIPTION
    Este script esta disenado para ejecutarse como Platform Script en Microsoft Intune bajo contexto SYSTEM o Administrador.
    Realiza las siguientes acciones:
    1. Crea la estructura de directorios en la raiz del sistema:
       - C:\Paquetizacion
       - C:\Paquetizacion\Source
       - C:\Paquetizacion\Output
    2. Descarga y aprovisiona la herramienta oficial IntuneWinAppUtil.exe desde el repositorio oficial de Microsoft en GitHub.
    3. Desbloquea el ejecutable eliminando marcas de zona de Internet (Zone.Identifier / Unblock-File).
    4. Genera una plantilla base 'Instalar.bat' en la carpeta Source si no existe previamente.
    5. Crea el script interactivo 'Crear-Intunewin.bat' en C:\Paquetizacion para compilar paquetes Win32 (.intunewin)
       solicitando nombre y version, utilizando C:\Paquetizacion\Source\Instalar.bat por defecto, sin catalogo (NO)
       y nombrando el resultado como '<Nombre> - <Version>.intunewin' en C:\Paquetizacion\Output.

.PARAMETER
    Ninguno.

.EXAMPLE
    .\Script Platform - Aprovisionar Intuneprep y carpetas de paquetizacion.ps1

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File ".\Script Platform - Aprovisionar Intuneprep y carpetas de paquetizacion.ps1"

.NOTES
    Name:       Script Platform - Aprovisionar Intuneprep y carpetas de paquetizacion.ps1
    Author:     Alejandro Suarez (@alexsf93)
    Date:       2026-11-15
    Version:    1.0.0
#>

[CmdletBinding()]
param ()

$ErrorActionPreference = 'Stop'

try {
    Write-Output "Iniciando aprovisionamiento del entorno de paquetizacion IntuneWin..."

    # Habilitar TLS 1.2 para descargas seguras
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $baseDir   = "C:\Paquetizacion"
    $sourceDir = Join-Path -Path $baseDir -ChildPath "Source"
    $outputDir = Join-Path -Path $baseDir -ChildPath "Output"

    # 1. Creacion de directorios
    $folders = @($baseDir, $sourceDir, $outputDir)
    foreach ($folder in $folders) {
        if (-not (Test-Path -Path $folder)) {
            Write-Output "Creando carpeta: $folder"
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        } else {
            Write-Output "La carpeta ya existe: $folder"
        }
    }

    # 2. Descarga y aprovisionamiento de IntuneWinAppUtil.exe
    $toolPath = Join-Path -Path $baseDir -ChildPath "IntuneWinAppUtil.exe"
    $downloadUrl = "https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/master/IntuneWinAppUtil.exe"

    Write-Output "Descargando IntuneWinAppUtil.exe desde el repositorio oficial de Microsoft..."
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($downloadUrl, $toolPath)

    if (Test-Path -Path $toolPath) {
        Unblock-File -Path $toolPath -ErrorAction SilentlyContinue
        Write-Output "Herramienta aprovisionada correctamente en: $toolPath"
    } else {
        throw "No se pudo encontrar el archivo descargado en $toolPath"
    }

    # 3. Crear plantilla base de Instalar.bat en Source si no existe
    $sampleInstaller = Join-Path -Path $sourceDir -ChildPath "Instalar.bat"
    if (-not (Test-Path -Path $sampleInstaller)) {
        $sampleContent = @"
@echo off
rem ===================================================
rem Script de instalacion principal
rem Coloque aqui los comandos de instalacion silenciosa
rem ===================================================
echo Instalando aplicacion...
exit /b 0
"@
        Set-Content -Path $sampleInstaller -Value $sampleContent -Encoding ASCII
        Write-Output "Plantilla de instalacion creada en: $sampleInstaller"
    }

    # 4. Generar el script interactivo Crear-Intunewin.bat en C:\Paquetizacion
    $batPath = Join-Path -Path $baseDir -ChildPath "Crear-Intunewin.bat"

    $batContent = @'
@echo off
setlocal EnableDelayedExpansion
title Asistente de Empaquetado IntuneWin
color 0B

echo ============================================================
echo           GENERADOR DE PAQUETES INTUNEWIN (.intunewin)
echo ============================================================
echo.

set "BASE_DIR=C:\Paquetizacion"
set "SOURCE_DIR=C:\Paquetizacion\Source"
set "OUTPUT_DIR=C:\Paquetizacion\Output"
set "SETUP_FILE=Instalar.bat"
set "TOOL_EXE=C:\Paquetizacion\IntuneWinAppUtil.exe"

:: 1. Verificaciones previas
if not exist "%TOOL_EXE%" (
    color 0C
    echo [ERROR] No se encontro IntuneWinAppUtil.exe en %TOOL_EXE%
    echo Por favor, vuelva a ejecutar el script de aprovisionamiento.
    pause
    exit /b 1
)

if not exist "%SOURCE_DIR%\%SETUP_FILE%" (
    color 0E
    echo [AVISO] No se encontro "%SETUP_FILE%" en "%SOURCE_DIR%".
    echo Asegurese de haber copiado los binarios y el archivo "%SETUP_FILE%"
    echo en la carpeta "%SOURCE_DIR%" antes de continuar.
    echo.
    set /p "CONFIRM=Desea continuar de todos modos? (S/N): "
    if /i not "!CONFIRM!"=="S" (
        echo Operacion cancelada por el usuario.
        pause
        exit /b 0
    )
)

:: 2. Preguntas interactivas
echo ------------------------------------------------------------
:ask_name
set "PKG_NAME="
set /p "PKG_NAME=>> Introduce el NOMBRE del paquete: "
if "!PKG_NAME!"=="" (
    echo El nombre no puede estar vacio. Intenta de nuevo.
    goto ask_name
)

:ask_version
set "PKG_VER="
set /p "PKG_VER=>> Introduce la VERSION del paquete: "
if "!PKG_VER!"=="" (
    echo La version no puede estar vacia. Intenta de nuevo.
    goto ask_version
)

echo ------------------------------------------------------------
echo Origen de archivos : %SOURCE_DIR%
echo Archivo ejecutable : %SETUP_FILE% (por defecto)
echo Carpeta de salida  : %OUTPUT_DIR%
echo Generar catalogo   : NO
echo Archivo resultante : !PKG_NAME! - !PKG_VER!.intunewin
echo ------------------------------------------------------------
echo.
echo Generando paquete .intunewin, por favor espere...
echo.

:: 3. Limpiar temporal previo si existia Instalar.intunewin en Output
if exist "%OUTPUT_DIR%\%SETUP_FILE:.bat=%.intunewin" (
    del /f /q "%OUTPUT_DIR%\%SETUP_FILE:.bat=%.intunewin" >nul 2>&1
)

:: 4. Ejecutar IntuneWinAppUtil en modo silencioso (catalogo = NO automatico)
"%TOOL_EXE%" -c "%SOURCE_DIR%" -s "%SETUP_FILE%" -o "%OUTPUT_DIR%" -q

:: 5. Renombrar el archivo generado al formato 'Nombre - Version.intunewin'
set "DEFAULT_OUTPUT=%OUTPUT_DIR%\Instalar.intunewin"
set "FINAL_NAME=!PKG_NAME! - !PKG_VER!.intunewin"
set "FINAL_PATH=%OUTPUT_DIR%\!FINAL_NAME!"

if exist "%DEFAULT_OUTPUT%" (
    if exist "!FINAL_PATH!" (
        echo [AVISO] Ya existia un archivo con ese nombre. Reemplazando...
        del /f /q "!FINAL_PATH!"
    )
    ren "%DEFAULT_OUTPUT%" "!FINAL_NAME!"
    
    color 0A
    echo.
    echo ============================================================
    echo [EXITO] Paquete generado correctamente:
    echo Ruta: !FINAL_PATH!
    echo ============================================================
) else (
    color 0C
    echo.
    echo ============================================================
    echo [ERROR] No se pudo generar el archivo .intunewin.
    echo Revise que la carpeta Source tenga los archivos necesarios.
    echo ============================================================
)

echo.
pause
exit /b 0
'@

    Set-Content -Path $batPath -Value $batContent -Encoding ASCII
    Write-Output "Script interactivo generado en: $batPath"

    Write-Output "Entorno de paquetizacion aprovisionado exitosamente."
    exit 0
}
catch {
    Write-Error "Error durante el aprovisionamiento: $_"
    exit 1
}

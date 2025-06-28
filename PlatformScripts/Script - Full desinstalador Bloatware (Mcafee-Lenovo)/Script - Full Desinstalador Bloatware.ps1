<#
============================================================
      Full Desinstalador de Bloatware Lenovo (PowerShell)
------------------------------------------------------------
Autor: Alejandro Suárez (@alexsf93)
Basado en el script original de HPC-Germany
============================================================

.DESCRIPCIÓN
    Este script elimina aplicaciones preinstaladas (bloatware) y utilidades innecesarias en equipos Lenovo,
    optimizando el rendimiento y liberando espacio en disco. Soporta ejecución interactiva y silenciosa.
    Incluye la desinstalación automática de McAfee, Dropbox, Intel Unison, Lenovo Vantage y más.

.NOTAS DE USO
    - Ejecutar SIEMPRE como administrador para máxima efectividad.
    - Si usas Intune y quieres desinstalar Dropbox, marca la opción
      "Run this script using the logged on credentials".
    - Puedes personalizar la whitelist de apps si lo deseas.

.PARAMETER customwhitelist
    (Opcional) Lista de aplicaciones a excluir de la desinstalación.

.EJEMPLOS
    # Ejecución estándar:
    .\Script - Full Desinstalador Bloatware.ps1

    # Ejecutar con whitelist personalizada:
    .\Script - Full Desinstalador Bloatware.ps1 -customwhitelist "App1","App2"

.ADVERTENCIAS
    - Elimina directorios y apps relacionados con McAfee y Lenovo.
    - Revisa y edita la lista de apps a eliminar según tu entorno.
    - Haz copia de seguridad antes de ejecutar en equipos de producción.
    - Usa bajo tu propia responsabilidad.

============================================================
#>

param (
    [string[]]$customwhitelist
)

##Elevar si no es administrador

If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Host "No estas ejecutando el script como administrador. Este script se elevará automáticamente para ejecutarse como administrador y continuar."
    Start-Sleep 1
    Write-Host "                                               3"
    Start-Sleep 1
    Write-Host "                                               2"
    Start-Sleep 1
    Write-Host "                                               1"
    Start-Sleep 1
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -WhitelistApps {1}" -f $PSCommandPath, ($WhitelistApps -join ',')) -Verb RunAs
    Exit
}

## Sin errores y modo background
$ErrorActionPreference = 'silentlycontinue'



$locale = Get-WinSystemLocale | Select-Object -expandproperty Name

## Active la configuración regional para configurar variables
switch ($locale) {
    "de-DE" {
        $everyone = "Jeder"
        $builtin = "Integriert"
    }
    "en-US" {
        $everyone = "Everyone"
        $builtin = "Builtin"
    }    
    "en-GB" {
        $everyone = "Everyone"
        $builtin = "Builtin"
    }
    default {
        $everyone = "Everyone"
        $builtin = "Builtin"
    }
}

## McAfee
write-host "Detectando McAfee"
$mcafeeinstalled = "false"
$InstalledSoftware = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
foreach($obj in $InstalledSoftware){
     $name = $obj.GetValue('DisplayName')
     if ($name -like "*McAfee*") {
         $mcafeeinstalled = "true"
     }
}

$InstalledSoftware32 = Get-ChildItem "HKLM:\Software\WOW6432NODE\Microsoft\Windows\CurrentVersion\Uninstall"
foreach($obj32 in $InstalledSoftware32){
     $name32 = $obj32.GetValue('DisplayName')
     if ($name32 -like "*McAfee*") {
         $mcafeeinstalled = "true"
     }
}

if ($mcafeeinstalled -eq "true") {
    Write-Host "McAfee detectado"

## McAfee
write-host "Descargando McAfee Removal Tool"
## Origen descarga
$URL = 'https://raw.githubusercontent.com/alexsf93/Intune/refs/heads/main/PlatformScripts/Script%20-%20Full%20desinstalador%20Bloatware%20(Mcafee-Lenovo)/mcafeeclean.zip'

## Set variable donde guardar zip
$destination = 'C:\ProgramData\Debloat\mcafee.zip'

## Descargar
Invoke-WebRequest -Uri $URL -OutFile $destination -Method Get
  
Expand-Archive $destination -DestinationPath "C:\ProgramData\Debloat" -Force

write-host "Eliminando McAfee"
## Automatización de desinstalación y matar los servicios
start-process "C:\ProgramData\Debloat\Mccleanup.exe" -ArgumentList "-p StopServices,MFSY,PEF,MXD,CSP,Sustainability,MOCP,MFP,APPSTATS,Auth,EMproxy,FWdiver,HW,MAS,MAT,MBK,MCPR,McProxy,McSvcHost,VUL,MHN,MNA,MOBK,MPFP,MPFPCU,MPS,SHRED,MPSCU,MQC,MQCCU,MSAD,MSHR,MSK,MSKCU,MWL,NMC,RedirSvc,VS,REMEDIATION,MSC,YAP,TRUEKEY,LAM,PCB,Symlink,SafeConnect,MGS,WMIRemover,RESIDUE -v -s"
write-host "McAfee Removal Tool se esta ejecutando"

## New MCCleanup
write-host "Descargando McAfee Removal Tool"
## Origen descarga
$URL = 'https://raw.githubusercontent.com/alexsf93/bloatwarelenovomcpr/refs/heads/main/mcafeeclean.zip'

## Set variable donde guardar zip
$destination = 'C:\ProgramData\Debloat\mcafeenew.zip'

## Descargar
Invoke-WebRequest -Uri $URL -OutFile $destination -Method Get
  
New-Item -Path "C:\ProgramData\Debloat\mcnew" -ItemType Directory
Expand-Archive $destination -DestinationPath "C:\ProgramData\Debloat\mcnew" -Force

write-host "Eliminando McAfee"
## Automatización de desinstalación y matar los servicios
start-process "C:\ProgramData\Debloat\mcnew\Mccleanup.exe" -ArgumentList "-p StopServices,MFSY,PEF,MXD,CSP,Sustainability,MOCP,MFP,APPSTATS,Auth,EMproxy,FWdiver,HW,MAS,MAT,MBK,MCPR,McProxy,McSvcHost,VUL,MHN,MNA,MOBK,MPFP,MPFPCU,MPS,SHRED,MPSCU,MQC,MQCCU,MSAD,MSHR,MSK,MSKCU,MWL,NMC,RedirSvc,VS,REMEDIATION,MSC,YAP,TRUEKEY,LAM,PCB,Symlink,SafeConnect,MGS,WMIRemover,RESIDUE -v -s"
write-host "McAfee Removal Tool se esta ejecutando"

$InstalledPrograms = $allstring | Where-Object {($_.Name -like "*McAfee*")}
$InstalledPrograms | ForEach-Object {

    Write-Host -Object "Intentando desinstalar: [$($_.Name)]..."
    $uninstallcommand = $_.String

    Try {
        if ($uninstallcommand -match "^msiexec*") {
            ## Eliminar msiexec ya que necesitamos dividirnos para la desinstalación.
            $uninstallcommand = $uninstallcommand -replace "msiexec.exe", ""
            $uninstallcommand = $uninstallcommand + " /quiet /norestart"
            $uninstallcommand = $uninstallcommand -replace "/I", "/X "   
            ## Desinstalar con parámetros string2
            Start-Process 'msiexec.exe' -ArgumentList $uninstallcommand -NoNewWindow -Wait
            }
            else {
            $string2 = $uninstallcommand
            start-process $string2
            }
        Write-Host -Object "Desinstalado satisfactoriamente: [$($_.Name)]"
    }
    Catch {Write-Warning -Message "Fallo al desinstalar: [$($_.Name)]"}
}

## Eliminar Safeconnect
$safeconnects = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -match "McAfee Safe Connect" } | Select-Object -Property UninstallString
 
ForEach ($sc in $safeconnects) {
    If ($sc.UninstallString) {
        cmd.exe /c $sc.UninstallString /quiet /norestart
    }
}
}

write-host "Completado"

## Eliminar WebAdvisor
cd "C:\Program Files\McAfee\WebAdvisor\"
.\uninstaller.exe /s

## Eliminar LenovoNow
$path = 'C:\Program Files (x86)\Lenovo\LenovoNow\unins000.exe'
$params = "/SILENT"
if (Test-Path -Path $path) {
    Start-Process -FilePath $path -ArgumentList $params -Wait
}

## Eliminar DROPBOX
Get-AppxPackage *Dropbox* | Remove-AppxPackage

## Eliminar INTEL UNISON LAUNCHER
$AppName = "Intel® Unison™ Launcher"
[version]$TargetVersion = "99.0"

$reg32 = Get-ChildItem -Path HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall
$reg64 = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall

foreach ($app32 in $reg32) {
	Set-Location HKLM:
	if (Get-ItemProperty -Path $app32 | Where-Object {
			$_.Displayname -like "*$AppName*" -and [version]$_.DisplayVersion -lt $TargetVersion
		}) {
		Set-Location c:
		Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/x $($app32.PsChildName) /qn /noreboot" -Wait
	}
	
}

foreach ($app64 in $reg64) {
	Set-Location HKLM:
	if (Get-ItemProperty -Path $app64 | Where-Object {
			$_.Displayname -like "*$AppName*" -and [version]$_.DisplayVersion -lt $TargetVersion
		}) {
		Set-Location c:
		Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/x $($app64.PsChildName) /qn /noreboot" -Wait
	}
	
}

## Eliminar Lenovo Vantage Microsoft Store
$AppList = "E046963F.LenovoCompanion",           
           "LenovoCorporation.LenovoSettings",
           "E046963F.LenovoSettingsforEnterprise"
           "E0469640.LenovoUtility"

ForEach ($App in $AppList)
{
   $PackageFullName = (Get-AppxPackage -allusers $App).PackageFullName
   $ProPackageFullName = (Get-AppxProvisionedPackage -online | where {$_.Displayname -eq $App}).PackageName
  
   ForEach ($AppToRemove in $PackageFullName)
   {
     Write-Host "Removing Package: $AppToRemove"
     try
     {
        remove-AppxPackage -package $AppToRemove -allusers
     }
     catch
     {
        ## A partir de Win10 20H1
        $PackageBundleName = (Get-AppxPackage -packagetypefilter bundle -allusers $App).PackageFullName
        ForEach ($BundleAppToRemove in $PackageBundleName)
        {
           remove-AppxPackage -package $BundleAppToRemove -allusers
        }
     }
   }

   ForEach ($AppToRemove in $ProPackageFullName)
   {
     Write-Host "Removing Provisioned Package: $AppToRemove"
     try
     {
        Remove-AppxProvisionedPackage -online -packagename $AppToRemove
     }
     catch
     {
        ## las aplicaciones empaquetadas/aprovisionadas ya han sido eliminadas por "remove-AppxPackage -allusers""
     }
   }

}

## Eliminar Lenovo Vantage Cliente Escritorio
$lvs = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object DisplayName -eq "Lenovo Vantage Service"
    if (!([string]::IsNullOrEmpty($lvs.QuietUninstallString))) {
        $uninstall = "cmd /c " + $lvs.QuietUninstallString
        write-output $uninstall
        Invoke-Expression $uninstall
    }

## BORRAR DIRECTORIOS MCAFEE Y LENOVO
## Definir la ruta para buscar
$searchPath = "C:\"

## Definir los términos de búsqueda
$searchTerms = @("McAfee", "Lenovo")

## Buscar directorios relacionados con McAfee o Lenovo
$directoriesToDelete = Get-ChildItem -Path $searchPath -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { 
    $matchFound = $false
    foreach ($term in $searchTerms) {
        if ($_.Name -like "*$term*") {
            $matchFound = $true
            break
        }
    }
    $matchFound
}

## Verificar si se encontraron directorios
if ($directoriesToDelete) {
    Write-Host "Se encontraron los siguientes directorios relacionados con 'McAfee' o 'Lenovo':"
    $directoriesToDelete | ForEach-Object { 
        Write-Host "Eliminando directorio: $($_.FullName)"
        Remove-Item -Path $_.FullName -Recurse -Force
    }
    Write-Host "Eliminación completa."
} else {
    Write-Host "No se encontraron directorios relacionados con 'McAfee' o 'Lenovo'."
}

## Retorno a C:\Windows
cd C:\Windows
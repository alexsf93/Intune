<#
.SYNOPSIS
    Habilitar Hyper-V + GUI en Windows 10/11.

.DESCRIPTION
    Automatiza la habilitación de Microsoft Hyper-V (incluyendo la consola gráfica de administración)
    en sistemas Windows compatibles. Programa un reinicio en 5 minutos.

.PARAMETER
    Ninguno.

.EXAMPLE
    .\Script - Hyper-V - Habilitar caracteristica Hyper-V.ps1

.NOTES
    Name: Script - Hyper-V - Habilitar caracteristica Hyper-V.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
#>


#Comprobar si Hyper-V está habilitado
if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Hypervisor).State -eq "Disabled") {
    Write-host "Habilitando Microsoft-Hyper-V ...."
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
}
else {
    Write-host "Microsoft-Hyper-V ha sido instalado satisfactoriamente"
}

#Comprobar si Hyper-V GUI está habilitado
if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-Clients).State -eq "Disabled") { 
    Write-host "Habilitando Microsoft-Hyper-V GUI ...."
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
}
else {
    Write-host "Microsoft-Hyper-V With GUI ha sido instalado satisfactoriamente"
}
shutdown /r /f /c "El equipo se reiniciara en 5 minutos para habilitar la caracteristica de Hyper-V" /t 300

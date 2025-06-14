#Comprobar si Hyper-V está habilitado
if((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Hypervisor).State -eq "Disabled")
{
    Write-host "Habilitando Microsoft-Hyper-V ...."
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
}
else
{
    Write-host "Microsoft-Hyper-V ha sido instalado satisfactoriamente"
}

#Comprobar si Hyper-V GUI está habilitado
if((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-Clients).State -eq "Disabled") 
{ 
    Write-host "Habilitando Microsoft-Hyper-V GUI ...."
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
}
else 
{
    Write-host "Microsoft-Hyper-V With GUI ha sido instalado satisfactoriamente"
}
shutdown /r /f /c "El equipo se reiniciara en 5 minutos para habilitar la caracteristica de Hyper-V" /t 300
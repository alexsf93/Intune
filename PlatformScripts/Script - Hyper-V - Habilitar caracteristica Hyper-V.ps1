<#
============================================================
      Script: Habilitar Hyper-V + GUI en Windows 10/11
------------------------------------------------------------
Autor: Alejandro Suárez (@alexsf93)
============================================================

.DESCRIPCIÓN
    Este script automatiza la **habilitación de Microsoft Hyper-V** (incluyendo la consola gráfica de administración, GUI)
    en sistemas Windows compatibles. Está pensado para uso manual o para despliegue mediante plataformas como Intune.

.CONSIDERACIONES Y REQUISITOS
    1. **Permisos de Administrador:**  
       Es imprescindible ejecutar el script como administrador.
    2. **Entornos gestionados (Intune/MDM):**  
       Si el equipo está gestionado, asegúrate de que está en un grupo de exclusión para evitar que las políticas sobrescriban los cambios.
    3. **Acción del script:**  
       - Comprueba si Hyper-V y su interfaz gráfica están habilitados.
       - Si no lo están, los habilita automáticamente.
       - Programa un reinicio del equipo en 5 minutos para completar la instalación.
    4. **Advertencia importante:**  
       El script forzará el reinicio del equipo en 5 minutos.  
       **Guarda tu trabajo antes de ejecutarlo.**

.EJEMPLO DE USO
    .\Script - Hyper-V - Habilitar caracteristica Hyper-V.ps1

.NOTAS
    - Revisa y ajusta el script según tu entorno antes de desplegarlo masivamente.
    - Puedes usarlo como Platform Script en Intune o ejecutarlo manualmente.
#>


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

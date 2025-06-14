<#
Este script automatiza la habilitación de la característica **Microsoft Hyper-V** (incluyendo la consola de administración gráfica, GUI) en sistemas Windows compatibles.

**Consideraciones y requisitos:**

1. **Permisos de Administrador:**  
   Este script requiere ser ejecutado con privilegios de administrador.

2. **Entornos gestionados (Intune u otros):**  
   Si el dispositivo está gestionado por **Intune** u otra herramienta de administración, asegúrate de que el equipo esté incluido en un grupo de exclusión para evitar que las políticas de configuración sobrescriban los cambios realizados por el script.

3. **Acción del script:**  
   - Comprueba si Hyper-V y su interfaz gráfica (Hyper-V GUI) están habilitados.
   - Si no lo están, procede a habilitarlos automáticamente.
   - Programa un reinicio del equipo en 5 minutos para completar la instalación de Hyper-V.

4. **Advertencia importante:**  
   El script forzará el reinicio del equipo en 5 minutos después de ejecutarse.  
   **Asegúrate de guardar tu trabajo antes de ejecutar este script.**

5. **Uso:**
    Puedes desplegarlo como un PlatformScript en Microsoft Intune

**Nota:**  
Revisa el script y ajusta los parámetros según las necesidades de tu entorno antes de desplegarlo masivamente.

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

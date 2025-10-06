<#
=====================================================================================================
    REMEDIATION SCRIPT: CREAR O AJUSTAR LA TAREA "ScheduledTask-Inkoova-CleanUpdates"
-----------------------------------------------------------------------------------------------------
Este script instala y configura el idioma **en-US** como UI de Windows, mantiene formatos regionales
en **es-ES**, y ajusta el teclado a Español (España). Está orientado a Intune Proactive Remediations.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Ejecución con privilegios SYSTEM o administrador local.
- Acceso a Windows Update para descargar paquetes de idioma/capacidades.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Usa Install-Language para instalar el paquete de idioma en-US.
- Instala capacidades adicionales (Basic, OCR, Speech, TTS, Handwriting).
- Configura UI en inglés (US).
- Configura formatos de España (es-ES).
- Configura teclado único en Español (España).
- Copia configuraciones a Welcome Screen y nuevas cuentas.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Configuración aplicada correctamente.
- "NOK" (exit code 1) → Error en instalación o configuración de idioma.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

$want = "en-US"

# 1) Instalar paquete de idioma desde Windows Update
try {
    Install-Language -Language $want -ErrorAction Stop
} catch {
    Write-Error "Error instalando el paquete de idioma $want $_"
    exit 1
}

# 2) Instalar capacidades adicionales
$caps = @(
  "Language.Basic~~~en-US~0.0.1.0",
  "Language.Handwriting~~~en-US~0.0.1.0",
  "Language.OCR~~~en-US~0.0.1.0",
  "Language.Speech~~~en-US~0.0.1.0",
  "Language.TextToSpeech~~~en-US~0.0.1.0"
)
foreach ($c in $caps) {
    try { Add-WindowsCapability -Online -Name $c -ErrorAction SilentlyContinue | Out-Null } catch {}
}

# 3) Configuración de idioma y región
Set-WinSystemLocale en-US
Set-WinUILanguageOverride en-US
Set-Culture es-ES
Set-WinHomeLocation -GeoId 217

# 4) Teclado: solo Español (España - Tradicional)
$ll = New-WinUserLanguageList en-US
$ll[0].InputMethodTips.Clear()
$ll[0].InputMethodTips.Add("040a:0000040a")
Set-WinUserLanguageList $ll -Force

# 5) Copiar ajustes a pantalla de bienvenida y nuevas cuentas
try { Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true 2>$null } catch {}

exit 0

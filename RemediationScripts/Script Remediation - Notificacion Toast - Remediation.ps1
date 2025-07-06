Add-Type -AssemblyName System.Runtime.InteropServices

# Variables de título y mensaje (puedes cambiarlas aquí)
$title = "Notificaciones Inkoova"
$message = "Por favor, inicia OneDrive para sincronizar tus archivos."

# Parámetros generales
$shortcutName = "Notificaciones Inkoova"
$shortcutFileName = "$shortcutName.lnk"
$appUserModelId = $shortcutName
$targetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$shortcutPath = Join-Path $startMenuPath $shortcutFileName

# Controlar si mostrar hero image: 1 = sí, 0 = no
$useHeroImage = 1

# URLs imágenes para la notificación
$heroUrl = "https://staintunenaxvan.blob.core.windows.net/wallpapers/Inkoova_transparente.png"
$appLogoUrl = "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRoddcq6BuYr-FlC3x4JOuPv9rzMOjG1cksJw&s"
$heroPath = "$env:LOCALAPPDATA\Temp\heroimage.png"
$appLogoPath = "$env:LOCALAPPDATA\Temp\applogo.png"

function New-ShortcutWithAppId {
    param(
        [string]$shortcutPath,
        [string]$targetPath,
        [string]$appUserModelId
    )

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetPath
    # Usar icono por defecto de powershell.exe
    $shortcut.IconLocation = "$targetPath,0"
    $shortcut.Save()

    $csCode = @"
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

[ComImport]
[Guid("000214F9-0000-0000-C000-000000000046")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IShellLinkW
{
    void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszFile, int cchMaxPath, out IntPtr pfd, uint fFlags);
    void GetIDList(out IntPtr ppidl);
    void SetIDList(IntPtr pidl);
    void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszName, int cchMaxName);
    void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
    void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszDir, int cchMaxPath);
    void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
    void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszArgs, int cchMaxPath);
    void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
    void GetHotkey(out short pwHotkey);
    void SetHotkey(short wHotkey);
    void GetShowCmd(out int piShowCmd);
    void SetShowCmd(int iShowCmd);
    void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszIconPath, int cchIconPath, out int piIcon);
    void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
    void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, uint dwReserved);
    void Resolve(IntPtr hwnd, uint fFlags);
    void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
}

[ComImport]
[Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IPropertyStore
{
    void GetCount(out uint cProps);
    void GetAt(uint iProp, out PROPERTYKEY pkey);
    void GetValue(ref PROPERTYKEY key, out PROPVARIANT pv);
    void SetValue(ref PROPERTYKEY key, ref PROPVARIANT pv);
    void Commit();
}

[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct PROPERTYKEY
{
    public Guid fmtid;
    public uint pid;
}

[StructLayout(LayoutKind.Explicit)]
public struct PROPVARIANT
{
    [FieldOffset(0)]
    public ushort vt;
    [FieldOffset(8)]
    public IntPtr pointerValue;

    public static PROPVARIANT FromString(string val)
    {
        var pv = new PROPVARIANT();
        pv.vt = 31; // VT_LPWSTR
        pv.pointerValue = Marshal.StringToCoTaskMemUni(val);
        return pv;
    }

    public void Clear()
    {
        if (vt == 31 && pointerValue != IntPtr.Zero)
        {
            Marshal.FreeCoTaskMem(pointerValue);
            pointerValue = IntPtr.Zero;
        }
        vt = 0;
    }
}

public class ShortcutPropertySetter
{
    static readonly PROPERTYKEY PKEY_AppUserModel_ID = new PROPERTYKEY
    {
        fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"),
        pid = 5
    };

    public static void SetAppUserModelId(string shortcutPath, string appId)
    {
        var shellLink = (IShellLinkW)new CShellLink();
        var persistFile = (IPersistFile)shellLink;
        persistFile.Load(shortcutPath, 0);

        var propertyStore = (IPropertyStore)shellLink;
        PROPVARIANT propVariant = PROPVARIANT.FromString(appId);
        PROPERTYKEY key = PKEY_AppUserModel_ID;  // Copia local

        propertyStore.SetValue(ref key, ref propVariant);
        propertyStore.Commit();
        propVariant.Clear();

        persistFile.Save(shortcutPath, true);
    }
}

[ComImport]
[Guid("00021401-0000-0000-C000-000000000046")]
public class CShellLink
{
}
"@

    Add-Type -TypeDefinition $csCode -Language CSharp

    [ShortcutPropertySetter]::SetAppUserModelId($shortcutPath, $appUserModelId)
}

# Crear shortcut
Write-Output "Creando acceso directo..."
New-ShortcutWithAppId -shortcutPath $shortcutPath -targetPath $targetPath -appUserModelId $appUserModelId

# Esperar a que aparezca en Get-StartApps
Write-Output "Esperando a que la app aparezca en Get-StartApps..."
$maxWait = 30
$foundAppId = $null
for ($i = 0; $i -lt $maxWait; $i++) {
    $app = Get-StartApps | Where-Object Name -eq $shortcutName
    if ($app) {
        $foundAppId = $app.AppID
        break
    }
    Start-Sleep -Seconds 1
}

if (-not $foundAppId) {
    Write-Warning "No se encontró la app en Get-StartApps tras esperar $maxWait segundos."
    exit 1
}

Write-Output "AppID encontrado: $foundAppId"

# Descargar imágenes
Write-Output "Descargando imágenes..."
if (Test-Path $heroPath) { Remove-Item $heroPath -Force }
Invoke-WebRequest -Uri $heroUrl -OutFile $heroPath -ErrorAction Stop
if (Test-Path $appLogoPath) { Remove-Item $appLogoPath -Force }
Invoke-WebRequest -Uri $appLogoUrl -OutFile $appLogoPath -ErrorAction Stop

# Instalar BurntToast si falta
if (-not (Get-Module -ListAvailable -Name BurntToast)) {
    Install-Module BurntToast -Scope CurrentUser -Force -AllowClobber
}
Import-Module BurntToast -ErrorAction Stop

# Preparar parámetros notificación
$params = @{
    Text = @($title, $message)
    AppLogo = $appLogoPath
    AppId = $foundAppId
}

if ($useHeroImage -eq 1) {
    $params.HeroImage = $heroPath
}

# Mostrar notificación
Write-Output "Mostrando notificación..."
New-BurntToastNotification @params

# Limpiar: eliminar acceso directo y clave de registro
Write-Output "Eliminando acceso directo y AppID..."

if (Test-Path $shortcutPath) {
    Remove-Item $shortcutPath -Force
    Write-Output "Acceso directo eliminado."
}

$regPath = "HKCU:\Software\Classes\ActivatableClasses\PackageId\$appUserModelId"
if (Test-Path $regPath) {
    Remove-Item -Path $regPath -Recurse -Force
    Write-Output "Clave de registro eliminada."
}

Write-Output "Proceso completado."

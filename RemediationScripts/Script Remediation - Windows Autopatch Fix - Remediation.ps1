<#
===============================================================================================
     REMEDIACION: DESBLOQUEAR WINDOWS UPDATE / AUTOPATCH (INTUNE/POWERSHELL)
-----------------------------------------------------------------------------------------------
Este script corrige configuraciones de directiva en el registro que impiden la gestion por
Windows Autopatch, normalizando los valores a DWORD=0.

Claves objetivo:
    • HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DoNotConnectToWindowsUpdateInternetLocations
    • HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DisableWindowsUpdateAccess
    • HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate

Comportamiento:
    • Crea subclaves si faltan y establece cada valor en 0 (DWORD).
    • Exit 0 si queda corregido; Exit 1 si persisten valores != 0.

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suarez (@alexsf93)
===============================================================================================
#>

$ErrorActionPreference = 'Stop'

$targets = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate';    Name = 'DoNotConnectToWindowsUpdateInternetLocations' },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate';    Name = 'DisableWindowsUpdateAccess' },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'NoAutoUpdate' }
)

foreach ($t in $targets) {
    if (-not (Test-Path -LiteralPath $t.Path)) {
        New-Item -Path $t.Path -Force | Out-Null
    }
    try {
        New-ItemProperty -LiteralPath $t.Path -Name $t.Name -Value 0 -PropertyType DWord -Force | Out-Null
        Write-Output "Set $($t.Path)\$($t.Name) = 0"
    } catch {
        try {
            Remove-ItemProperty -LiteralPath $t.Path -Name $t.Name -ErrorAction Stop
            New-ItemProperty -LiteralPath $t.Path -Name $t.Name -Value 0 -PropertyType DWord -Force | Out-Null
            Write-Output "Recreated $($t.Path)\$($t.Name) = 0"
        } catch {
            Write-Output "ERROR setting $($t.Path)\$($t.Name): $($_.Exception.Message)"
        }
    }
}

$remaining = 0
foreach ($t in $targets) {
    try {
        $v = (Get-ItemProperty -LiteralPath $t.Path -Name $t.Name -ErrorAction Stop).$t.Name
        if ([int]$v -ne 0) { $remaining++ }
    } catch { }
}

if ($remaining -eq 0) {
    Write-Output "Remediacion completada."
    Exit 0
} else {
    Write-Output "Remediacion incompleta: hay valores != 0."
    Exit 1
}

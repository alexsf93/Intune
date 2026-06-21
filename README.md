# 🚀 Intune Script Repository

> **Colección centralizada de scripts de automatización, configuración y remediación para Microsoft Intune.**

Este repositorio alberga una biblioteca de scripts en **PowerShell y Bash** diseñados para facilitar la administración de dispositivos Windows, Linux y macOS en entornos corporativos. Incluye soluciones para despliegue de software, configuración de sistema, auditoría y corrección automática de problemas (Proactive Remediations).

---

## 📂 Estructura del Repositorio

### `📁 PlatformScripts`
Scripts de propósito general clasificados por sistema operativo. Ideales para despliegue de aplicaciones (Win32Apps), configuración inicial o tareas de mantenimiento.

- **Windows:** Scripts de PowerShell para configuración de OS, limpieza, Hyper-V, BitLocker, etc.
- **Linux:** Scripts Bash para Ubuntu/Debian (SSH, Firewall, VSCode, Updates).
- **macOS:** Scripts Bash para gestión de Firewall, renombrado de equipos y limpieza.

### `📁 RemediationScripts`
Conjunto de pares de scripts (**Detección** y **Remediación**) optimizados para **Intune Proactive Remediations**.

| Detección (`detection.ps1`) | Remediación (`remediation.ps1`) | Propósito |
| :--- | :--- | :--- |
| **Bloatware** | Desinstala Apps | Elimina software preinstalado no deseado de los dispositivos (Dropbox, Lenovo Now). |
| **Company Portal** | Instala Portal | Verifica la instalación del Portal de Empresa de Microsoft y crea los accesos directos necesarios. |
| **Device Renaming** | Renombra Equipo | Valida y renombra el equipo para cumplir con la nomenclatura estándar (NOMBRE + sufijo de Serial/UUID). |
| **DNS Config** | Corrige DNS | Asegura el uso de DNS corporativos o específicos (Google/Cloudflare). |
| **Intune Agent (IME)** | Actualiza IME | Compara la versión local de Intune Management Extension con la última oficial y la actualiza si está obsoleta. |
| **Language Packs** | Instala Idioma | Instala y configura el idioma inglés (en-US) como predeterminado en el sistema. |
| **OneDrive Startup** | Corrige Inicio | Asegura que OneDrive se inicie con Windows y configura SilentAccountConfig para M365. |
| **Power Plans** | Restaura Planes | Detecta e importa los planes de energía predeterminados de Windows (Equilibrado, Alto rendimiento, Economizador) si faltan. |
| **Scheduled Tasks** | Crea/Corrige Tarea | Garantiza que tareas críticas (limpieza de actualizaciones, actualización de software, escaneo Defender) existan y corran como SYSTEM. |
| **Security** | Configura Seguridad | Verifica Secure Boot, gestiona cuentas locales (deshabilita Administrator) y agrega el usuario primario a administradores. |
| **Timezone** | Ajusta Zona Horaria | Estandariza la zona horaria a *Romance Standard Time* y sincroniza reloj. |
| **Toast Notifications** | Muestra Notificación | Envía notificaciones Toast dinámicas interactivas a los usuarios utilizando BurntToast. |
| **Windows Autopatch** | Corrige Políticas | Identifica y elimina directivas del registro que bloquean el funcionamiento correcto de Windows Update / Autopatch. |
| **Windows Cleanup** | Limpia Espacio | Detecta y elimina archivos y carpetas residuales de actualizaciones anteriores de Windows para liberar almacenamiento. |
| **Winget Update** | Actualiza Software | Ejecuta actualizaciones silenciosas y desatendidas de software de terceros instalado mediante Winget. |

---

## 🚀 Uso en Microsoft Intune

### 1️⃣ Scripts de Plataforma (PlatformScripts)
1. Navega a **Devices** > **Scripts**.
2. Selecciona la plataforma (Windows, Linux o macOS).
3. Carga el archivo `.ps1` o `.sh` correspondiente.
4. Configura el contexto de ejecución (SYSTEM o Usuario verificado) según las notas del encabezado del script.

### 2️⃣ Remediaciones Proactivas (RemediationScripts)
1. Navega a **Reports** > **Endpoint analytics** > **Proactive remediations**.
2. Crea un nuevo paquete de script.
3. Carga el script de **Detección** y el de **Remediación** correspondientes.
4. Asigna los grupos de dispositivos y programa la frecuencia de ejecución (ej. diaria o cada hora).

---

## 🛠 Requisitos

- **Microsoft Intune** con licencias activas para administración de dispositivos.
- **Windows 10/11** con PowerShell 5.1+.
- **Ubuntu 20.04/22.04/24.04** (para scripts Linux).
- **macOS Big Sur (11.0)+** (para scripts macOS).
- Permisos de administrador o SYSTEM para la mayoría de las ejecuciones.

---

## 🤝 Contribuyendo

Las contribuciones son bienvenidas para mejorar y expandir esta biblioteca.
1. Haz un Fork del repositorio.
2. Crea una rama para tu característica (`git checkout -b feature/NuevaFuncionalidad`).
3. Asegúrate de incluir encabezados estándar en tus scripts.
4. Envía un Pull Request.

---

## 📄 Licencia y Autor

Desarrollado y mantenido por **Alejandro Suárez** ([@alexsf93](https://github.com/alexsf93)).
Este proyecto se distribuye bajo la licencia MIT. Siéntete libre de usarlo y adaptarlo a tus necesidades.

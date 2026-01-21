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
| **DNS Config** | Corrige DNS | Asegura el uso de DNS corporativos o específicos (Google/Cloudflare). |
| **Scheduled Tasks** | Crea/Corrige Tarea | Garantiza que tareas críticas (limpieza, escaneo Defender) existan y corran como SYSTEM. |
| **Timezone** | Ajusta Zona Horaria | Estandariza la zona horaria a *Romance Standard Time* y sincroniza reloj. |
| **Bloatware** | Desinstala Apps | Elimina software preinstalado no deseado (Dropbox, Lenovo Now). |
| **Security** | Configura Seguridad | Verifica Secure Boot, añade usuarios a administradores, deshabilita cuentas locales. |

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

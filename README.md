
### 📁 PlatformScripts
Scripts generales por sistema operativo, orientados a la **configuración, automatización y personalización** de los dispositivos administrados.

### 📁 RemediationScripts
Colección de **pares de scripts de Detección y Remediación** listos para usar en **Proactive Remediations de Intune**.  
Cada conjunto sigue la convención:

- `*-Detection.ps1` → Verifica si la condición está presente/no conforme.  
- `*-Remediation.ps1` → Corrige el problema en caso de detección.  

Ejemplos incluidos en este repositorio:
- 🔹 **Dropbox / Lenovo Now** → Detección y desinstalación silenciosa.  
- 🔹 **Archivos residuales de Windows Update** → Limpieza automática.  
- 🔹 **Secure Boot** → Registro y auditoría de estado.  
- 🔹 **Intune Management Extension (IME)** → Detección de versión y reinstalación.  
- 🔹 **Company Portal** → Instalación y creación de accesos directos.  
- 🔹 **Notificaciones personalizadas (Toast)** → Mensajes al usuario con BurntToast.  
- 🔹 **Planes de energía** → Restauración de configuraciones estándar.  
- 🔹 **Scheduled Tasks (limpieza y escaneo Defender)** → Creación y validación de tareas programadas.  
- 🔹 **Zona horaria y sincronización** → Configuración de "Romance Standard Time".  
- 🔹 **Windows Autopatch** → Detección y corrección de políticas bloqueantes.  

---

## 🎯 Propósito

Este repositorio busca ser un **catálogo reutilizable de buenas prácticas en Intune**, proporcionando:

- ✅ Scripts listos para integrar en **Win32Apps**.  
- ✅ **Detección y remediación automatizada** con Intune Proactive Remediations.  
- ✅ Plantillas claras para crear nuevas soluciones personalizadas.  

---

## 🛠️ Requisitos

- **Microsoft Intune** para la gestión centralizada.  
- **PowerShell 5.1 o superior** (compatibles con PowerShell 7.x).  
- Ejecución con permisos adecuados (**SYSTEM** en la mayoría de remediaciones).  

---

## 👨‍💻 Autor

**Alejandro Suárez (@alexsf93)**  
Repositorio mantenido con el objetivo de compartir **scripts reutilizables y probados en entornos reales** de administración con Microsoft Intune.

---

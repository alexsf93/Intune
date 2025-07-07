#!/bin/bash
# ===============================================================
#      Script: Verificar, instalar y habilitar UFW en Linux
# ---------------------------------------------------------------
#      Autor: Alejandro Suárez (@alexsf93)
# ===============================================================
#
# DESCRIPCIÓN:
#     Verifica si el firewall UFW está instalado en el sistema Linux.
#     Si no está instalado, lo instala automáticamente.
#     Si no está habilitado, configura las reglas básicas y lo habilita.
#
# INSTRUCCIONES DE USO:
#     1. Ejecuta este script como root (o con sudo) en la máquina objetivo.
#     2. Es compatible con múltiples gestores de paquetes (apt, dnf, yum, pacman, zypper).
#     3. Ideal para despliegue mediante Microsoft Intune en entornos mixtos de Linux.
#
# NOTAS:
#     - Permite conexiones SSH antes de habilitar UFW para no perder acceso remoto.
#     - Puedes agregar más reglas personalizadas según tus necesidades.
#     - Muestra el estado final del firewall tras la ejecución.
#
# ===============================================================

echo "Verificando UFW..."

# Comprobar si UFW está instalado
if ! command -v ufw &> /dev/null; then
    echo "UFW no está instalado. Instalando..."
    
    # Detectar el gestor de paquetes del sistema
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y ufw
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y ufw
    elif command -v yum &> /dev/null; then
        sudo yum install -y ufw
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm ufw
    elif command -v zypper &> /dev/null; then
        sudo zypper install -y ufw
    else
        echo "No se pudo detectar el gestor de paquetes. Por favor, instala UFW manualmente."
        exit 1
    fi
    
    echo "UFW ha sido instalado correctamente."
else
    echo "UFW ya está instalado."
fi

# Comprobar si UFW está habilitado
if ! sudo ufw status | grep -q "Status: active"; then
    echo "UFW no está habilitado. Habilitando..."
    
    # Configuración básica antes de habilitar
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh  # Para evitar perder acceso SSH
    
    # Habilitar UFW
    echo "y" | sudo ufw enable
    
    echo "UFW ha sido habilitado correctamente."
else
    echo "UFW ya está habilitado."
fi

echo "Proceso completado. Estado actual de UFW:"
sudo ufw status

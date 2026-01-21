#!/bin/bash

# ==============================================================================
# Nombre:       Script - Check UFW.sh
# Descripción:  Verifica si el firewall UFW está instalado en el sistema Linux.
#               Si no está instalado, lo instala automáticamente.
#               Si no está habilitado, configura las reglas básicas y lo habilita.
# Autor:        Alejandro Suárez (@alexsf93)
# Versión:      1.0.0
# Uso:          ./Script - Check UFW.sh
# Notas:        Permite conexiones SSH antes de habilitar UFW. Compatible con apt, dnf, yum, pacman, zypper.
# ==============================================================================

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

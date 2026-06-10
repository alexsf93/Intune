#!/bin/bash
# ==============================================================================
# Nombre:        Configurar-Edge-Dock.sh
# Descripción:   Añade Microsoft Edge al Dock de macOS de forma nativa
#                y lo posiciona automáticamente al lado de Safari.
# Autor:         Alejandro Suárez
# Versión:       1.0.0
# Uso:           ./Configurar-Edge-Dock.sh
# Notas:         Se ejecuta en el contexto del usuario conectado. No requiere
#                herramientas de terceros (como dockutil) ni Python.
# ==============================================================================

APP_PATH="/Applications/Microsoft Edge.app"
APP_NAME="Microsoft Edge"
DOCK_PLIST="$HOME/Library/Preferences/com.apple.dock.plist"

# 1. Comprobar si Microsoft Edge está instalado
if [ -d "$APP_PATH" ]; then

    # 2. Comprobar si ya existe en el Dock para evitar duplicados
    if plutil -extract "persistent-apps" xml1 -o - "$DOCK_PLIST" | grep -q "$APP_NAME"; then
        echo "Microsoft Edge ya está en el Dock."
    else
        echo "Añadiendo y ordenando Microsoft Edge al lado de Safari..."
        
        # Estructura XML nativa que requiere el Dock de Apple
        XML_ENTRY="<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$APP_PATH</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
        
        # 3. Inyectar la entrada exactamente en el índice 1 (segundo lugar del Dock)
        plutil -insert "persistent-apps.1" -xml "$XML_ENTRY" "$DOCK_PLIST"
        
        # 4. Forzar al sistema a sincronizar los cambios
        defaults read com.apple.dock > /dev/null
        
        # 5. Reiniciar el Dock para aplicar los cambios en pantalla
        killall Dock
        echo "¡Logrado! Edge posicionado correctamente."
    fi
else
    echo "Error: Microsoft Edge no se encuentra en /Applications."
fi

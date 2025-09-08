#!/bin/bash
# ===============================================================
#      Script: Script - Full cleanup (para updates) (macOS)
# ---------------------------------------------------------------
#      Autor: Alejandro Suárez (@alexsf93)
# ===============================================================
#
# DESCRIPCIÓN:
#     Limpia silenciosamente en macOS únicamente artefactos de
#     actualizaciones obsoletos y recreables:
#       - Descargas de softwareupdate en /Library/Updates
#       - Caches de softwareupdate bajo /private/var/folders
#       - Caches de softwareupdate por usuario (si existieran)
#     Se ejecuta mediante una tarea temporal (LaunchDaemon one-shot)
#     Tras completar, también elimina el binario auxiliar que se autocopia.
#
# INSTRUCCIONES DE USO:
#     1. Guarda este archivo exactamente con el nombre:
#          Script - Full cleanup (para updates)
#     2. Concede permisos de ejecución:
#          chmod +x "Script - Full cleanup (para updates)"
#     3. Ejecútalo como root (instala y lanza la tarea one-shot):
#          sudo "./Script - Full cleanup (para updates)"
#     4. Para ejecutar la limpieza directamente (sin crear tarea):
#          sudo "./Script - Full cleanup (para updates)" --run
#
# NOTAS:
#     - Log de la limpieza:
#         /var/log/cleanup_macos.log
#     - Logs del LaunchDaemon:
#         /var/log/inkoova_cleanup.stdout.log
#         /var/log/inkoova_cleanup.stderr.log
#     - Compatible con macOS 11+ (Big Sur o superior).
#     - No modifica recibos ni preferencias del sistema.
#
# ===============================================================

set -euo pipefail

# LOG
CLEAN_LOG="/var/log/cleanup_macos.log"
Write-Log() {
  local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] $*" | tee -a "$CLEAN_LOG" >/dev/null
}

# Comprobación de root
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Este script debe ejecutarse con sudo/root." >&2
  exit 1
fi

# Rutas y constantes
TARGET_DIR="/usr/local/sbin"
TARGET_BIN="${TARGET_DIR}/inkoova_updates_cleanup.sh"
PLIST_DIR="/Library/LaunchDaemons"
STDOUT_LOG="/var/log/inkoova_cleanup.stdout.log"
STDERR_LOG="/var/log/inkoova_cleanup.stderr.log"

# Limpieza de updates (modo --run)
Do-UpdatesCleanup() {
  local label="${1:-}"
  local plist="${2:-}"

  Write-Log "== Inicio de limpieza de updates obsoletos =="

  # /Library/Updates
  Write-Log "Eliminando descargas en /Library/Updates ..."
  if [[ -d /Library/Updates ]]; then
    rm -rf /Library/Updates/* /Library/Updates/.[!.]* /Library/Updates/..?* 2>/dev/null || true
  fi

  # Caches de softwareupdate en /private/var/folders
  Write-Log "Purgando caches com.apple.SoftwareUpdate* en /private/var/folders ..."
  find /private/var/folders -type d \( \
      -name "com.apple.SoftwareUpdate" -o \
      -name "com.apple.SoftwareUpdateNotifications" -o \
      -name "com.apple.SoftwareUpdateCache" \
    \) -prune -exec rm -rf {} + 2>/dev/null || true

  # Caches por usuario relacionadas con softwareupdate
  Write-Log "Limpiando caches de softwareupdate por usuario (si existen) ..."
  for home in /Users/*; do
    [[ -d "$home/Library" ]] || continue
    rm -rf "$home/Library/Updates/"* "$home/Library/Updates/".[!.]* "$home/Library/Updates/".??* 2>/dev/null || true
    find "$home/Library/Caches" -maxdepth 1 -type d -name "*SoftwareUpdate*" -exec rm -rf {} + 2>/dev/null || true
  done

  # Resumen
  Write-Log "Resumen de volúmenes montados:"
  df -h | tee -a "$CLEAN_LOG" >/dev/null

  Write-Log "== Limpieza de updates completada =="

  # Autodesregistro LaunchDaemon
  if [[ -n "$label" || -n "$plist" ]]; then
    Write-Log "Desregistrando LaunchDaemon temporal..."
    if [[ -n "$plist" && -f "$plist" ]]; then
      launchctl bootout system "$plist" >/dev/null 2>&1 || true
    fi
    if [[ -n "$label" ]]; then
      launchctl remove "$label" >/dev/null 2>&1 || true
    fi
    if [[ -n "$plist" && -f "$plist" ]]; then
      rm -f "$plist" || true
      Write-Log "Eliminado $plist"
    fi
  fi

  # Autoeliminación del binario auxiliar
  if [[ -f "$TARGET_BIN" ]]; then
    Write-Log "Eliminando binario auxiliar: $TARGET_BIN"
    rm -f "$TARGET_BIN" || true
  fi
}

# Instalación y lanzamiento (por defecto)
Install-And-Launch() {
  mkdir -p "$TARGET_DIR"
  cp "$0" "$TARGET_BIN.new"
  chown root:wheel "$TARGET_BIN.new"
  chmod 0755 "$TARGET_BIN.new"
  mv -f "$TARGET_BIN.new" "$TARGET_BIN"

  local uuid; uuid="$(uuidgen | tr 'A-Z' 'a-z')"
  local label="com.inkoova.cleanup.updates.${uuid}"
  local plist="${PLIST_DIR}/${label}.plist"

  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>${label}</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/bash</string>
      <string>${TARGET_BIN}</string>
      <string>--run</string>
      <string>--label</string>
      <string>${label}</string>
      <string>--plist</string>
      <string>${plist}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>UserName</key>
    <string>root</string>
    <key>StandardOutPath</key>
    <string>${STDOUT_LOG}</string>
    <key>StandardErrorPath</key>
    <string>${STDERR_LOG}</string>
    <key>ProcessType</key>
    <string>Background</string>
  </dict>
</plist>
EOF

  chown root:wheel "$plist"
  chmod 0644 "$plist"

  launchctl bootstrap system "$plist"

  echo "Tarea temporal creada y lanzada:"
  echo "  Label:  $label"
  echo "  Plist:  $plist"
  echo "  Logs:   $STDOUT_LOG / $STDERR_LOG"
  echo "Se autodesinstalará al finalizar y eliminará el binario auxiliar."
}

# Parseo de argumentos
MODE="install"
LABEL_ARG=""
PLIST_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run)   MODE="run"; shift ;;
    --label) LABEL_ARG="${2:-}"; shift 2 ;;
    --plist) PLIST_ARG="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

# Ejecución
if [[ "$MODE" == "run" ]]; then
  Do-UpdatesCleanup "$LABEL_ARG" "$PLIST_ARG"
else
  Install-And-Launch
fi

exit 0

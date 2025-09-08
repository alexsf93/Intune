#!/bin/bash
# ===============================================================
#      Script: Script - Full cleanup (para updates) (Linux)
# ---------------------------------------------------------------
#      Autor: Alejandro Suárez (@alexsf93)
# ===============================================================
#
# DESCRIPCIÓN:
#     Limpia silenciosamente en Linux únicamente artefactos
#     de actualizaciones obsoletos y recreables:
#       - Cachés/descargas de gestores de paquetes (APT/DNF/YUM/
#         Zypper/Pacman/APK) y metadatos de PackageKit
#       - Revisiones antiguas de Snap y Flatpak sin uso
#       - Journal de systemd (vacuum prudente)
#     Crea una tarea temporal one-shot:
#       - Preferencia: 'systemd-run' TRANSIENTE (no deja unidad en disco)
#       - Alternativa: unidad .service temporal en /etc/systemd/system
#       - Sin systemd: ejecuta limpieza directa
#     Tras completar, elimina el binario auxiliar y (si aplica) la unidad.
#
# INSTRUCCIONES DE USO:
#     1. Guarda este archivo con el nombre que desees, por ejemplo:
#          Script - Full cleanup (para updates) (Linux)
#     2. Concede permisos de ejecución:
#          chmod +x "Script - Full cleanup (para updates) (Linux)"
#     3. Ejecútalo como root (instala y lanza tarea one-shot):
#          sudo "./Script - Full cleanup (para updates) (Linux)"
#     4. Para ejecutar la limpieza directamente (sin crear tarea):
#          sudo "./Script - Full cleanup (para updates) (Linux)" --run
#
# NOTAS:
#     - Log de la limpieza:
#         /var/log/cleanup_linux_updates.log
#     - Con systemd puedes ver salida con:
#         journalctl -u com.inkoova.cleanup.updates.<uuid>.service
#     - Por diseño, sólo se toca contenido recreable de updates.
#
# ===============================================================

set -euo pipefail

# LOG
CLEAN_LOG="/var/log/cleanup_linux_updates.log"
WRITE_LOG=1
Write-Log() {
  if [[ "${WRITE_LOG}" -eq 1 ]]; then
    local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] $*" | tee -a "$CLEAN_LOG" >/dev/null
  fi
}

# Comprobación de root
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Este script debe ejecutarse con sudo/root." >&2
  exit 1
fi

# Rutas y constantes
TARGET_DIR="/usr/local/sbin"
TARGET_BIN="${TARGET_DIR}/inkoova_updates_cleanup_linux.sh"
SYSTEMD_DIR="/etc/systemd/system"

# Utilidades
have() { command -v "$1" >/dev/null 2>&1; }

# Limpieza de updates (modo --run)
Do-UpdatesCleanup() {
  local unit_name="${1:-}"
  local unit_path="${2:-}"

  Write-Log "== Inicio de limpieza de updates obsoletos =="

  # APT (Debian/Ubuntu)
  if have apt-get; then
    Write-Log "APT: autoremove/autoclean/clean..."
    DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge 2>/dev/null || true
    DEBIAN_FRONTEND=noninteractive apt-get -y autoclean 2>/dev/null || true
    DEBIAN_FRONTEND=noninteractive apt-get -y clean 2>/dev/null || true
    rm -rf /var/lib/apt/lists/partial/* /var/cache/apt/archives/partial/* 2>/dev/null || true
  fi

  # DNF (Fedora/RHEL8+)
  if have dnf; then
    Write-Log "DNF: autoremove y clean all..."
    dnf -y autoremove 2>/dev/null || true
    dnf -y clean all 2>/dev/null || true
  fi

  # YUM (RHEL/CentOS 7)
  if have yum; then
    Write-Log "YUM: clean all y orfandades..."
    yum -y clean all 2>/dev/null || true
    if have package-cleanup; then
      package-cleanup --oldkernels --count=2 -y 2>/dev/null || true
    fi
    yum -y autoremove 2>/dev/null || true
  fi

  # Zypper (openSUSE/SLES)
  if have zypper; then
    Write-Log "Zypper: clean --all y orfandades..."
    zypper --non-interactive clean --all 2>/dev/null || true
    zypper --non-interactive packages --orphaned 2>/dev/null | awk 'NR>2 {print $3}' | xargs -r zypper --non-interactive rm -u 2>/dev/null || true
    if have purge-kernels; then purge-kernels --keep-last 2>/dev/null || true; fi
  fi

  # Pacman (Arch/Manjaro)
  if have pacman; then
    Write-Log "Pacman: paccache y huérfanos..."
    if have paccache; then
      paccache -r 2>/dev/null || true
      paccache -rk 1 2>/dev/null || true
    else
      pacman -Scc --noconfirm 2>/dev/null || true
    fi
    if pacman -Qtdq >/dev/null 2>&1; then
      pacman -Qtdq | xargs -r pacman -Rns --noconfirm 2>/dev/null || true
    fi
  fi

  # APK (Alpine)
  if have apk; then
    Write-Log "APK: cache clean..."
    apk cache clean 2>/dev/null || true
  fi

  # PackageKit (si existe)
  if [[ -d /var/cache/PackageKit ]]; then
    Write-Log "PackageKit: purgando cache..."
    rm -rf /var/cache/PackageKit/* 2>/dev/null || true
  fi

  # Snap (eliminar revisiones antiguas deshabilitadas)
  if have snap; then
    Write-Log "Snap: eliminando revisiones deshabilitadas..."
    snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | while read -r name rev; do
      snap remove "$name" --revision="$rev" 2>/dev/null || true
    done
  fi

  # Flatpak (apps/runtimes sin uso)
  if have flatpak; then
    Write-Log "Flatpak: uninstall --unused..."
    flatpak uninstall --unused -y 2>/dev/null || true
  fi

  # Journal de systemd (conserva 7 días)
  if have journalctl; then
    Write-Log "Journal: vacuum-time=7d..."
    journalctl --vacuum-time=7d 2>/dev/null || true
  fi

  # Resumen de espacio
  Write-Log "Resumen de volúmenes montados:"
  df -h | tee -a "$CLEAN_LOG" >/dev/null

  Write-Log "== Limpieza de updates completada =="

  # Autodesregistro systemd (si se creó una unidad .service)
  if [[ -n "$unit_name" || -n "$unit_path" ]]; then
    Write-Log "Desregistrando servicio temporal systemd..."
    if have systemctl; then
      systemctl stop "$unit_name" >/dev/null 2>&1 || true
      systemctl disable "$unit_name" >/dev/null 2>&1 || true
      systemctl reset-failed "$unit_name" >/dev/null 2>&1 || true
    fi
    if [[ -n "$unit_path" && -f "$unit_path" ]]; then
      rm -f "$unit_path" || true
      Write-Log "Eliminado $unit_path"
      have systemctl && systemctl daemon-reload || true
    fi
  fi

  # Autoeliminación del binario auxiliar
  if [[ -f "$TARGET_BIN" ]]; then
    Write-Log "Eliminando binario auxiliar: $TARGET_BIN"
    rm -f "$TARGET_BIN" || true
  fi

  # Eliminar log si se pidió no dejar rastro (WRITE_LOG=0)
  if [[ "${WRITE_LOG}" -eq 0 && -f "$CLEAN_LOG" ]]; then
    rm -f "$CLEAN_LOG" || true
  fi
}

# Instalación y lanzamiento (por defecto)
Install-And-Launch() {
  mkdir -p "$TARGET_DIR"
  cp "$0" "$TARGET_BIN.new"
  chown root:root "$TARGET_BIN.new"
  chmod 0755 "$TARGET_BIN.new"
  mv -f "$TARGET_BIN.new" "$TARGET_BIN"

  # Preferencia: systemd-run TRANSIENTE (no crea archivos de unidad)
  if have systemd-run; then
    local uuid; uuid="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen || echo $$)"
    local unit="com.inkoova.cleanup.updates.${uuid}"
    # --collect asegura que la unidad se recoja al terminar; no deja rastro
    systemd-run --unit "${unit}" --collect \
      -p Type=oneshot -p RemainAfterExit=no -p Nice=10 \
      /bin/bash "${TARGET_BIN}" --run >/dev/null 2>&1 || true

    echo "Tarea temporal lanzada (systemd-run transiente):"
    echo "  Unidad: ${unit}"
    echo "  Log:    $CLEAN_LOG"
    echo "Se autodestruirá al finalizar (sin archivo .service)."
    return
  fi

  # Alternativa: systemctl con archivo .service temporal
  if have systemctl && [[ -d "$SYSTEMD_DIR" ]]; then
    local uuid; uuid="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen || echo $$)"
    local unit_name="com.inkoova.cleanup.updates.${uuid}.service"
    local unit_path="${SYSTEMD_DIR}/${unit_name}"

    cat > "$unit_path" <<EOF
[Unit]
Description=Inkoova - Limpieza de updates (one-shot) - ${uuid}
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash ${TARGET_BIN} --run --unit ${unit_name} --unit-path ${unit_path}
Nice=10
NoNewPrivileges=yes
ProtectSystem=full
PrivateTmp=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    chmod 0644 "$unit_path"
    systemctl daemon-reload
    systemctl enable --now "$unit_name"

    echo "Tarea temporal creada y lanzada:"
    echo "  Unidad: $unit_name"
    echo "  Ruta:   $unit_path"
    echo "  Log:    $CLEAN_LOG"
    echo "Se autodesinstalará al finalizar y eliminará el binario auxiliar."
    return
  fi

  # Sin systemd: ejecutar limpieza directa
  Write-Log "Systemd no disponible: ejecutando limpieza directa..."
  Do-UpdatesCleanup "" ""
}

# Parseo de argumentos
MODE="install"
UNIT_ARG=""
UNIT_PATH_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) MODE="run"; shift ;;
    --unit) UNIT_ARG="${2:-}"; shift 2 ;;
    --unit-path) UNIT_PATH_ARG="${2:-}"; shift 2 ;;
    --no-log) WRITE_LOG=0; shift ;;
    *) shift ;;
  esac
done

# Ejecución
if [[ "$MODE" == "run" ]]; then
  Do-UpdatesCleanup "$UNIT_ARG" "$UNIT_PATH_ARG"
else
  Install-And-Launch
fi

exit 0

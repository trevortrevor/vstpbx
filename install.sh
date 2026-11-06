#!/bin/bash
set -e

echo "============================================"
echo "  VstPBX Installer"
echo "============================================"
echo ""

# Language selection (installer + web UI default)
echo "Sprache / Language:"
echo "  [1] Deutsch"
echo "  [2] English"
read -rp "Auswahl / Choice [1]: " UI_LANG_CHOICE
if [ "$UI_LANG_CHOICE" = "2" ]; then
    UI_LANG="en"
else
    UI_LANG="de"
fi
INSTALL_LANG="$UI_LANG"
echo ""

# Check if user can run Docker (root or docker group)
if ! docker info >/dev/null 2>&1; then
    if [ "$INSTALL_LANG" = "de" ]; then
        echo "FEHLER: Keine Verbindung zu Docker moeglich."
        echo "        Bitte als root ausfuehren oder Benutzer zur docker-Gruppe hinzufuegen:"
        echo "        sudo usermod -aG docker \$USER"
    else
        echo "ERROR: Cannot connect to Docker."
        echo "       Run as root or add your user to the docker group:"
        echo "       sudo usermod -aG docker \$USER"
    fi
    exit 1
fi

# Check prerequisites
if ! command -v docker >/dev/null 2>&1; then
    if [ "$INSTALL_LANG" = "de" ]; then
        echo "FEHLER: docker ist nicht installiert."
    else
        echo "ERROR: docker is not installed."
    fi
    exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
    if [ "$INSTALL_LANG" = "de" ]; then
        echo "FEHLER: docker compose ist nicht verfuegbar."
    else
        echo "ERROR: docker compose is not available."
    fi
    exit 1
fi

ensure_fail2ban() {
    if [ ! -f /var/lib/fail2ban/fail2ban.sqlite3 ]; then
        echo ""
        if [ "$INSTALL_LANG" = "de" ]; then
            echo "FEHLER: Die fail2ban-Datenbank (/var/lib/fail2ban/fail2ban.sqlite3) wurde nicht gefunden."
            echo "        Bitte installiere und starte fail2ban, bevor du das Skript erneut ausfuehrst:"
            echo "        sudo apt install -y fail2ban && sudo systemctl enable --now fail2ban"
        else
            echo "ERROR: The fail2ban database (/var/lib/fail2ban/fail2ban.sqlite3) was not found."
            echo "       Please install and start fail2ban before rerunning this script:"
            echo "       sudo apt install -y fail2ban && sudo systemctl enable --now fail2ban"
        fi
        exit 1
    fi
    if [ ! -S /var/run/fail2ban/fail2ban.sock ] && [ ! -e /var/run/fail2ban/fail2ban.sock ]; then
        echo ""
        if [ "$INSTALL_LANG" = "de" ]; then
            echo "FEHLER: Der fail2ban-Socket (/var/run/fail2ban/fail2ban.sock) wurde nicht gefunden."
            echo "        Bitte installiere und starte fail2ban, bevor du das Skript erneut ausfuehrst:"
            echo "        sudo apt install -y fail2ban && sudo systemctl enable --now fail2ban"
        else
            echo "ERROR: The fail2ban socket (/var/run/fail2ban/fail2ban.sock) was not found."
            echo "       Please install and start fail2ban before rerunning this script:"
            echo "       sudo apt install -y fail2ban && sudo systemctl enable --now fail2ban"
        fi
        exit 1
    fi
}

ensure_fail2ban

if [ "$INSTALL_LANG" = "de" ]; then
    echo "[OK] Docker, Docker Compose und fail2ban gefunden."
else
    echo "[OK] Docker, Docker Compose, and fail2ban found."
fi
echo ""

# --- Check for existing installation ---
FRESH_INSTALL=true

if [ -f .env ]; then
    if [ "$INSTALL_LANG" = "de" ]; then
        echo "Bestehende Installation gefunden."
        echo ""
        echo "  [1] Update - Code aktualisieren, Daten und Passwoerter behalten"
        echo "  [2] Neu    - Alles loeschen und komplett neu installieren"
        echo ""
        read -rp "Auswahl [1]: " INSTALL_MODE
    else
        echo "Existing installation found."
        echo ""
        echo "  [1] Update    - Update code, keep data and passwords"
        echo "  [2] Reinstall - Delete everything and perform a clean install"
        echo ""
        read -rp "Choice [1]: " INSTALL_MODE
    fi

    if [ "$INSTALL_MODE" = "2" ]; then
        echo ""
        if [ "$INSTALL_LANG" = "de" ]; then
            echo "ACHTUNG: Alle Daten (Nebenstellen, Trunks, Anrufverlauf) werden geloescht!"
            read -rp "Wirklich alles loeschen? [j/N]: " CONFIRM_DELETE
        else
            echo "WARNING: All data (extensions, trunks, call history) will be deleted!"
            read -rp "Really delete everything? [y/N]: " CONFIRM_DELETE
        fi
        if [ "$CONFIRM_DELETE" = "j" ] || [ "$CONFIRM_DELETE" = "J" ] || [ "$CONFIRM_DELETE" = "y" ] || [ "$CONFIRM_DELETE" = "Y" ]; then
            if [ "$INSTALL_LANG" = "de" ]; then
                echo "Stoppe Container und loesche Daten..."
            else
                echo "Stopping containers and deleting data..."
            fi
            docker compose down -v 2>/dev/null || true
            rm -f .env asterisk/config/manager.conf
            if [ "$INSTALL_LANG" = "de" ]; then
                echo "[OK] Alte Installation entfernt"
            else
                echo "[OK] Previous installation removed"
            fi
            FRESH_INSTALL=true
        else
            if [ "$INSTALL_LANG" = "de" ]; then
                echo "Abgebrochen."
            else
                echo "Aborted."
            fi
            exit 0
        fi
    else
        # --- Update mode ---
        echo ""
        if [ "$INSTALL_LANG" = "de" ]; then
            echo "Aktualisiere VstPBX..."
        else
            echo "Updating VstPBX..."
        fi

        # Source existing env values
        # shellcheck disable=SC1091
        . ./.env

        # Regenerate manager.conf with existing AMI password
        sed "s/%%AMI_PASSWORD%%/${AMI_PASSWORD}/" asterisk/config/manager.conf.template > asterisk/config/manager.conf
        if [ "$INSTALL_LANG" = "de" ]; then
            echo "[OK] manager.conf aktualisiert"
        else
            echo "[OK] manager.conf updated"
        fi

        # Ensure fail2ban paths exist
        ensure_fail2ban

        echo ""
        if [ "$INSTALL_LANG" = "de" ]; then
            echo "Starte Container neu..."
        else
            echo "Restarting containers..."
        fi
        docker pull docker:cli >/dev/null 2>&1 &
        docker compose up -d --build

        # Detect local LAN IP
        LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")

        echo ""
        echo "============================================"
        if [ "$INSTALL_LANG" = "de" ]; then
            echo "  VstPBX Update abgeschlossen!"
        else
            echo "  VstPBX Update Complete!"
        fi
        echo "============================================"
        echo ""
        if [ "$BIND_ADDRESS" = "0.0.0.0" ] && [ -n "$LOCAL_IP" ]; then
            echo "  Web GUI:    http://${LOCAL_IP}:3000"
        else
            echo "  Web GUI:    http://localhost:3000"
        fi
        echo ""
        if [ "$INSTALL_LANG" = "de" ]; then
            echo "  Zugangsdaten unveraendert (siehe .env)"
        else
            echo "  Credentials unchanged (see .env)"
        fi
        echo "============================================"
        exit 0
    fi
fi

# --- Fresh installation ---

# Detect external IP
if [ "$INSTALL_LANG" = "de" ]; then
    echo "Ermittle externe IP-Adresse..."
else
    echo "Detecting external IP address..."
fi
DETECTED_IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || curl -4 -s --max-time 5 icanhazip.com 2>/dev/null || echo "")

if [ -n "$DETECTED_IP" ]; then
    if [ "$INSTALL_LANG" = "de" ]; then
        echo "Erkannte externe IP: $DETECTED_IP"
        read -rp "Diese IP verwenden? [J/n]: " USE_DETECTED
    else
        echo "Detected external IP: $DETECTED_IP"
        read -rp "Use this IP? [Y/n]: " USE_DETECTED
    fi
    if [ "$USE_DETECTED" = "n" ] || [ "$USE_DETECTED" = "N" ]; then
        if [ "$INSTALL_LANG" = "de" ]; then
            read -rp "Externe IP eingeben: " EXTERNAL_IP
        else
            read -rp "Enter external IP: " EXTERNAL_IP
        fi
    else
        EXTERNAL_IP="$DETECTED_IP"
    fi
else
    if [ "$INSTALL_LANG" = "de" ]; then
        echo "Externe IP konnte nicht automatisch ermittelt werden."
        read -rp "Externe IP eingeben: " EXTERNAL_IP
    else
        echo "Could not detect external IP automatically."
        read -rp "Enter external IP: " EXTERNAL_IP
    fi
fi

# Detect local LAN IP
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")

echo ""

# Network mode
if [ "$INSTALL_LANG" = "de" ]; then
    echo "Nutzt du einen Reverse Proxy (z.B. Nginx) vor VstPBX?"
    echo "  [1] Nein  - Direkter Zugriff aus dem Netzwerk (empfohlen fuer Heimnetz)"
    echo "  [2] Ja    - Zugriff nur ueber localhost/Reverse Proxy"
    read -rp "Auswahl [1]: " PROXY_CHOICE
else
    echo "Are you using a reverse proxy (e.g. Nginx) in front of VstPBX?"
    echo "  [1] No   - Direct access from the network (recommended for LAN/home use)"
    echo "  [2] Yes  - Access only via localhost/reverse proxy"
    read -rp "Choice [1]: " PROXY_CHOICE
fi
if [ "$PROXY_CHOICE" = "2" ]; then
    BIND_ADDRESS="127.0.0.1"
    if [ "$INSTALL_LANG" = "de" ]; then
        echo "-> Bind: 127.0.0.1 (nur localhost)"
    else
        echo "-> Bind: 127.0.0.1 (localhost only)"
    fi
else
    BIND_ADDRESS="0.0.0.0"
    if [ "$INSTALL_LANG" = "de" ]; then
        echo "-> Bind: 0.0.0.0 (Zugriff aus dem Netzwerk)"
    else
        echo "-> Bind: 0.0.0.0 (network access enabled)"
    fi
fi

# SIP port
echo ""
if [ "$INSTALL_LANG" = "de" ]; then
    echo "SIP-Port fuer Asterisk (Standard: 5060)"
    echo "Aendern falls dein Router ein SIP-ALG hat (z.B. FritzBox)"
    read -rp "SIP-Port [5060]: " SIP_PORT
else
    echo "SIP port for Asterisk (default: 5060)"
    echo "Change this if your router uses SIP ALG (e.g. FritzBox)"
    read -rp "SIP port [5060]: " SIP_PORT
fi
SIP_PORT="${SIP_PORT:-5060}"
echo "-> SIP-Port: $SIP_PORT"

echo ""

# Admin password
if [ "$INSTALL_LANG" = "de" ]; then
    printf "Admin-Passwort festlegen (leer lassen fuer automatische Generierung): "
else
    printf "Set admin password (leave empty to auto-generate): "
fi
IFS= read -r ADMIN_PASSWORD
if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | head -c 20)
    if [ "$INSTALL_LANG" = "de" ]; then
        printf 'Generiertes Admin-Passwort: %s\n' "$ADMIN_PASSWORD"
    else
        printf 'Generated admin password: %s\n' "$ADMIN_PASSWORD"
    fi
else
    if [ "$INSTALL_LANG" = "de" ]; then
        printf 'Passwort gesetzt: %s\n' "$ADMIN_PASSWORD"
    else
        printf 'Password set: %s\n' "$ADMIN_PASSWORD"
    fi
fi

# Generate secure random passwords
JWT_SECRET=$(openssl rand -base64 48 | tr -d '/+=')
DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')
AMI_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')

# Home Assistant integration (optional)
echo ""
if [ "$INSTALL_LANG" = "de" ]; then
    echo "Home Assistant Integration (optional)"
    read -rp "API-Schluessel fuer Home Assistant generieren? [j/N]: " HA_CHOICE
else
    echo "Home Assistant Integration (optional)"
    read -rp "Generate API key for Home Assistant? [y/N]: " HA_CHOICE
fi
if [ "$HA_CHOICE" = "y" ] || [ "$HA_CHOICE" = "Y" ] || [ "$HA_CHOICE" = "j" ] || [ "$HA_CHOICE" = "J" ]; then
    HA_API_KEY=$(openssl rand -hex 32)
    if [ "$INSTALL_LANG" = "de" ]; then
        printf 'Generierter HA API-Schluessel: %s\n' "$HA_API_KEY"
        echo ""
        read -rp "MQTT-Broker-Adresse (leer lassen zum Ueberspringen): " MQTT_BROKER
    else
        printf 'Generated HA API Key: %s\n' "$HA_API_KEY"
        echo ""
        read -rp "MQTT broker address (leave empty to skip): " MQTT_BROKER
    fi
    if [ -n "$MQTT_BROKER" ]; then
        if [ "$INSTALL_LANG" = "de" ]; then
            read -rp "MQTT-Port [1883]: " MQTT_PORT
            MQTT_PORT="${MQTT_PORT:-1883}"
            read -rp "MQTT-Benutzer (leer lassen falls keiner): " MQTT_USER
            if [ -n "$MQTT_USER" ]; then
                printf "MQTT-Passwort: "
                IFS= read -r MQTT_PASSWORD
            fi
        else
            read -rp "MQTT port [1883]: " MQTT_PORT
            MQTT_PORT="${MQTT_PORT:-1883}"
            read -rp "MQTT user (leave empty if none): " MQTT_USER
            if [ -n "$MQTT_USER" ]; then
                printf "MQTT password: "
                IFS= read -r MQTT_PASSWORD
            fi
        fi
    fi
else
    HA_API_KEY=""
    MQTT_BROKER=""
fi

echo ""
if [ "$INSTALL_LANG" = "de" ]; then
    echo "Erstelle Konfiguration..."
else
    echo "Generating configuration..."
fi

# Create .env file
cat > .env <<'ENVEOF'
# VstPBX Configuration - generated by install.sh
ENVEOF
# Write values without quotes (Docker Compose v2 treats quotes as literal)
{
    printf 'EXTERNAL_IP=%s\n' "$EXTERNAL_IP"
    printf 'ADMIN_PASSWORD=%s\n' "$ADMIN_PASSWORD"
    printf 'JWT_SECRET=%s\n' "$JWT_SECRET"
    printf 'DB_PASSWORD=%s\n' "$DB_PASSWORD"
    printf 'AMI_PASSWORD=%s\n' "$AMI_PASSWORD"
    printf 'BIND_ADDRESS=%s\n' "$BIND_ADDRESS"
    printf 'SIP_PORT=%s\n' "$SIP_PORT"
    printf 'PROJECT_DIR=%s\n' "$(pwd)"
    printf 'UI_LANG=%s\n' "${UI_LANG}"
    printf 'HA_API_KEY=%s\n' "${HA_API_KEY:-}"
    printf 'MQTT_BROKER=%s\n' "${MQTT_BROKER:-}"
    printf 'MQTT_PORT=%s\n' "${MQTT_PORT:-1883}"
    printf 'MQTT_USER=%s\n' "${MQTT_USER:-}"
    printf 'MQTT_PASSWORD=%s\n' "${MQTT_PASSWORD:-}"
} >> .env

if [ "$INSTALL_LANG" = "de" ]; then
    echo "[OK] .env erstellt"
else
    echo "[OK] .env created"
fi

# Write manager.conf from template with generated AMI password
sed "s/%%AMI_PASSWORD%%/${AMI_PASSWORD}/" asterisk/config/manager.conf.template > asterisk/config/manager.conf

if [ "$INSTALL_LANG" = "de" ]; then
    echo "[OK] manager.conf aktualisiert"
else
    echo "[OK] manager.conf updated"
fi

# Ensure fail2ban paths exist (VstPBX reads them read-only if available)
ensure_fail2ban

# Pre-pull helper image for web-based updates
echo ""
if [ "$INSTALL_LANG" = "de" ]; then
    echo "Bereite Update-System vor..."
else
    echo "Preparing update system..."
fi
docker pull docker:cli >/dev/null 2>&1 &

# Start containers
echo ""
if [ "$INSTALL_LANG" = "de" ]; then
    echo "Starte Container..."
else
    echo "Starting containers..."
fi
docker compose up -d --build

echo ""
echo "============================================"
if [ "$INSTALL_LANG" = "de" ]; then
    echo "  VstPBX Installation abgeschlossen!"
else
    echo "  VstPBX Installation Complete!"
fi
echo "============================================"
echo ""
if [ "$BIND_ADDRESS" = "0.0.0.0" ]; then
    ACCESS_IP="${LOCAL_IP:-$EXTERNAL_IP}"
    echo "  Web GUI:    http://${ACCESS_IP}:3000"
    echo "  API:        http://${ACCESS_IP}:8000"
    if [ -n "$LOCAL_IP" ] && [ "$LOCAL_IP" != "$EXTERNAL_IP" ]; then
        echo ""
        if [ "$INSTALL_LANG" = "de" ]; then
            echo "  Lokales Netzwerk: http://${LOCAL_IP}:3000"
            echo "  Extern:           http://${EXTERNAL_IP}:3000"
            echo "                     (Port 3000 muss im Router freigegeben sein)"
        else
            echo "  Local network:    http://${LOCAL_IP}:3000"
            echo "  External:         http://${EXTERNAL_IP}:3000"
            echo "                     (Port 3000 must be forwarded on your router)"
        fi
    fi
else
    echo "  Web GUI:    http://localhost:3000"
    echo "  API:        http://localhost:8000"
    if [ "$INSTALL_LANG" = "de" ]; then
        echo "  (Reverse Proxy noetig fuer externen Zugriff)"
    else
        echo "  (Reverse proxy required for external access)"
    fi
fi
echo ""
printf '  Login:      admin / %s\n' "$ADMIN_PASSWORD"
echo ""
if [ "$INSTALL_LANG" = "de" ]; then
    echo "  Zugangsdaten sind in .env gespeichert"
else
    echo "  Credentials are saved in .env"
fi
echo "============================================"

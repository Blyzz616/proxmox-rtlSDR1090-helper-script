#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Jim
# License: MIT
# Source: https://github.com/Blyzz616/proxmox-rtlSDR1090-helper-script

# --- Pre-flight: ensure host has required dependencies before doing anything else ---
if ! command -v jq &>/dev/null; then
  echo "jq not found on host — installing now..."
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y jq >/dev/null 2>&1
  if command -v jq &>/dev/null; then
    echo "jq installed successfully."
  else
    echo "WARNING: jq install failed — continuing anyway, build.func will fall back gracefully."
  fi
fi
# --- End pre-flight ---

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

APP="ADSB"
var_tags="${var_tags:-adsb;rtl-sdr}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-0}"

header_info "$APP"

echo -e "\nNOTE: This container needs to be PRIVILEGED so the RTL-SDR USB dongle\ncan be passed through to it later via usb_passthrough.sh.\nUnprivileged containers cannot access host USB devices without extra\nmanual cgroup/AppArmor configuration.\n"

variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/readsb ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating readsb"
  $STD apt update
  $STD apt install --only-upgrade -y readsb
  msg_ok "readsb updated"

  msg_info "Updating tar1090"
  $STD bash /opt/tar1090/install.sh
  msg_ok "tar1090 updated"

  msg_info "Updating graphs1090"
  $STD bash /opt/graphs1090/install.sh
  msg_ok "graphs1090 updated"

  exit
}

start
build_container
description

msg_info "Installing ADS-B stack inside container (this runs our own install script, not upstream)"
pct exec "$CTID" -- bash -c "$(curl -fsSL https://raw.githubusercontent.com/Blyzz616/proxmox-rtlSDR1090-helper-script/main/install/ads-b_install.sh)"
msg_ok "ADS-B stack installed"

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL.
         ${BL}http://${IP}/tar1090${CL} \n"
echo -e "${YW}IMPORTANT:${CL} You still need to pass the RTL-SDR USB dongle through
         to this container. Run the following on the Proxmox HOST shell
         (not inside the container):

         ${BL}bash <(curl -fsSL https://raw.githubusercontent.com/Blyzz616/proxmox-rtlSDR1090-helper-script/main/usb_passthrough.sh)${CL}

         and follow the prompts, supplying CTID ${BL}${CTID}${CL} when asked.\n"

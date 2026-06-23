#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Jim
# License: MIT
# Source: https://github.com/wiedehopf/readsb

source "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt update
$STD apt install -y \
  curl \
  sudo \
  mc \
  gnupg \
  ca-certificates \
  usbutils \
  unzip \
  rtl-sdr
msg_ok "Installed Dependencies"

msg_info "Blacklisting default DVB-T kernel driver"
cat <<EOF >/etc/modprobe.d/blacklist-rtl.conf
blacklist dvb_usb_rtl28xxu
blacklist rtl2832
blacklist rtl2830
EOF
msg_ok "Blacklisted default DVB-T driver"

msg_info "Installing readsb (ADS-B decoder)"
$STD bash -c "$(curl -fsSL https://github.com/wiedehopf/readsb/raw/dev/install.sh)"
msg_ok "Installed readsb"

msg_info "Installing tar1090 (Map Web UI)"
$STD bash -c "$(curl -fsSL https://github.com/wiedehopf/tar1090/raw/master/install.sh)"
msg_ok "Installed tar1090"

msg_info "Installing graphs1090 (Stats/Graphs)"
$STD bash -c "$(curl -fsSL https://github.com/wiedehopf/graphs1090/raw/master/install.sh)"
msg_ok "Installed graphs1090"

msg_info "Creating Storage Folders for Logos/Silhouettes"
mkdir -p /opt/adsb-data/flightaware_logos
mkdir -p /opt/adsb-data/silhouettes
mkdir -p /opt/adsb-data/custom_logos
msg_ok "Created Storage Folders (/opt/adsb-data)"

msg_info "Configuring readsb to use RTL-SDR"
cat <<EOF >/etc/default/readsb
RECEIVER_OPTIONS="--device-type rtlsdr --device 0 --gain auto --ppm 0"
DECODER_OPTIONS="--max-range 450"
NET_OPTIONS="--net --net-heartbeat 60 --net-ro-size 1280 --net-ro-interval 0.2 --net-ri-port 30001 --net-ro-port 30002 --net-sbs-port 30003 --net-bi-port 30004,30104 --net-bo-port 30005"
JSON_OPTIONS="--json-location-accuracy 2"
EOF
systemctl restart readsb
msg_ok "Configured readsb"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt -y autoremove
$STD apt -y autoclean
msg_ok "Cleaned"

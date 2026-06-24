#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Jim
# License: MIT
# Source: https://github.com/wiedehopf/readsb
#
# Self-contained install script — does NOT depend on community-scripts'
# build.func/install.func helpers ($STD, msg_info, etc). This is run directly
# inside the container via `pct exec`, not through the upstream framework's
# own install pipeline, so it has to stand on its own.

set -e

echo ">> Updating package lists"
apt-get update -y

echo ">> Installing dependencies"
apt-get install -y \
  curl \
  sudo \
  mc \
  gnupg \
  ca-certificates \
  usbutils \
  unzip \
  rtl-sdr

echo ">> Blacklisting default DVB-T kernel driver"
cat <<EOC >/etc/modprobe.d/blacklist-rtl.conf
blacklist dvb_usb_rtl28xxu
blacklist rtl2832
blacklist rtl2830
EOC

echo ">> Setting up a boot-time fixup for RTL-SDR USB permissions"
echo "   (LXC USB passthrough bind-mounts don't carry host udev group ownership,"
echo "   so udev rules inside the container won't reliably fire — a systemd"
echo "   oneshot service on every boot is more robust)"
cat <<EOC >/usr/local/bin/fix-rtlsdr-perms.sh
#!/bin/bash
for dev in /dev/bus/usb/*/*; do
  [ -e "\$dev" ] && chmod 666 "\$dev" 2>/dev/null
done
EOC
chmod +x /usr/local/bin/fix-rtlsdr-perms.sh

cat <<EOC >/etc/systemd/system/fix-rtlsdr-perms.service
[Unit]
Description=Fix RTL-SDR USB device permissions for LXC passthrough
Before=readsb.service
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fix-rtlsdr-perms.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOC

systemctl daemon-reload
systemctl enable fix-rtlsdr-perms.service
systemctl start fix-rtlsdr-perms.service

echo ">> Installing readsb (ADS-B decoder) + tar1090 (this script handles both)"
bash -c "$(curl -fsSL https://github.com/wiedehopf/adsb-scripts/raw/master/readsb-install.sh)"

echo ">> Setting receiver location"
# Default: Aldergrove, BC. Override these two values for a different install location.
RECEIVER_LAT="${RECEIVER_LAT:-49.0578}"
RECEIVER_LON="${RECEIVER_LON:-122.4669}"
readsb-set-location "$RECEIVER_LAT" "$RECEIVER_LON"

echo ">> Installing graphs1090 (Stats/Graphs)"
bash -c "$(curl -fsSL https://github.com/wiedehopf/graphs1090/raw/master/install.sh)"

echo ">> Creating storage folders for logos/silhouettes"
mkdir -p /opt/adsb-data/flightaware_logos
mkdir -p /opt/adsb-data/silhouettes
mkdir -p /opt/adsb-data/custom_logos

echo ">> Configuring readsb to use RTL-SDR"
cat <<EOC >/etc/default/readsb
RECEIVER_OPTIONS="--device-type rtlsdr --device 0 --gain auto --ppm 0"
DECODER_OPTIONS="--max-range 450"
NET_OPTIONS="--net --net-heartbeat 60 --net-ro-size 1280 --net-ro-interval 0.2 --net-ri-port 30001 --net-ro-port 30002 --net-sbs-port 30003 --net-bi-port 30004,30104 --net-bo-port 30005"
JSON_OPTIONS="--json-location-accuracy 2"
EOC
systemctl restart readsb

echo ">> Cleaning up"
apt-get -y autoremove
apt-get -y autoclean

echo ">> Done. readsb, tar1090, and graphs1090 are installed."
echo ">> Note: the RTL-SDR dongle still needs USB passthrough from the host"
echo ">> (run usb_passthrough.sh on the Proxmox host shell, not in here)."

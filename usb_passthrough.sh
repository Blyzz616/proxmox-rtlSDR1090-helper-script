#!/usr/bin/env bash
# RTL-SDR USB Passthrough Helper for Proxmox LXC
# Run this on the PROXMOX HOST shell (not inside the container).
# It asks for your container ID, finds the RTL-SDR dongle, and wires up passthrough.

set -e

echo "=== RTL-SDR USB Passthrough Helper ==="
echo

# 1. Ask for the container ID
read -rp "Enter the CTID of your ADS-B container (e.g. 105): " CTID

if ! pct status "$CTID" &>/dev/null; then
  echo "ERROR: No container with ID $CTID found. Run 'pct list' to check."
  exit 1
fi

# 2. Detect RTL-SDR dongle on the host
echo
echo "Scanning for RTL-SDR dongle on the host..."
USB_LINE=$(lsusb | grep -iE "RTL2838|RTL2832|Realtek Semiconductor" || true)

if [[ -z "$USB_LINE" ]]; then
  echo "No RTL-SDR dongle detected via lsusb."
  echo "Make sure it's plugged into the Proxmox host (not passed through to another VM/CT)."
  exit 1
fi

echo "Found: $USB_LINE"

BUS=$(echo "$USB_LINE" | awk '{print $2}')
DEV=$(echo "$USB_LINE" | awk '{print $4}' | tr -d ':')
VENDOR_PRODUCT=$(echo "$USB_LINE" | awk '{print $6}')

echo "Bus: $BUS  Device: $DEV  ID: $VENDOR_PRODUCT"
echo

# 3. Confirm before editing config
read -rp "Add USB passthrough for this device to container $CTID? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

CONF="/etc/pve/lxc/${CTID}.conf"

if grep -q "rtl-sdr-passthrough" "$CONF" 2>/dev/null; then
  echo "Passthrough entry already exists in $CONF — skipping duplicate add."
else
  {
    echo ""
    echo "# rtl-sdr-passthrough"
    echo "lxc.cgroup2.devices.allow: c 189:* rwm"
    echo "lxc.mount.entry: /dev/bus/usb dev/bus/usb none bind,optional,create=dir"
  } >> "$CONF"
  echo "Passthrough config written to $CONF"
fi

echo
echo "Restarting container $CTID..."
pct stop "$CTID" 2>/dev/null || true
sleep 2
pct start "$CTID"

echo
echo "=== Done ==="
echo "Inside the container, verify with: lsusb | grep -i realtek"
echo "If it doesn't show up, double check the dongle isn't claimed by the host's"
echo "dvb_usb_rtl28xxu driver — run 'lsmod | grep dvb' on the HOST."
echo "If loaded there, run: rmmod dvb_usb_rtl28xxu  (then re-run this script)"

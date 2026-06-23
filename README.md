# Proxmox RTL-SDR / ADS-B Helper Script

A Proxmox VE helper script that creates a lightweight LXC container running a full
ADS-B (aircraft tracking) receiver stack, fed by a cheap RTL-SDR (R820T2) USB dongle.

Built in the same style as the [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE)
helper scripts — interactive prompts, sensible defaults, minimal manual config.

## What it installs

Inside the container:

- **[readsb](https://github.com/wiedehopf/readsb)** — decodes raw 1090 MHz ADS-B signals from the RTL-SDR dongle
- **[tar1090](https://github.com/wiedehopf/tar1090)** — modern live map web UI (includes aircraft silhouettes & operator flags support)
- **[graphs1090](https://github.com/wiedehopf/graphs1090)** — signal strength / message rate graphs over time
- Kernel DVB driver blacklist (so the host doesn't grab the dongle before readsb can)
- `/opt/adsb-data/` folders for dropping in custom operator logos / silhouettes

This replaces the Windows rtl1090 + Virtual Radar Server combo with the standard
Linux equivalent stack used by most dedicated ADS-B feeders (e.g. PiAware, ADSBExchange feeders).

## Requirements

- Proxmox VE host
- An RTL-SDR dongle (R820T2 or similar) plugged into the **Proxmox host** (not yet passed through)
- A 1090 MHz capable antenna (a basic telescoping antenna works for testing; a dedicated collinear antenna gives much better range)

## Usage

### 1. Create the container

Run on the **Proxmox host** shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Blyzz616/proxmox-rtlSDR1090-helper-script/main/ads-b.sh)"
```

You'll be walked through the standard interactive prompts (CPU, RAM, disk, storage,
network, etc). Defaults are tuned for this workload:

| Setting | Default |
|---|---|
| CPU | 2 cores |
| RAM | 1024 MB |
| Disk | 8 GB |
| OS | Debian 12 |
| Privileged | Yes (required for USB passthrough) |

> Disk is set higher than readsb/tar1090 strictly need, to leave headroom for
> custom operator logo packs, silhouettes, and graphs1090's history.

### 2. Pass the RTL-SDR dongle through to the container

Once the container is created, run this **on the Proxmox host shell** (not inside the container):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Blyzz616/proxmox-rtlSDR1090-helper-script/main/usb_passthrough.sh)
```

It will:
1. Scan the host for a connected RTL-SDR dongle via `lsusb`
2. Ask which container ID (CTID) to attach it to
3. Write the required `cgroup` / USB bind-mount lines into that container's config
4. Restart the container

If the dongle doesn't show up, make sure the host's `dvb_usb_rtl28xxu` kernel module
isn't already holding onto it (`lsmod | grep dvb` on the host — if present, `rmmod dvb_usb_rtl28xxu` and re-run).

### 3. View your live aircraft map

Once both steps are done:

```
http://<container-ip>/tar1090
```

### 4. Adding custom operator logos / silhouettes

tar1090 ships with its own default logo/silhouette set, but if you want to use a
specific pack (e.g. the FlightAware logo set from
[vradarserver/standing-data](https://github.com/vradarserver/standing-data)), drop
the images into:

```
/opt/adsb-data/flightaware_logos/
/opt/adsb-data/silhouettes/
```

and point tar1090's config at that path (see tar1090's own docs for the exact config
key, as it may change between versions).

## Updating

Re-run the main script against an existing container and choose the update path
when prompted — it will refresh readsb, tar1090, and graphs1090 in place without
losing your configuration.

## Troubleshooting

**Container can't see the dongle at all**
Check `lsusb` inside the container. If empty, re-run `usb_passthrough.sh` — most
likely the host's DVB driver claimed the device first, or the passthrough lines
didn't get written (check `/etc/pve/lxc/<CTID>.conf` for a `rtl-sdr-passthrough`
comment block).

**readsb runs but no aircraft show up**
- Confirm an antenna is actually attached
- Check gain isn't set too low — edit `/etc/default/readsb` and adjust `--gain`
- Antenna placement matters a lot at 1090 MHz — near a window or outside is best
- Use [adsbexchange.com](https://www.adsbexchange.com/) or [flightradar24.com](https://www.flightradar24.com/) to confirm there's actually traffic overhead

**Dongle gets hot / USB connection is flaky**
This is normal for cheap RTL-SDR dongles. A short USB extension cable lets you
position the dongle away from the host for better airflow and antenna placement,
without needing a powered hub in most cases.

## Credits

- [wiedehopf](https://github.com/wiedehopf) for readsb, tar1090, and graphs1090
- [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) for the helper script framework this is built on

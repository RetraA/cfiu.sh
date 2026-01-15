# CFIU — Cloudflare IP Updater

CFIU is a fully automated Bash script that keeps Cloudflare DNS records up to date with your system’s current public IPv4 and IPv6 addresses. It is designed for dynamic IP environments and supports **multiple DNS records across multiple Cloudflare zones** using a single configuration file.

Ideal for home servers, self-hosted services, VPN endpoints, and any system with a changing public IP.

---

## Features

- Automatically detects public **IPv4 and IPv6**
- Updates existing **A and AAAA DNS records**
- **Multi-record / multi-zone** support
- Single JSON configuration file
- Updates only when the IP changes
- Automatic dependency installation (`curl`, `jq`)
- Secure config permissions
- Root-safe execution with `sudo`
- Built-in **uninstall mode**
- Clear, color-coded output

---

## Requirements

- Bash
- Cloudflare API token with **DNS edit permissions**
- Supported package managers:
  - apt
  - dnf
  - yum
  - pacman

---

## Installation

```bash
curl -o cfiu.sh https://your-repo-url/cfiu.sh
chmod +x cfiu.sh
sudo ./cfiu.sh
```

On first run, CFIU will:
- Install required dependencies
- Create `/etc/cfiu/config.json`
- Populate it with example DNS records
- Exit so you can edit the configuration

---

## Configuration

Edit the config file:

```bash
sudo nano /etc/cfiu/config.json
```

### Example configuration

```json
{
  "API Key": "YOUR_CLOUDFLARE_API_TOKEN",
  "records": [
    {
      "Zone Id": "ZONE_ID",
      "domain": "home.example.com",
      "types": ["A", "AAAA"],
      "ttl": 120,
      "proxied": false
    },
    {
      "Zone Id": "ZONE_ID",
      "domain": "vpn.example.net",
      "types": ["A"],
      "ttl": 120,
      "proxied": false
    }
  ]
}
```

---

## Usage

```bash
sudo ./cfiu.sh
```

---

## Cron Example

```bash
* * * * * /usr/bin/bash -c 'mkdir -p /var/log/cfiu; LOG=/var/log/cfiu/cfiu-$(date +\%F).log; /usr/bin/bash /root/cfiu.sh >> "$LOG" 2>&1'
```

---

## Uninstall

```bash
sudo ./cfiu.sh -u
```

Remove with dependencies:

```bash
**WARNING**
THIS MAY UNINSTALL DEPENDENCIES REQUIRED BY OTHER PROGRAMS!! 
sudo ./cfiu.sh -u --deps 
```

---

## License

MIT License

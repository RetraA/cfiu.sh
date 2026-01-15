# CFIU — Cloudflare IP Updater

CFIU is a fully automated Bash script that keeps Cloudflare DNS records synchronized with your system’s current public **IPv4 and IPv6** addresses. It is designed for dynamic IP environments and supports **multiple DNS records across multiple Cloudflare zones** using a single configuration file.

Ideal for home servers, self-hosted services, VPN endpoints, and any system with a frequently changing public IP.

---

## Features

- Automatic public **IPv4 and IPv6** detection
- Updates existing **A and AAAA** DNS records
- **Multi-record / multi-zone** support
- Single JSON configuration file
- Updates only when the IP address changes
- Automatic dependency installation (`curl`, `jq`)
- Secure configuration file permissions
- Root-safe execution with `sudo`
- Built-in **uninstall mode**
- Clear, color-coded terminal output

---

## Requirements

- Bash
- Cloudflare API token with **DNS edit permissions**
- Supported package managers:
  - `apt`
  - `dnf`
  - `yum`
  - `pacman`

---

## Installation

### Using `wget`
```bash
wget https://raw.githubusercontent.com/RetraA/cfiu.sh/main/cfiu.sh
```

### Using `curl`
```bash
curl -o cfiu.sh https://raw.githubusercontent.com/RetraA/cfiu.sh/main/cfiu.sh
```

Make the script executable and run it:
```bash
chmod +x cfiu.sh
bash cfiu.sh
```

### First Run Behavior

On first execution, CFIU will:
- Install required dependencies
- Create `/etc/cfiu/config.json`
- Populate the file with example DNS records
- Exit so you can review and edit the configuration

---

## Configuration

Edit the configuration file:
```bash
nano /etc/cfiu/config.json
```

### Example Configuration

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

Run the updater manually:
```bash
bash cfiu.sh
```

---

## Cron

You can automate updates by creating a cron job:
```bash
crontab -e
```
Schedule the script to run as often as you like (e.g., every minute, every 5 minutes, etc.).

---

## Uninstall

Remove CFIU:
```bash
bash cfiu.sh -u
```

### Remove with Dependencies (Optional)
⚠ **WARNING**  
This may uninstall packages required by other applications.
```bash
bash cfiu.sh -u --deps
```

---

## License

MIT License

© Retra


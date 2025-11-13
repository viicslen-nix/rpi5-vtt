# 🎲 VTT Gaming Server Configuration

A complete NixOS configuration for Raspberry Pi 5 that provides a WiFi Access Point with integrated Foundry Virtual Tabletop gaming server. Perfect for portable D&D sessions and tabletop gaming anywhere!

## ✨ Features

- **📶 WiFi Access Point**: Creates "VTT-Gaming" network for client devices
- **🌐 Internet Sharing**: Shares ethernet connection with WiFi clients via NAT
- **🔗 Custom DNS**: Resolves `vtt.local` and `foundry.local` to gaming server
- **⚡ Port-free Access**: Nginx reverse proxy eliminates need for `:30000`
- **🔐 Secure SSH**: Key-based authentication with passwordless sudo
- **🎲 Foundry VTT**: Complete virtual tabletop server ready to use
- **🛠️ Debug Tools**: Built-in network monitoring and status scripts

## 🚀 Quick Start

### 1. Deploy Configuration
```bash
# Build the configuration locally
nix build .#nixosConfigurations.vtt.config.system.build.toplevel

# Deploy to your Raspberry Pi
nixos-rebuild switch --flake .#vtt \
  --target-host vtt@192.168.1.173 \
  --build-host vtt@192.168.1.173 \
  --use-remote-sudo
```

### 2. Connect & Play
1. Connect devices to **VTT-Gaming** WiFi network (password: `foundrycast`)
2. Open browser to: **`http://vtt.local/`**
3. Start your gaming session! 🎮

## 🌐 Access Your VTT Server

Once connected to the WiFi network, access your server via:

| Method | URL | Description |
|--------|-----|-------------|
| 🎯 **Primary** | `http://vtt.local/` | Clean, memorable access |
| 🎲 **Alternative** | `http://foundry.local/` | Foundry-branded URL |
| 📍 **Direct IP** | `http://192.168.4.1/` | Always works |
| 🔧 **Legacy** | `http://vtt.local:30000` | Direct port access |

## 📁 Project Structure

### 🏗️ Core Configuration
```
├── flake.nix              # NixOS flake with system definition
├── default.nix            # Main configuration entry point
├── hardware.nix           # Raspberry Pi 5 hardware config
├── configuration.nix      # Foundry VTT service setup
└── disko.nix              # Disk partitioning configuration
```

### 🧩 Modular Components
```
modules/
├── system.nix             # Core system & boot configuration
├── networking.nix         # Network interfaces & NAT forwarding  
├── wifi-ap.nix           # WiFi AP, DHCP & DNS services
├── web-services.nix      # Nginx reverse proxy configuration
├── users.nix             # SSH authentication & sudo config
└── utilities.nix         # Debug tools & system utilities
```

## 🌐 Network Architecture

### WiFi Access Point
- **SSID**: `VTT-Gaming`
- **Password**: `foundrycast`
- **Security**: WPA2-PSK encryption
- **IP Range**: `192.168.4.0/24`
- **Gateway**: `192.168.4.1` (the Raspberry Pi)
- **DHCP Pool**: `192.168.4.10-192.168.4.100`

### Service Flow
```
📡 Internet ← Ethernet → 🥧 Pi ← WiFi → 🎮 Gaming Devices
                         ↓
                   [dnsmasq DHCP/DNS]
                         ↓
              [nginx:80] → [foundry:30000]
```

## ⚙️ Module Details

### `system.nix` - Core System
- Raspberry Pi 5 hardware imports
- WiFi kernel modules
- IP forwarding for NAT

### `networking.nix` - Network Layer
- Ethernet & WiFi interface config
- NAT rules for internet sharing
- Firewall configuration

### `wifi-ap.nix` - Access Point
- Manual hostapd service setup
- dnsmasq DHCP server (192.168.4.10-100)
- Custom DNS (vtt.local → 192.168.4.1)

### `web-services.nix` - Web Proxy
- Nginx reverse proxy (port 80 → 30000)
- WebSocket support for real-time gaming
- Multiple hostname support

### `users.nix` - Authentication
- SSH key-based login
- PAM configuration for passwordless sudo
- Secure user account setup

### `utilities.nix` - System Tools
- WiFi status monitoring script
- USB device auto-mounting
- Debug and maintenance tools

## 🔧 Management & Debugging

### Status Monitoring
```bash
# Quick status overview
ssh vtt@192.168.1.173 'wifi-ap-status'

# Check all gaming services
ssh vtt@192.168.1.173 'sudo systemctl status nginx manual-hostapd dnsmasq foundry-vtt --no-pager'

# View real-time logs
ssh vtt@192.168.1.173 'sudo journalctl -u manual-hostapd -f'
```

### Service Management
```bash
# Restart WiFi access point
ssh vtt@192.168.1.173 'sudo systemctl restart manual-hostapd'

# Restart web services
ssh vtt@192.168.1.173 'sudo systemctl restart nginx dnsmasq'

# Full network restart (if needed)
ssh vtt@192.168.1.173 'sudo systemctl restart systemd-networkd'
```

### Development & Testing
```bash
# Test configuration before deploy
nix build .#nixosConfigurations.vtt.config.system.build.toplevel

# Validate flake
nix flake check

# Remote shell for debugging
ssh vtt@192.168.1.173
```

## 🎨 Customization

### Change WiFi Settings
Edit `default.nix`:
```nix
# Update WiFi password
environment.etc."wpa_passphrase".text = "your-new-password";
```

Edit `modules/wifi-ap.nix`:
```nix
# Change network name or IP range
services.dnsmasq.settings.interface = "wlan0";
services.dnsmasq.settings.dhcp-range = "192.168.4.10,192.168.4.200";
```

### Add Custom Services
Edit `modules/web-services.nix`:
```nix
# Add new virtual hosts
services.nginx.virtualHosts."custom.local" = {
  listen = [{ addr = "0.0.0.0"; port = 80; }];
  locations."/" = {
    proxyPass = "http://192.168.4.1:8080";
  };
};
```

### Modify Network Range
Edit `modules/networking.nix` and `modules/wifi-ap.nix` to change IP ranges consistently.

## 🛠️ Troubleshooting

### WiFi Access Point Issues
```bash
# Check if hostapd is running
ssh vtt@192.168.1.173 'sudo systemctl status manual-hostapd'

# Verify WiFi interface status  
ssh vtt@192.168.1.173 'ip link show wlan0'

# Check hostapd logs
ssh vtt@192.168.1.173 'sudo journalctl -u manual-hostapd --since "5 minutes ago"'
```

### Internet Connectivity Problems
```bash
# Verify NAT rules are active
ssh vtt@192.168.1.173 'sudo iptables -t nat -L POSTROUTING'

# Check IP forwarding is enabled
ssh vtt@192.168.1.173 'cat /proc/sys/net/ipv4/ip_forward'

# Test ethernet connectivity
ssh vtt@192.168.1.173 'ping -c 3 8.8.8.8'
```

### DNS Resolution Issues
```bash
# Check dnsmasq status
ssh vtt@192.168.1.173 'sudo systemctl status dnsmasq'

# Test local DNS resolution
ssh vtt@192.168.1.173 'nslookup vtt.local 127.0.0.1'

# Check DNS configuration
ssh vtt@192.168.1.173 'cat /etc/dnsmasq.conf'
```

### Web Access Problems
```bash
# Check nginx status
ssh vtt@192.168.1.173 'sudo systemctl status nginx'

# Test proxy functionality
ssh vtt@192.168.1.173 'curl -I http://192.168.4.1/'

# Check Foundry VTT backend
ssh vtt@192.168.1.173 'sudo systemctl status foundry-vtt'
```

## 📋 Requirements

- **Hardware**: Raspberry Pi 5 with WiFi capability
- **Storage**: MicroSD card (16GB+ recommended)
- **OS**: NixOS (fresh installation)
- **Network**: Ethernet connection for internet sharing
- **Development**: Nix package manager with flakes enabled

## 🚧 Development

### Local Development
```bash
# Clone and enter directory
git clone <repo-url>
cd vtt

# Test build locally
nix build .#nixosConfigurations.vtt.config.system.build.toplevel

# Format nix files
nix fmt
```

### Making Changes
1. Edit the relevant module file in `modules/`
2. Test the build: `nix build .#nixosConfigurations.vtt.config.system.build.toplevel`
3. Deploy: `nixos-rebuild switch --flake .#vtt --target-host vtt@<PI_IP> --build-host vtt@<PI_IP> --use-remote-sudo`

### Adding Features
- **New web services**: Add to `modules/web-services.nix`
- **Network changes**: Modify `modules/networking.nix`
- **System tools**: Add to `modules/utilities.nix`

## 📝 License

This project is provided as-is for educational and personal use. Foundry VTT requires a separate license for commercial use.
# Deployment Guide

## Using the Built Artifacts

After the CircleCI workflow completes, you can download and deploy the artifacts to your Raspberry Pi.

### Option 1: Deploy System Closure (for existing NixOS installation)

1. Download the `nixos-system` artifact from the CircleCI Artifacts tab
2. Extract the artifact on your local machine
3. Copy to Raspberry Pi and activate:

```bash
# Copy the system closure to your Raspberry Pi
rsync -avz --progress artifacts/system/ vtt@<raspberry-pi-ip>:/tmp/new-system/

# SSH into the Raspberry Pi
ssh vtt@<raspberry-pi-ip>

# Switch to the new system
sudo nix-env --profile /nix/var/nix/profiles/system --set /tmp/new-system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

### Option 2: Flash SD Image (for new installation)

1. Download the `sd-image` artifact from the CircleCI Artifacts tab
2. Extract the .img file
3. Flash to SD card:

```bash
# On Linux/macOS
sudo dd if=nixos-sd-image-*.img of=/dev/sdX bs=4M status=progress conv=fsync

# Or use a tool like balenaEtcher, Raspberry Pi Imager, etc.
```

4. Insert the SD card into your Raspberry Pi and boot

### Option 3: Remote Deployment with nixos-rebuild

If you have SSH access and want to build locally but deploy remotely:

```bash
# Build and deploy in one command
nixos-rebuild switch --flake .#vtt --target-host vtt@<raspberry-pi-ip> --use-remote-sudo
```

## CircleCI Setup

The workflow uses CircleCI's ARM64 runners which are available for private repositories.

### Getting Started

1. Sign up for CircleCI at https://circleci.com and connect your GitHub account
2. Add your repository in CircleCI by going to Projects → Set Up Project
3. CircleCI will automatically detect the `.circleci/config.yml` file and start building

### Resource Classes

The workflow uses `arm.medium` resource class which provides:
- 2 vCPUs
- 8GB RAM
- ARM64 architecture

For faster builds, you can upgrade to `arm.large` (4 vCPUs, 16GB RAM) by changing the `resource_class` in the config.

### Build Artifacts

After each successful build, artifacts are available in:
- CircleCI dashboard → Your build → Artifacts tab
- System toplevel and SD image will be available for download
- Artifacts are retained according to your CircleCI plan (typically 30 days)

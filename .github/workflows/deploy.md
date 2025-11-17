# Deployment Guide

## Using the Built Artifacts

After the GitHub Actions workflow completes, you can download and deploy the artifacts to your Raspberry Pi.

### Option 1: Deploy System Closure (for existing NixOS installation)

1. Download the `nixos-system-<commit-sha>` artifact from the Actions tab
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

1. Download the `sd-image-<commit-sha>` artifact from the Actions tab
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

## GitHub Actions Setup

The workflow requires an ARM64 runner. You can either:

1. **Use GitHub-hosted ARM64 runners** (available for Team and Enterprise plans)
2. **Self-host an ARM64 runner** on your own hardware

### Setting up a Self-Hosted ARM64 Runner

If you don't have access to GitHub-hosted ARM64 runners, you can set up a self-hosted runner:

1. Go to your repository Settings → Actions → Runners → New self-hosted runner
2. Select Linux and ARM64
3. Follow the instructions to set up the runner on an ARM64 machine (can be another Raspberry Pi, AWS Graviton instance, etc.)

Alternatively, modify the workflow to use `ubuntu-latest` and enable QEMU for ARM64 emulation (slower but works without ARM64 hardware):

```yaml
runs-on: ubuntu-latest
steps:
  - name: Set up QEMU
    uses: docker/setup-qemu-action@v3
    with:
      platforms: arm64
```

## Cachix Setup (Optional)

To speed up builds by using cached dependencies:

1. Create a Cachix account at https://cachix.org
2. Create a new binary cache
3. Generate an auth token
4. Add the token as a repository secret named `CACHIX_AUTH_TOKEN`

This is optional - the workflow will work without it, just slower.

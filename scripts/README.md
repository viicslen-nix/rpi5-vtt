# GitHub Deployment Script

This script allows you to download and deploy the latest NixOS system build from GitHub Actions artifacts directly to your Raspberry Pi.

## Features

- Downloads the latest successful build from GitHub Actions
- Verifies the system closure before deploying
- Shows a diff of changes (if `nvd` is installed)
- Interactive confirmation before switching
- Dry-run mode for testing
- Optional automatic updates via systemd timer

## Prerequisites

1. **GitHub CLI (`gh`)** - Installed automatically with the module
2. **GitHub Authentication** - You must authenticate the GitHub CLI:
   ```bash
   gh auth login
   ```
   Follow the prompts to authenticate with your GitHub account.

## Usage

### Manual Deployment

Simply run the script to deploy the latest build:

```bash
sudo deploy-from-github
```

The script will:
1. Find the latest successful workflow run
2. Download the system artifacts
3. Verify the system closure
4. Show what will change
5. Ask for confirmation
6. Switch to the new system

### Dry Run

To see what would happen without making changes:

```bash
deploy-from-github --dry-run
```

### Custom Repository

To deploy from a different repository:

```bash
deploy-from-github --repo owner/repo-name
```

### Command Line Options

```
Usage: deploy-from-github [OPTIONS]

Options:
  --dry-run          Show what would be done without making changes
  --repo OWNER/NAME  Specify repository (default: viicslen-nix/rpi5-vtt)
  --workflow NAME    Specify workflow file (default: build.yml)
  -h, --help         Show this help message
```

## Configuration

The deployment module is configured in your `configuration.nix`:

### Basic Setup (Manual Updates)

```nix
vtt.deploy = {
  enable = true;
};
```

This installs the `deploy-from-github` command and required tools.

### Automatic Updates

To enable automatic daily updates:

```nix
vtt.deploy = {
  enable = true;
  
  autoUpdate = {
    enable = true;
    schedule = "daily";  # or any systemd calendar format like "03:00"
    repository = "viicslen-nix/rpi5-vtt";
  };
};
```

#### Systemd Timer Schedules

You can use any systemd calendar format for the schedule:

- `"daily"` - Once per day
- `"weekly"` - Once per week
- `"03:00"` - Daily at 3 AM
- `"Mon,Wed,Fri 02:00"` - Monday, Wednesday, Friday at 2 AM
- `"*-*-* 04:00:00"` - Every day at 4 AM

#### Managing Auto-Updates

```bash
# Check timer status
systemctl status github-auto-deploy.timer

# View recent runs
journalctl -u github-auto-deploy.service

# Manually trigger an update
sudo systemctl start github-auto-deploy.service

# Disable auto-updates temporarily
sudo systemctl stop github-auto-deploy.timer
```

## How It Works

1. **Build Phase** (GitHub Actions):
   - Code is pushed to the repository
   - GitHub Actions builds the NixOS system for ARM64
   - Build artifacts are uploaded and stored for 30 days

2. **Deploy Phase** (On Raspberry Pi):
   - Script queries GitHub API for the latest successful build
   - Downloads the system closure artifact
   - Verifies the closure is valid
   - Sets the system profile to the new closure
   - Runs `switch-to-configuration switch` to activate

3. **Rollback** (If Needed):
   - NixOS keeps previous generations
   - Rollback at boot by selecting a previous generation
   - Or manually: `sudo nix-env --profile /nix/var/nix/profiles/system --rollback`

## Troubleshooting

### "GitHub CLI is not authenticated"

Run `gh auth login` and follow the prompts to authenticate.

### "No successful workflow runs found"

Check that:
- The workflow has run successfully at least once
- You have access to the repository
- The workflow name matches (default: `build.yml`)

### Permission Denied

The script needs to be run with sudo to switch the system:
```bash
sudo deploy-from-github
```

### Viewing Detailed Changes

Install `nvd` for a detailed diff of package changes:
```bash
nix-env -iA nixos.nvd
```

Then run the deployment script - it will automatically show detailed changes.

## Security Considerations

- The script downloads and executes system configurations from GitHub
- Ensure your GitHub account is secured with 2FA
- Review the workflow runs before deploying if unsure
- The repository should be private if it contains sensitive configuration
- Use `--dry-run` first to review changes

## Example Workflow

```bash
# 1. Push changes to GitHub
git add .
git commit -m "Update configuration"
git push

# 2. Wait for GitHub Actions to build (check on GitHub)

# 3. Deploy to Raspberry Pi
ssh vtt@raspberry-pi
sudo deploy-from-github

# 4. Review changes and confirm

# 5. If something goes wrong, rollback
sudo nixos-rebuild switch --rollback
```

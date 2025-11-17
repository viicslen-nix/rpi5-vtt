#!/usr/bin/env bash
#
# Deploy NixOS System from GitHub Actions Artifacts
# This script downloads the latest successful build from GitHub Actions
# and switches the system to use it.
#

set -euo pipefail

# Configuration
REPO_OWNER="${REPO_OWNER:-viicslen-nix}"
REPO_NAME="${REPO_NAME:-rpi5-vtt}"
WORKFLOW_NAME="${WORKFLOW_NAME:-build.yml}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/tmp/nixos-deploy}"
DRY_RUN="${DRY_RUN:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

check_requirements() {
    log_info "Checking requirements..."
    
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        log_info "Install with: nix-env -iA nixos.gh"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated"
        log_info "Run: gh auth login"
        exit 1
    fi
    
    log_success "All requirements met"
}

get_latest_successful_run() {
    log_info "Finding latest successful workflow run..."
    
    local run_id
    run_id=$(gh run list \
        --repo "${REPO_OWNER}/${REPO_NAME}" \
        --workflow "${WORKFLOW_NAME}" \
        --status success \
        --limit 1 \
        --json databaseId \
        --jq '.[0].databaseId')
    
    if [ -z "$run_id" ] || [ "$run_id" = "null" ]; then
        log_error "No successful workflow runs found"
        exit 1
    fi
    
    log_success "Found run ID: $run_id"
    echo "$run_id"
}

get_run_info() {
    local run_id=$1
    
    log_info "Getting run information..."
    
    gh run view "$run_id" \
        --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json headSha,createdAt,updatedAt,conclusion \
        --jq '{commit: .headSha, created: .createdAt, updated: .updatedAt, status: .conclusion}'
}

download_artifact() {
    local run_id=$1
    local artifact_pattern=$2
    local dest_dir=$3
    
    log_info "Downloading artifact matching: $artifact_pattern"
    
    # Create destination directory
    mkdir -p "$dest_dir"
    
    # Download artifact
    gh run download "$run_id" \
        --repo "${REPO_OWNER}/${REPO_NAME}" \
        --pattern "$artifact_pattern" \
        --dir "$dest_dir"
    
    log_success "Downloaded artifact to: $dest_dir"
}

verify_system_closure() {
    local system_path=$1
    
    log_info "Verifying system closure..."
    
    if [ ! -d "$system_path" ]; then
        log_error "System path does not exist: $system_path"
        return 1
    fi
    
    if [ ! -f "$system_path/activate" ]; then
        log_error "System closure missing activate script"
        return 1
    fi
    
    if [ ! -d "$system_path/sw" ]; then
        log_error "System closure missing sw directory"
        return 1
    fi
    
    log_success "System closure verified"
    return 0
}

switch_to_system() {
    local system_path=$1
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warn "DRY RUN: Would switch to system: $system_path"
        log_warn "DRY RUN: Would run: sudo nix-env --profile /nix/var/nix/profiles/system --set $system_path"
        log_warn "DRY RUN: Would run: sudo $system_path/bin/switch-to-configuration switch"
        return 0
    fi
    
    log_info "Setting system profile..."
    sudo nix-env --profile /nix/var/nix/profiles/system --set "$system_path"
    
    log_info "Switching to new configuration..."
    sudo "$system_path/bin/switch-to-configuration" switch
    
    log_success "System switched successfully!"
}

show_diff() {
    local new_system=$1
    local current_system="/run/current-system"
    
    if [ ! -e "$current_system" ]; then
        log_warn "Cannot show diff: no current system found"
        return
    fi
    
    log_info "Changes from current system:"
    echo ""
    
    # Show package differences
    if command -v nvd &> /dev/null; then
        nvd diff "$current_system" "$new_system"
    else
        log_info "Install 'nvd' for detailed diff: nix-env -iA nixos.nvd"
        echo "Current: $current_system"
        echo "New:     $new_system"
    fi
}

cleanup() {
    if [ "$DRY_RUN" = "false" ]; then
        log_info "Cleaning up temporary files..."
        rm -rf "$DOWNLOAD_DIR"
        log_success "Cleanup complete"
    fi
}

main() {
    log_info "=== NixOS GitHub Deployment Script ==="
    log_info "Repository: ${REPO_OWNER}/${REPO_NAME}"
    log_info "Workflow: ${WORKFLOW_NAME}"
    echo ""
    
    # Check requirements
    check_requirements
    
    # Get latest successful run
    run_id=$(get_latest_successful_run)
    
    # Show run information
    log_info "Run Information:"
    get_run_info "$run_id"
    echo ""
    
    # Download artifacts
    download_artifact "$run_id" "nixos-system-*" "$DOWNLOAD_DIR"
    
    # Find the system closure directory
    system_dir=$(find "$DOWNLOAD_DIR" -type d -name "nixos-system-*" | head -n1)
    if [ -z "$system_dir" ]; then
        log_error "Could not find downloaded system directory"
        exit 1
    fi
    
    system_path="$system_dir/system"
    
    # Verify the system closure
    if ! verify_system_closure "$system_path"; then
        log_error "System verification failed"
        cleanup
        exit 1
    fi
    
    # Show what will change
    show_diff "$system_path"
    echo ""
    
    # Confirm before switching (unless in non-interactive mode)
    if [ -t 0 ] && [ "$DRY_RUN" = "false" ]; then
        read -p "$(echo -e ${YELLOW}Do you want to switch to this system? [y/N]:${NC} )" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warn "Deployment cancelled"
            cleanup
            exit 0
        fi
    fi
    
    # Switch to the new system
    switch_to_system "$system_path"
    
    # Cleanup
    cleanup
    
    echo ""
    log_success "=== Deployment Complete ==="
    log_info "You may want to reboot for all changes to take effect"
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --repo)
            REPO_OWNER="${2%%/*}"
            REPO_NAME="${2##*/}"
            shift 2
            ;;
        --workflow)
            WORKFLOW_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run          Show what would be done without making changes"
            echo "  --repo OWNER/NAME  Specify repository (default: viicslen-nix/rpi5-vtt)"
            echo "  --workflow NAME    Specify workflow file (default: build.yml)"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  REPO_OWNER         Repository owner"
            echo "  REPO_NAME          Repository name"
            echo "  WORKFLOW_NAME      Workflow filename"
            echo "  DOWNLOAD_DIR       Temporary download directory"
            echo "  DRY_RUN            Set to 'true' for dry run"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main

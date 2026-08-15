{ config, pkgs, ... }:

let
  syncScript = pkgs.writeShellScript "vtt-sync" ''
    set -eu

    direction="$1"
    case "$direction" in
      pull|push) ;;
      *) exit 64 ;;
    esac

    state=/var/lib/vtt-sync
    local_data=/home/${config.vtt.common.userName}/foundrydata/Data
    local_backups=/home/${config.vtt.common.userName}/foundrydata/SyncBackups
    remote=vtt-sync@192.168.1.62
    remote_data=/var/lib/foundryvtt/Data
    timestamp=$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)
    ssh_options="-i $state/id_ed25519 -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$state/known_hosts -o ConnectTimeout=10"
    local_stopped=false
    backup_ready=false

    exec 9>"$state/sync.lock"
    ${pkgs.util-linux}/bin/flock -n 9 || exit 75

    write_status() {
      tmp=$(${pkgs.coreutils}/bin/mktemp "$state/status.json.XXXXXX")
      ${pkgs.coreutils}/bin/printf '{"direction":"%s","state":"%s","message":"%s","timestamp":"%s"}\n' \
        "$direction" "$1" "$2" "$(${pkgs.coreutils}/bin/date --iso-8601=seconds)" > "$tmp"
      ${pkgs.coreutils}/bin/chmod 600 "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "$state/status.json"
    }

    remote_control() {
      # The remote account exposes only this control command.
      ${pkgs.openssh}/bin/ssh $ssh_options "$remote" vtt-sync-control "$@"
    }

    prune_local_backups() {
      set -- $(${pkgs.findutils}/bin/find "$local_backups" -mindepth 1 -maxdepth 1 -type d -name '[0-9]*-[0-9]*' -printf '%f\n' 2>/dev/null | ${pkgs.coreutils}/bin/sort -r)
      count=0
      for backup do
        count=$((count + 1))
        [ "$count" -le 3 ] || ${pkgs.coreutils}/bin/rm -rf "$local_backups/$backup"
      done
    }

    failed() {
      code=$?
      trap - EXIT
      active_instance_started=false
      local_safe=true
      if $backup_ready; then
        if [ "$direction" = pull ]; then
          restore_data="$local_data.restore-$timestamp"
          ${pkgs.coreutils}/bin/rm -rf "$restore_data"
          if ${pkgs.coreutils}/bin/cp -a --reflink=auto "$local_backups/$timestamp" "$restore_data"; then
            ${pkgs.coreutils}/bin/rm -rf "$local_data"
            ${pkgs.coreutils}/bin/mv "$restore_data" "$local_data"
          else
            local_safe=false
            if remote_control start; then
              active_instance_started=true
            fi
          fi
        elif remote_control restore "$timestamp" && remote_control start; then
          active_instance_started=true
        fi
      fi
      if $local_stopped && ! $active_instance_started && $local_safe; then
        ${config.systemd.package}/bin/systemctl start foundry-vtt.service || true
      fi
      prune_local_backups || true
      write_status failed "Sync failed"
      exit "$code"
    }
    trap failed EXIT

    write_status running "Sync in progress"
    remote_control check
    ${config.systemd.package}/bin/systemctl stop foundry-vtt.service
    local_stopped=true
    remote_control stop

    if [ "$direction" = pull ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$local_data" "$local_backups"
      ${pkgs.coreutils}/bin/cp -a --reflink=auto "$local_data" "$local_backups/$timestamp"
      backup_ready=true
      ${pkgs.rsync}/bin/rsync --archive --no-owner --no-group --no-perms --omit-dir-times --delete \
        -e "${pkgs.openssh}/bin/ssh $ssh_options" "$remote:$remote_data/" "$local_data/"
      ${pkgs.coreutils}/bin/chown -R ${config.vtt.common.userName}:users "$local_data"
      ${config.systemd.package}/bin/systemctl start foundry-vtt.service
      local_stopped=false
      backup_ready=false
      prune_local_backups
    else
      remote_control backup "$timestamp"
      backup_ready=true
      ${pkgs.rsync}/bin/rsync --archive --no-owner --no-group --no-perms --omit-dir-times --delete \
        -e "${pkgs.openssh}/bin/ssh $ssh_options" "$local_data/" "$remote:$remote_data/"
      remote_control start
      backup_ready=false
    fi

    trap - EXIT
    write_status succeeded "Sync completed"
  '';
in {
  environment.systemPackages = [ pkgs.rsync pkgs.openssh ];

  systemd.services."vtt-sync@" = {
    description = "Synchronize Foundry data (%i)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${syncScript} %i";
      TimeoutStartSec = "30min";
      StateDirectory = "vtt-sync";
      StateDirectoryMode = "0700";
      UMask = "0077";
    };
  };
}

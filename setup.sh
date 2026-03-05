#!/bin/bash
# adguard management script
# Usage: ./setup.sh <command> [args]
set -eo pipefail

[ "$EUID" -eq 0 ] && {
	echo "ERROR: Don't run with sudo. Script uses sudo internally."
	exit 1
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Helpers
info() { echo -e "${BLUE}${BOLD}::${NC} $*"; }
ok() { echo -e "${GREEN}${BOLD}ok${NC} $*"; }
warn() { echo -e "${YELLOW}${BOLD}warn${NC} $*"; }
err() { echo -e "${RED}${BOLD}err${NC} $*"; }
header() { echo -e "\n${BOLD}━━━ $* ━━━${NC}"; }
dim() { echo -e "${DIM}  $*${NC}"; }

# Config
USER_HOME="/home/pi"
SUDO="sudo"
REPO_DIR="$USER_HOME/adguard"

# NFS config
NAS_IP="192.168.4.219"
NFS_MOUNTS=(
	"backup|/volume1/backup|$USER_HOME/backup"
)

#=============================================================================
# SETUP - Create directories
#=============================================================================
cmd_setup() {
	header "Creating directories"
	local dirs=(
		"$USER_HOME/backup/adguard"
		"$USER_HOME/data/adguard/borgmatic"
	)
	for dir in "${dirs[@]}"; do
		if [ ! -d "$dir" ]; then
			mkdir -p "$dir"
			dim "Created: $dir"
		else
			dim "Exists: $dir"
		fi
	done
	ok "Done"
}

#=============================================================================
# NFS - Mount/unmount NFS shares
#=============================================================================
nfs_mount() {
	local name=$1 nas_path=$2 local_path=$3
	if mountpoint -q "$local_path" 2>/dev/null; then
		dim "$name: Already mounted"
		return
	fi
	info "Mounting $name: $NAS_IP:$nas_path -> $local_path"
	mkdir -p "$local_path"
	$SUDO mount -t nfs "$NAS_IP:$nas_path" "$local_path" && ok "$name" || err "$name failed"
}

nfs_unmount() {
	local name=$1 nas_path=$2 local_path=$3
	info "Unmounting $name: $local_path"
	$SUDO umount "$local_path" 2>/dev/null && ok "$name" || dim "Not mounted"
}

nfs_status() {
	local name=$1 nas_path=$2 local_path=$3
	if mountpoint -q "$local_path" 2>/dev/null; then
		printf "${GREEN}%-10s${NC} MOUNTED   " "$name:"
		df -h "$local_path" | awk 'NR==2 {print $3"/"$2" ("$5" used)"}'
	else
		printf "${RED}%-10s${NC} NOT MOUNTED\n" "$name:"
	fi
}

cmd_nfs() {
	local action=$1 target=${2:-all}
	[ -z "$action" ] && {
		echo -e "Usage: $0 nfs {mount|unmount|status} [backup|all]"
		exit 1
	}

	for mount in "${NFS_MOUNTS[@]}"; do
		IFS='|' read -r name nas_path local_path <<<"$mount"
		if [[ "$target" == "all" || "$target" == "$name" ]]; then
			case "$action" in
			mount) nfs_mount "$name" "$nas_path" "$local_path" ;;
			unmount | umount) nfs_unmount "$name" "$nas_path" "$local_path" ;;
			status) nfs_status "$name" "$nas_path" "$local_path" ;;
			esac
		fi
	done
}

#=============================================================================
# INSTALL - Full setup and deploy
#=============================================================================
cmd_install() {
	header "Installing AdGuard"
	cmd_nfs mount all
	cmd_setup
	info "Starting containers..."
	$SUDO docker compose up -d
	cmd_borgmatic_init
	header "Done"
	cmd_status
}

#=============================================================================
# UPDATE - Pull latest and redeploy
#=============================================================================
cmd_update() {
	header "Updating AdGuard"
	cd "$REPO_DIR"
	info "Pulling latest..."
	git pull
	info "Pulling images..."
	$SUDO docker compose pull
	info "Redeploying..."
	$SUDO docker compose up -d
	header "Done"
	cmd_status
}

#=============================================================================
# RESTART - Down + up
#=============================================================================
cmd_restart() {
	header "Restarting AdGuard"
	cd "$REPO_DIR"
	$SUDO docker compose down
	$SUDO docker compose up -d
	header "Done"
	cmd_status
}

#=============================================================================
# BORGMATIC-INIT - Initialize borg repo
#=============================================================================
cmd_borgmatic_init() {
	header "Borgmatic Init"
	if $SUDO docker exec adguard-borgmatic borg info /repository &>/dev/null; then
		dim "adguard-borgmatic: already initialized"
	elif $SUDO docker exec adguard-borgmatic borgmatic init --encryption repokey-blake2; then
		ok "adguard-borgmatic: initialized"
	else
		err "adguard-borgmatic: failed"
	fi
}

#=============================================================================
# BORGMATIC-BACKUP - Run backup
#=============================================================================
cmd_borgmatic_backup() {
	header "Borgmatic Backup"
	if $SUDO docker exec adguard-borgmatic borgmatic create --verbosity 1; then
		ok "Backup complete"
	else
		err "Backup failed"
	fi
}

#=============================================================================
# STATUS - Show current status
#=============================================================================
cmd_status() {
	header "Status"
	echo ""
	echo -e "${BOLD}Containers:${NC}"
	$SUDO docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || dim "None"
	echo ""
	echo -e "${BOLD}NFS Mounts:${NC}"
	cmd_nfs status
}

#=============================================================================
# MAIN
#=============================================================================
case "${1:-}" in
install)
	cmd_install
	;;
update)
	cmd_update
	;;
restart)
	cmd_restart
	;;
setup)
	cmd_setup
	;;
nfs)
	shift
	cmd_nfs "$@"
	;;
borgmatic-init)
	cmd_borgmatic_init
	;;
borgmatic-backup)
	cmd_borgmatic_backup
	;;
status)
	cmd_status
	;;
*)
	echo -e "${BOLD}adguard${NC} management script"
	echo ""
	echo -e "Usage: ${CYAN}$0${NC} <command>"
	echo ""
	echo -e "${BOLD}Commands:${NC}"
	echo -e "  ${GREEN}install${NC}            Full setup: NFS, dirs, compose up, borgmatic init"
	echo -e "  ${GREEN}update${NC}             Pull latest and redeploy"
	echo -e "  ${GREEN}restart${NC}            Down + up"
	echo -e "  ${GREEN}setup${NC}              Create data/backup directories"
	echo -e "  ${GREEN}nfs mount${NC}          Mount NFS backup share"
	echo -e "  ${GREEN}nfs unmount${NC}        Unmount NFS backup share"
	echo -e "  ${GREEN}nfs status${NC}         Show NFS mount status"
	echo -e "  ${GREEN}borgmatic-init${NC}     Initialize borg repo"
	echo -e "  ${GREEN}borgmatic-backup${NC}   Run backup now"
	echo -e "  ${GREEN}status${NC}             Show containers and mounts"
	exit 1
	;;
esac

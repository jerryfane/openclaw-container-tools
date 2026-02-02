#!/bin/bash
# Efficient Workspace to R2 Sync Script
# Syncs OpenClaw workspace (/root/clawd or custom path) to R2 with incremental updates, exclusions, and deletion tracking

set -e

# Configuration
# Allow override via environment variable, with smart defaults
if [ -n "$WORKSPACE_DIR" ]; then
    # Use environment variable if set
    WORKSPACE_DIR="$WORKSPACE_DIR"
elif [ -d "/root/clawd" ]; then
    # Use OpenClaw/Clawdbot workspace if it exists
    WORKSPACE_DIR="/root/clawd"
elif [ -d "/workspace" ]; then
    # Fall back to /workspace if it exists
    WORKSPACE_DIR="/workspace"
else
    # Default to OpenClaw standard location
    WORKSPACE_DIR="/root/clawd"
fi

R2_MOUNT_PATH="/data/moltbot"
BACKUP_SUBDIR="workspace"
TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S")
MAX_SIZE_GB=10  # Maximum size in GB to sync (safety limit)
DRY_RUN="${DRY_RUN:-false}"  # Set DRY_RUN=true to test without syncing

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Common exclusions for efficiency
EXCLUSIONS=(
    # Package managers
    "node_modules"
    ".npm"
    "bower_components"

    # Python
    "__pycache__"
    "*.pyc"
    "*.pyo"
    "*.pyd"
    ".Python"
    "pip-log.txt"
    "pip-delete-this-directory.txt"
    ".venv"
    "venv"
    "ENV"
    "env"
    ".pytest_cache"
    ".tox"

    # Build outputs
    "dist"
    "build"
    "*.egg-info"
    "target"
    "out"
    "bin"
    "obj"

    # Version control
    ".git"
    ".svn"
    ".hg"
    ".bzr"

    # IDE
    ".idea"
    ".vscode"
    "*.swp"
    "*.swo"
    "*~"
    ".DS_Store"

    # Logs and temp files
    "*.log"
    "logs"
    "*.tmp"
    "*.temp"
    "tmp"
    "temp"
    ".cache"

    # Large files
    "*.iso"
    "*.dmg"
    "*.zip"
    "*.tar.gz"
    "*.rar"
    "*.7z"

    # Media (optional - uncomment if needed)
    # "*.mp4"
    # "*.mov"
    # "*.avi"
)

echo "==================================================="
echo -e "${GREEN}Efficient Workspace to R2 Sync${NC}"
echo "==================================================="
echo "Timestamp: $TIMESTAMP"
echo "Source: $WORKSPACE_DIR"
echo "Destination: $R2_MOUNT_PATH/$BACKUP_SUBDIR"
echo -e "Dry Run: ${YELLOW}$DRY_RUN${NC}"
echo ""

# Check if workspace directory exists
if [ ! -d "$WORKSPACE_DIR" ]; then
    echo -e "${RED}ERROR: Workspace directory $WORKSPACE_DIR does not exist${NC}"
    exit 1
fi

# Check if R2 is mounted
if [ ! -d "$R2_MOUNT_PATH" ]; then
    echo -e "${RED}ERROR: R2 mount point $R2_MOUNT_PATH does not exist${NC}"
    echo "R2 storage may not be configured or mounted"
    exit 1
fi

# Create backup directory structure
mkdir -p "$R2_MOUNT_PATH/$BACKUP_SUBDIR"

# Build rsync exclusion arguments
RSYNC_EXCLUDES=""
for pattern in "${EXCLUSIONS[@]}"; do
    RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude='$pattern'"
done

# Check workspace size (excluding ignored files)
echo "Calculating workspace size (excluding ignored files)..."
WORKSPACE_SIZE_KB=$(eval "du -sk $WORKSPACE_DIR $RSYNC_EXCLUDES" 2>/dev/null | awk '{sum+=$1} END {print sum}')
WORKSPACE_SIZE_GB=$(echo "scale=2; $WORKSPACE_SIZE_KB / 1048576" | bc)

echo -e "Workspace size to sync: ${YELLOW}${WORKSPACE_SIZE_GB}GB${NC}"

# Safety check for size
if (( $(echo "$WORKSPACE_SIZE_GB > $MAX_SIZE_GB" | bc -l) )); then
    echo -e "${RED}ERROR: Workspace size (${WORKSPACE_SIZE_GB}GB) exceeds maximum allowed (${MAX_SIZE_GB}GB)${NC}"
    echo "Adjust MAX_SIZE_GB in the script if this is intentional"
    exit 1
fi

# Count files to sync (excluding ignored patterns)
echo "Counting files to sync..."
FILE_COUNT=$(find "$WORKSPACE_DIR" -type f 2>/dev/null | \
    grep -v -E "(node_modules|__pycache__|\.git|\.venv|venv|dist|build)" | \
    wc -l)
echo -e "Files to sync: ${YELLOW}$FILE_COUNT${NC}"
echo ""

# Save previous sync state if it exists
if [ -f "$R2_MOUNT_PATH/$BACKUP_SUBDIR/.last-sync" ]; then
    LAST_SYNC=$(cat "$R2_MOUNT_PATH/$BACKUP_SUBDIR/.last-sync")
    echo -e "Last sync: ${GREEN}$LAST_SYNC${NC}"
    cp "$R2_MOUNT_PATH/$BACKUP_SUBDIR/.last-sync" "$R2_MOUNT_PATH/$BACKUP_SUBDIR/.last-sync.prev"
fi

# Update sync timestamp
echo "$TIMESTAMP" > "$R2_MOUNT_PATH/$BACKUP_SUBDIR/.last-sync"

# Perform the sync using rsync
echo "Starting incremental sync..."
echo "Excluding: node_modules, .git, __pycache__, venv, and other large/temp files"
echo ""

if command -v rsync >/dev/null 2>&1; then
    # Build the rsync command
    RSYNC_CMD="rsync -avz --delete --delete-excluded --stats --human-readable"

    # Add progress flag for better UX
    RSYNC_CMD="$RSYNC_CMD --progress"

    # Add dry-run flag if requested
    if [ "$DRY_RUN" = "true" ]; then
        RSYNC_CMD="$RSYNC_CMD --dry-run"
        echo -e "${YELLOW}DRY RUN MODE - No files will be modified${NC}"
        echo ""
    fi

    # Add all exclusions
    for pattern in "${EXCLUSIONS[@]}"; do
        RSYNC_CMD="$RSYNC_CMD --exclude='$pattern'"
    done

    # Add source and destination
    RSYNC_CMD="$RSYNC_CMD '$WORKSPACE_DIR/' '$R2_MOUNT_PATH/$BACKUP_SUBDIR/'"

    # Execute rsync and capture statistics
    echo "Running: rsync with exclusions..."
    eval $RSYNC_CMD 2>&1 | tee /tmp/rsync_output.log
    SYNC_RESULT=${PIPESTATUS[0]}

    # Extract statistics from rsync output
    if [ -f /tmp/rsync_output.log ]; then
        echo ""
        echo "Sync Statistics:"
        grep -E "Number of files:|Total transferred file size:|Total file size:" /tmp/rsync_output.log || true
        rm -f /tmp/rsync_output.log
    fi
else
    echo -e "${YELLOW}Warning: rsync not available, using fallback method (less efficient)${NC}"

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}DRY RUN MODE - Listing files that would be synced${NC}"
        find "$WORKSPACE_DIR" -type f | \
            grep -v -E "(node_modules|__pycache__|\.git|\.venv|venv|dist|build)" | \
            head -20
        echo "... and more"
        SYNC_RESULT=0
    else
        # Clean destination first (manual deletion sync)
        echo "Cleaning destination of deleted files..."
        find "$R2_MOUNT_PATH/$BACKUP_SUBDIR" -mindepth 1 -maxdepth 1 ! -name '.last-sync*' ! -name '.sync-complete' -type d | \
            while read -r dir; do
                basename_dir=$(basename "$dir")
                if [ ! -e "$WORKSPACE_DIR/$basename_dir" ]; then
                    echo "  Removing deleted directory: $basename_dir"
                    rm -rf "$dir"
                fi
            done

        # Copy with tar for better preservation and exclusion handling
        echo "Syncing with tar (excluding large directories)..."
        tar -czf - \
            --exclude='node_modules' \
            --exclude='__pycache__' \
            --exclude='.git' \
            --exclude='venv' \
            --exclude='.venv' \
            --exclude='dist' \
            --exclude='build' \
            --exclude='*.pyc' \
            --exclude='*.log' \
            -C "$WORKSPACE_DIR" . | \
            tar -xzf - -C "$R2_MOUNT_PATH/$BACKUP_SUBDIR/"
        SYNC_RESULT=$?
    fi
fi

echo ""
if [ $SYNC_RESULT -eq 0 ]; then
    echo -e "${GREEN}✅ Sync completed successfully!${NC}"

    if [ "$DRY_RUN" != "true" ]; then
        # Show summary of synced content
        echo ""
        echo "Top-level synced items:"
        ls -lah "$R2_MOUNT_PATH/$BACKUP_SUBDIR/" 2>/dev/null | head -15

        # Calculate final synced size
        SYNCED_SIZE=$(du -sh "$R2_MOUNT_PATH/$BACKUP_SUBDIR" 2>/dev/null | cut -f1)
        echo ""
        echo -e "Total synced size: ${GREEN}$SYNCED_SIZE${NC}"

        # Update completion timestamp
        echo "$TIMESTAMP" > "$R2_MOUNT_PATH/$BACKUP_SUBDIR/.sync-complete"

        # Show what was excluded
        echo ""
        echo "Excluded from sync:"
        echo "  - node_modules directories"
        echo "  - Python cache and virtual environments"
        echo "  - Build/dist directories"
        echo "  - Version control (.git)"
        echo "  - IDE files and temp files"
    fi
else
    echo -e "${RED}❌ Sync failed with exit code: $SYNC_RESULT${NC}"

    # Restore previous sync timestamp on failure
    if [ -f "$R2_MOUNT_PATH/$BACKUP_SUBDIR/.last-sync.prev" ]; then
        mv "$R2_MOUNT_PATH/$BACKUP_SUBDIR/.last-sync.prev" "$R2_MOUNT_PATH/$BACKUP_SUBDIR/.last-sync"
    fi

    exit $SYNC_RESULT
fi

echo ""
echo "==================================================="
echo -e "${GREEN}Sync complete at $(date -u +"%Y-%m-%d %H:%M:%S UTC")${NC}"
echo "===================================================="
echo ""
echo "Usage tips:"
echo "  - Run with DRY_RUN=true to preview changes"
echo "  - Adjust MAX_SIZE_GB if you need to sync larger workspaces"
echo "  - Edit EXCLUSIONS array to customize ignored files"
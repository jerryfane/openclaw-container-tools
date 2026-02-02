# Workspace to R2 Sync Script

## Overview
The `sync-workspace-to-r2.sh` script efficiently syncs the `/workspace/` directory inside the container to R2 storage, with intelligent exclusions and deletion tracking.

## Features

### ✅ Efficient Syncing
- **Incremental updates** - Only syncs changed files
- **Compression** during transfer
- **Checksum-based** comparison
- **Progress reporting** for large syncs

### 🚫 Smart Exclusions
Automatically excludes:
- `node_modules/` - NPM packages
- `.git/` - Version control
- `__pycache__/`, `venv/`, `.venv/` - Python artifacts
- `dist/`, `build/` - Build outputs
- `*.log`, `logs/` - Log files
- `*.pyc`, `*.pyo` - Compiled Python files
- `.DS_Store`, `.idea/`, `.vscode/` - IDE/OS files
- Large archives (`*.zip`, `*.tar.gz`, etc.)

### 🗑️ Deletion Sync
- Files deleted from `/workspace/` are automatically removed from R2
- Uses `--delete` flag with rsync for accurate mirroring

### 🛡️ Safety Features
- **Size limit** (10GB default) to prevent accidental huge syncs
- **Dry-run mode** for testing
- **Backup of previous sync state**
- **Colored output** for better readability

## Usage

### Basic Sync
Run inside the container:
```bash
./sync-workspace-to-r2.sh
```

### Dry Run (Preview Changes)
See what would be synced without making changes:
```bash
DRY_RUN=true ./sync-workspace-to-r2.sh
```

### Custom Size Limit
Edit the script to change `MAX_SIZE_GB` if you need to sync larger workspaces.

## How It Works

1. **Checks R2 Mount**: Verifies `/data/moltbot` is mounted
2. **Calculates Size**: Computes workspace size excluding ignored files
3. **Safety Check**: Ensures size is under limit
4. **Incremental Sync**: Uses rsync (or tar fallback) to sync files
5. **Deletion Tracking**: Removes files from R2 that no longer exist locally
6. **Updates Timestamps**: Records sync completion time

## R2 Structure

```
/data/moltbot/
├── workspace/           # Synced workspace files
│   ├── .last-sync      # Timestamp of last sync
│   ├── .sync-complete  # Successful sync marker
│   └── [your files]    # All workspace content (minus exclusions)
├── clawdbot/           # Moltbot config (separate)
└── skills/             # Moltbot skills (separate)
```

## Performance Tips

1. **Regular Syncs**: Run frequently for smaller, faster incremental updates
2. **Exclusions**: Add project-specific exclusions to the EXCLUSIONS array
3. **Network**: Sync performs better with stable network connections
4. **File Count**: Works best with < 100k files after exclusions

## Troubleshooting

### "R2 mount point does not exist"
- R2 credentials may not be configured
- Container may not have mounted R2 successfully
- Check worker logs for mount errors

### "Workspace size exceeds maximum"
- Adjust `MAX_SIZE_GB` in the script
- Add more exclusions for large directories
- Clean up unnecessary files in workspace

### Sync is slow
- First sync is always slower (full copy)
- Subsequent syncs are incremental (faster)
- Consider adding more exclusions
- Check network performance

## Automation

To run automatically, add to crontab inside container:
```bash
# Sync workspace every hour
0 * * * * /sync-workspace-to-r2.sh >> /var/log/workspace-sync.log 2>&1
```

Or trigger from the Worker's scheduled handler for better control.
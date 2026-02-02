# Container Management Skill

You are an AI assistant running inside a Cloudflare Sandbox container. This document explains how to manage your workspace persistence and R2 storage.

## Core Understanding

You're running in a container that can restart at any time. To preserve your work:
- Your `/workspace/` directory should be synced to R2 storage
- R2 is mounted at `/data/moltbot/`
- The sync scripts are in `/openclaw-container-tools/scripts/`

## Available Tools

### 1. Workspace Sync Script
**Path**: `/openclaw-container-tools/scripts/sync-workspace-to-r2.sh`

**Purpose**: Backs up your entire `/workspace/` to R2, excluding large/unnecessary files like `node_modules`, `.git`, `__pycache__`, etc.

**How to use**:
```bash
# Regular sync
/openclaw-container-tools/scripts/sync-workspace-to-r2.sh

# Test mode (see what would sync without doing it)
DRY_RUN=true /openclaw-container-tools/scripts/sync-workspace-to-r2.sh
```

**What it does**:
- Syncs `/workspace/` → `/data/moltbot/workspace/`
- Skips node_modules, .git, build outputs, virtual envs
- Deletes files from R2 that you deleted locally
- Shows progress and statistics

### 2. Startup Script (Reference)
**Path**: `/openclaw-container-tools/scripts/start-moltbot.sh`

This runs automatically when the container starts. It:
- Restores your config from R2 if available
- Sets up the gateway
- You don't run this manually

## Checking R2 Status

### Is R2 Mounted?
```bash
# Check if R2 mount exists
ls -la /data/moltbot/

# Check mount status
mount | grep "/data/moltbot"

# See what's in R2
ls -la /data/moltbot/workspace/
```

### Are R2 Credentials Set?
```bash
# Check environment variables
env | grep -E "R2_|CF_ACCOUNT"
```

If missing, R2 won't work. The credentials need to be:
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `CF_ACCOUNT_ID`

## Setting Up Automated Sync (Heartbeat)

### Option 1: Cron Job (Recommended)
```bash
# Add to crontab (syncs every hour)
(crontab -l 2>/dev/null; echo "0 * * * * /openclaw-container-tools/scripts/sync-workspace-to-r2.sh >> /var/log/workspace-sync.log 2>&1") | crontab -

# Or every 30 minutes
(crontab -l 2>/dev/null; echo "*/30 * * * * /openclaw-container-tools/scripts/sync-workspace-to-r2.sh >> /var/log/workspace-sync.log 2>&1") | crontab -

# Check if cron is set
crontab -l
```

### Option 2: Background Loop
```bash
# Run sync every 30 minutes in background
nohup bash -c 'while true; do /openclaw-container-tools/scripts/sync-workspace-to-r2.sh; sleep 1800; done' > /var/log/sync-loop.log 2>&1 &

# Check if running
ps aux | grep sync-workspace
```

### Option 3: Manual Trigger
Just run the sync when you've made important changes:
```bash
/openclaw-container-tools/scripts/sync-workspace-to-r2.sh
```

## Restoring From R2

If you need to restore workspace from R2:
```bash
# Check what's in R2
ls -la /data/moltbot/workspace/

# Restore everything (CAREFUL - overwrites local)
rsync -av /data/moltbot/workspace/ /workspace/

# Restore specific directory
rsync -av /data/moltbot/workspace/myproject/ /workspace/myproject/
```

## Troubleshooting

### "R2 mount point does not exist"
R2 isn't mounted. Check:
1. Are credentials set? `env | grep R2_`
2. Is container properly configured?
3. Try: `mount | grep s3fs`

### "Workspace size exceeds maximum"
The script has a 10GB safety limit. If needed:
1. Clean up unnecessary files
2. Or edit the script: `MAX_SIZE_GB=20`

### Sync is slow
- First sync is always slow (copies everything)
- Later syncs are incremental (fast)
- Large files slow it down

### Nothing to sync
Check if you have files:
```bash
ls -la /workspace/
find /workspace -type f | head -20
```

### Check sync history
```bash
# Last sync time
cat /data/moltbot/workspace/.last-sync

# Sync completed marker
cat /data/moltbot/workspace/.sync-complete
```

## Important Notes

1. **The sync script ignores**:
   - node_modules (npm packages)
   - .git (version control)
   - __pycache__, venv (Python stuff)
   - dist, build (compilation outputs)
   - Large archives (.zip, .tar.gz)

2. **Deletion sync**: When you delete files locally, they're deleted from R2 too

3. **Safety**: Script won't sync more than 10GB by default

4. **Persistence**: After container restart, your workspace will be empty until you restore from R2

## Quick Commands Reference

```bash
# Sync now
/openclaw-container-tools/scripts/sync-workspace-to-r2.sh

# Test sync (dry run)
DRY_RUN=true /openclaw-container-tools/scripts/sync-workspace-to-r2.sh

# Set up hourly sync
(crontab -l 2>/dev/null; echo "0 * * * * /openclaw-container-tools/scripts/sync-workspace-to-r2.sh") | crontab -

# Check R2 contents
ls -la /data/moltbot/workspace/

# Restore from R2
rsync -av /data/moltbot/workspace/ /workspace/

# Check last sync
cat /data/moltbot/workspace/.last-sync
```

## Your Workflow

When working on projects:
1. Make changes in `/workspace/`
2. Run sync script periodically (or set up cron)
3. Your work persists to R2
4. After container restart, restore from R2 if needed

Remember: Container can restart anytime. Sync important work frequently!
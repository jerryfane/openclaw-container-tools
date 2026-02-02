# OpenClaw Container Tools

A collection of utilities and scripts for managing OpenClaw (formerly Moltbot/Clawdbot) containers running in Cloudflare Sandbox environments.

## 🚀 Overview

This repository contains essential tools for:
- **Workspace synchronization** with R2 storage
- **Container lifecycle management**
- **Data persistence** across container restarts
- **Backup and recovery** operations

These tools are designed to work with [OpenClaw on Cloudflare Workers](https://github.com/cloudflare/moltworker).

## 📁 Repository Structure

```
openclaw-container-tools/
├── scripts/                      # Executable scripts
│   ├── sync-workspace-to-r2.sh  # Workspace → R2 sync utility
│   └── start-moltbot.sh         # Container startup script
├── skill.md                      # AI assistant instructions
└── README.md                     # This file
```

## 🛠️ Tools

### 1. Workspace to R2 Sync (`sync-workspace-to-r2.sh`)

Efficiently syncs the `/workspace/` directory to R2 storage with intelligent filtering.

**Features:**
- ✅ Incremental syncing (only changed files)
- 🚫 Smart exclusions (node_modules, .git, etc.)
- 🗑️ Deletion tracking (removes deleted files from R2)
- 🛡️ Safety limits and dry-run mode
- 📊 Progress reporting with statistics

**Quick Usage:**
```bash
# Inside the container
./scripts/sync-workspace-to-r2.sh

# Dry run (preview changes)
DRY_RUN=true ./scripts/sync-workspace-to-r2.sh
```

### 2. Container Startup Script (`start-moltbot.sh`)

Manages OpenClaw gateway initialization with R2 persistence.

**Features:**
- 📥 Restores configuration from R2 backup
- ⚙️ Configures environment from secrets
- 💾 Background sync to R2
- 🚀 Starts the gateway service

## 🔧 Prerequisites

### Required
- OpenClaw container running in Cloudflare Sandbox
- R2 bucket configured (`moltbot-data`)
- R2 credentials set as environment variables:
  - `R2_ACCESS_KEY_ID`
  - `R2_SECRET_ACCESS_KEY`
  - `CF_ACCOUNT_ID`

### Optional
- `rsync` for efficient syncing (falls back to tar if unavailable)
- `bc` for size calculations

## 📦 Installation

### In Container

1. Clone this repository inside your container:
```bash
cd /
git clone https://github.com/yourusername/openclaw-container-tools.git
```

2. Make scripts executable:
```bash
chmod +x /openclaw-container-tools/scripts/*.sh
```

3. Run tools as needed:
```bash
/openclaw-container-tools/scripts/sync-workspace-to-r2.sh
```

### As Part of Docker Image

Add to your Dockerfile:
```dockerfile
# Copy container tools
COPY openclaw-container-tools /openclaw-container-tools
RUN chmod +x /openclaw-container-tools/scripts/*.sh
```

## 📊 R2 Storage Structure

After syncing, your R2 bucket will have:

```
moltbot-data/
├── workspace/           # Synced workspace files
│   ├── .last-sync      # Last sync timestamp
│   ├── .sync-complete  # Successful sync marker
│   └── [your files]    # Workspace content
├── clawdbot/           # OpenClaw configuration
│   ├── clawdbot.json   # Main config
│   ├── devices.json    # Paired devices
│   └── conversations/  # Chat history
└── skills/             # OpenClaw skills
```

## ⚡ Performance Tips

1. **Regular Syncs**: Run frequently for smaller incremental updates
2. **Exclusions**: Customize the EXCLUSIONS array in the sync script
3. **Size Limits**: Adjust MAX_SIZE_GB for larger workspaces
4. **Network**: Stable connections improve sync performance

## 🤖 Automation

### Cron Job (Inside Container)
```bash
# Add to container's crontab
0 * * * * /openclaw-container-tools/scripts/sync-workspace-to-r2.sh
```

### Cloudflare Worker Scheduled Trigger
```javascript
// In your worker's scheduled handler
async function scheduled(event, env, ctx) {
  const sandbox = getSandbox(env.Sandbox);
  await sandbox.startProcess('/openclaw-container-tools/scripts/sync-workspace-to-r2.sh');
}
```

## 🐛 Troubleshooting

### Common Issues

**"R2 mount point does not exist"**
- Verify R2 credentials are set
- Check if R2 is properly mounted at `/data/moltbot`

**"Workspace size exceeds maximum"**
- Adjust MAX_SIZE_GB in the script
- Add more exclusions for large directories

**Sync is slow**
- First sync is always slower
- Add more exclusions
- Check network performance

## 📄 License

MIT License - See LICENSE file for details

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## 🔗 Related Projects

- [OpenClaw](https://github.com/openclaw/openclaw) - The main OpenClaw project
- [Moltworker](https://github.com/cloudflare/moltworker) - OpenClaw on Cloudflare Workers
- [Cloudflare Sandbox](https://developers.cloudflare.com/sandbox/) - Container runtime documentation

## 📮 Support

For issues and questions:
- Open an issue in this repository
- Check the [docs](./docs/) folder for detailed guides
- Join the OpenClaw community discussions

---

Made with ❤️ for the OpenClaw community
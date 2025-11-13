# Devcontainer Sandbox

A standalone devcontainer repository providing shared services, tooling, and configuration for a multi-repo development environment.

## Features

- **Shared Services**: Redis (Valkey), MySQL 8, LocalStack (S3, SQS, SNS)
- **Development Tools**: PHP 8.3 CLI with full extension suite (bcmath, ftp, gd, intl, mbstring, mysqli, opcache, pcntl, pdo, pdo_mysql, pdo_pgsql, soap, sockets, zip, apcu, redis), Composer, Xdebug, Git, GitHub CLI, Docker, kubectl, Vault CLI, fnm (Node.js), Redis CLI, MySQL CLI
- **Multi-Repo Management**: Automatic repo cloning and composer-link setup
- **Persistent Storage**: Shell history and auth configs persist across rebuilds
- **Multi-Platform**: Supports Linux, macOS, and Windows (WSL2)

## Quick Start

1. Clone this repository
2. Copy `.devcontainer/.env.example` to `.env` and configure repositories
3. Open in VS Code/Cursor and click "Reopen in Container"
4. Services will start automatically, and repositories will be cloned if configured

## Configuration

### Environment Configuration

Copy `.devcontainer/.env.example` to `.env` (workspace root) and configure as needed:

```bash
# Repository Configuration
REPOS_TO_CLONE=batch,common
COMPOSER_LINK_COMMON=true
COMMON_REPO_PATH=/workspace/common

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
# REDIS_EXTERNAL_PORT is for host port exposure (default: 6379)
# Internal Docker network uses ${REDIS_HOST}:${REDIS_PORT} (default: redis:6379)

# MySQL Configuration
MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_USER=dev
MYSQL_PASSWORD=dev
MYSQL_DATABASE=dev
# MYSQL_EXTERNAL_PORT is for host port exposure (default: 3306)
# Internal Docker network uses ${MYSQL_HOST}:${MYSQL_PORT} (default: mysql:3306)

# LocalStack Configuration
LOCALSTACK_PORT=4566
# LOCALSTACK_EXTERNAL_PORT is for host port exposure (default: 4566)
# LOCALSTACK_EXTERNAL_PORT_RANGE_START and LOCALSTACK_EXTERNAL_PORT_RANGE_END for port range (default: 4510-4559)
# Internal Docker network uses http://localstack:${LOCALSTACK_PORT} (default: http://localstack:4566)
```

All scripts load environment variables from `.env` (workspace root) with sensible defaults. You can override any value by setting it in `.env`.

### Setup Command

The `setup` command provides modular functions for configuring the devcontainer:

```bash
setup <command> [args...]
```

Available commands:
- `setup packagist-auth <username> <token>` - Configure Private Packagist authentication
- `setup npmrc [token]` - Configure npm authentication (or use NPM_TOKEN env var)
- `setup composer-link` - Link common repo to all workspace repositories
- `setup github-cli` - Check GitHub CLI authentication status

Examples:
```bash
setup packagist-auth myuser mytoken
setup npmrc my-npm-token
setup composer-link
```

### Adding New Repositories

Add repositories to `REPOS_TO_CLONE` in `.env`:

```bash
REPOS_TO_CLONE=batch,common,new-repo
```

The setup script will clone repositories from the `encodium` organization if they don't already exist in `/workspace`.

### Mounting External Directories

You can mount external directories into the workspace by configuring `workspaceMounts` in `devcontainer.json`:

```json
"workspaceMounts": [
  "source=/path/to/external/repo,target=/workspace/my-repo,type=bind"
]
```

## Services

### Redis (Valkey)

- **Internal Docker Network**: `${REDIS_HOST:-redis}:6379` (use for tooling inside container)
- **External Host**: `localhost:${REDIS_EXTERNAL_PORT:-6379}` (from host, configurable via `REDIS_EXTERNAL_PORT` in `.env`)
- **Host**: `${REDIS_HOST:-redis}` (configurable via `REDIS_HOST` in `.env`, defaults to `redis`)
- **CLI Tool**: Redis CLI is installed via devcontainer feature
- **Alias**: `redis` (connects to Redis service using standard port 6379)

### MySQL

- **Internal Docker Network**: `${MYSQL_HOST:-mysql}:3306` (use for tooling inside container)
- **External Host**: `localhost:${MYSQL_EXTERNAL_PORT:-3306}` (from host, configurable via `MYSQL_EXTERNAL_PORT` in `.env`)
- **Host**: `${MYSQL_HOST:-mysql}` (configurable via `MYSQL_HOST` in `.env`, defaults to `mysql`)
- **User**: `dev` (configurable via `MYSQL_USER` in `.env`)
- **Password**: `dev` (configurable via `MYSQL_PASSWORD` in `.env`)
- **Database**: `dev` (configurable via `MYSQL_DATABASE` in `.env`)
- **CLI Tool**: MySQL CLI is installed via devcontainer feature
- **Alias**: `mysql` (connects to MySQL service using standard port 3306)

### LocalStack (AWS Services)

- **Internal Docker Network**: `http://localstack:4566` (use for tooling inside container)
- **External Host**: `http://localhost:${LOCALSTACK_EXTERNAL_PORT:-4566}` (from host, configurable via `LOCALSTACK_EXTERNAL_PORT` in `.env`)
- **Services**: S3, SQS, SNS
- **Credentials**: 
  - `AWS_ACCESS_KEY_ID=test`
  - `AWS_SECRET_ACCESS_KEY=test`
  - `AWS_DEFAULT_REGION=us-east-1`
- **Aliases**: `awslocal` (AWS CLI with LocalStack endpoint)

## Authentication

Authentication credentials persist in the home volume across container rebuilds. Use the `setup` command to configure authentication:

### GitHub CLI

```bash
setup github-cli
# Or run directly: gh auth login
```

### Composer (Private Packagist)

```bash
setup packagist-auth <username> <token>
# Get credentials from: https://packagist.com/profile/auth
```

### npm

```bash
setup npmrc <token>
# Or set NPM_TOKEN environment variable
```

### SSH

SSH agent forwarding is automatically configured via the `SSH_AUTH_SOCK` environment variable. The host's SSH agent socket is mounted into the container, allowing you to use your host's SSH keys without copying them into the container.

## Composer Link

The `common` repository can be linked to all other repositories using [composer-link](https://github.com/SanderSander/composer-link). The path to the common repository is configurable via `COMMON_REPO_PATH` in `.env` (defaults to `/workspace/common`).

To link common to all workspace repositories:

```bash
setup composer-link
# Or use the standalone command: link-common
```

To manually link a specific repo:

```bash
cd /workspace/my-repo
composer link ${COMMON_REPO_PATH:-/workspace/common}
```

To unlink:

```bash
composer unlink /workspace/common
```

## Shell Aliases

- `redis` - Connect to Redis (uses `REDIS_HOST` from `.env`, always uses port 6379)
- `mysql` - Connect to MySQL (uses `MYSQL_HOST`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DATABASE` from `.env`, always uses port 3306)
- `awslocal` - AWS CLI with LocalStack endpoint (always uses port 4566)
- `test-services` - Test connectivity to all services

All aliases use standard internal ports (6379, 3306, 4566) and respect host/hostname environment variables set in `.env`. The `*_HOST` variables control the Docker network hostname, while `*_EXTERNAL_PORT` variables control host port forwarding.

## Xdebug Configuration

### VS Code/Cursor

Xdebug is pre-configured for VS Code/Cursor. The debugger listens on port 9003.

### PHPStorm

1. Go to `File > Settings > Languages & Frameworks > PHP > Debug`
2. Set `xdebug.client_host` to `host.docker.internal` (or your host IP)
3. Set port to `9003`
4. Configure server mapping:
   - Name: `devcontainer`
   - Host: `localhost`
   - Port: `80`
   - Path mappings: `/workspace` → your local workspace path

## Troubleshooting

### Services Not Starting

Check service status:

```bash
docker compose -f .devcontainer/compose.yaml ps
```

Start services manually:

```bash
docker compose -f .devcontainer/compose.yaml up -d
```

### Repository Cloning Fails

Ensure GitHub CLI is authenticated:

```bash
gh auth status
gh auth login
```

### Composer Link Fails

Verify the common repository exists and has a `composer.json`:

```bash
ls -la /workspace/common/composer.json
```

### SSH Agent Not Working

Check SSH agent forwarding:

```bash
echo $SSH_AUTH_SOCK
ssh-add -l
```

### Docker Socket Not Found

The devcontainer uses `docker-outside-of-docker` feature which mounts the host Docker socket. If you see socket errors:

- Linux: Ensure `/var/run/docker.sock` exists
- macOS: Docker Desktop should expose the socket automatically
- Windows/WSL2: Ensure Docker Desktop is running

### Port Conflicts

If host ports are already in use, modify `.env` to use different external ports:

```bash
REDIS_EXTERNAL_PORT=6380
MYSQL_EXTERNAL_PORT=3307
LOCALSTACK_EXTERNAL_PORT=4567
LOCALSTACK_EXTERNAL_PORT_RANGE_START=4520
LOCALSTACK_EXTERNAL_PORT_RANGE_END=4569
```

Note: `*_EXTERNAL_PORT` environment variables only affect the host port exposure. Inside containers and the Docker network, services use `${*_HOST}:${*_PORT}` (defaults: `redis:6379`, `mysql:3306`, `localstack:4566`). The `*_HOST` variables control the Docker network hostname, and `*_PORT` variables control the internal port (though these rarely need to be changed).

## Networking

Services are accessible via the `rp` network. 

**Inside containers/Docker network:**
- Use service names with standard ports: `${REDIS_HOST:-redis}:6379`, `${MYSQL_HOST:-mysql}:3306`, `localstack:4566`
- Tooling (aliases, scripts) automatically use standard ports and `*_HOST` variables

**From host machine:**
- Use `localhost` with external ports (e.g., `localhost:${REDIS_EXTERNAL_PORT:-6379}`, `localhost:${MYSQL_EXTERNAL_PORT:-3306}`)
- Port environment variables control host port exposure only

To connect an external container to the network:

```bash
docker network connect rp <container-name>
```

## Git-in-Git Handling

The `workspace/` directory is automatically excluded from the parent repository's git tracking using `.git/info/exclude`. This prevents git-in-git issues when cloning repositories into the workspace.

## Persistence

The entire `/home/vscode` directory is persisted in a Docker volume (`home-data`) that persists across container rebuilds. This includes:

- Shell history (`.zsh_history`, `.mysql_history`, `.rediscli_history`)
- GitHub CLI authentication (`~/.config/gh`)
- Composer global configs and auth (`~/.composer`)
- npm configs (`~/.npmrc`, `~/.npm`)
- All other home directory files and configurations

Note: SSH keys are not stored in the volume. SSH agent forwarding is used instead (see Authentication section).

### Managing the Home Volume

The `home-data` volume is automatically created and managed by Docker Compose. To manage it:

**View volume information:**
```bash
docker volume inspect devcontainer_home-data
```

**Backup the volume:**
```bash
docker run --rm -v devcontainer_home-data:/data -v $(pwd):/backup alpine tar czf /backup/home-data-backup.tar.gz -C /data .
```

**Restore the volume:**
```bash
docker run --rm -v devcontainer_home-data:/data -v $(pwd):/backup alpine sh -c "cd /data && rm -rf * && tar xzf /backup/home-data-backup.tar.gz"
```

**Remove the volume (WARNING: This deletes all persisted data):**
```bash
docker volume rm devcontainer_home-data
```

### Devcontainer Features and Volume Updates

Devcontainer features (like zsh/oh-my-zsh installation) run during container creation. On first run, the volume is empty and features install normally. On subsequent runs, the volume contains existing data, and features should handle this gracefully:

- Features check for existing installations before installing
- If you need to force a feature reinstall, remove the volume (see above) and rebuild
- Configuration changes in devcontainer features may require volume cleanup if they conflict with existing configs

## Multi-Platform Support

- **Linux**: Uses `/var/run/docker.sock`
- **macOS**: Uses Docker Desktop socket
- **Windows/WSL2**: Uses `/var/run/docker.sock` in WSL2

Path handling and home directory detection work across all platforms.

## PHP Extensions

The following PHP extensions are installed and enabled:

- **Core Extensions**: bcmath, ftp, gd, intl, mbstring, mysqli, opcache, pcntl, pdo, pdo_mysql, pdo_pgsql, soap, sockets, zip
- **PECL Extensions**: apcu, redis, xdebug

All extensions are configured during container build and ready to use.

## Local Devcontainer Features

This repository includes custom devcontainer features:

- `vault-cli` - HashiCorp Vault CLI
- `fnm-node` - Fast Node Manager with Node.js
- `composer-link-plugin` - Composer link plugin
- `redis-cli` - Redis CLI client tools
- `mysql-cli` - MySQL CLI client tools

These features benefit from Docker layer caching for faster rebuilds.

## Contributing

When modifying this devcontainer:

1. Test changes locally
2. Verify multi-platform compatibility
3. Update documentation
4. Ensure services start correctly
5. Test auth persistence across rebuilds



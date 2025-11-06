# Devcontainer Sandbox

A standalone devcontainer repository providing shared services, tooling, and configuration for a multi-repo development environment.

## Features

- **Shared Services**: Valkey (Redis-compatible), MySQL 8, LocalStack (S3, SQS, SNS)
- **Development Tools**: PHP 8.3 CLI with full extension suite (bcmath, ftp, gd, intl, mbstring, mysqli, opcache, pcntl, pdo, pdo_mysql, pdo_pgsql, soap, sockets, zip, apcu, redis), Composer, Xdebug, Git, GitHub CLI, Docker, kubectl, Vault CLI, fnm (Node.js), Redis CLI, MySQL CLI
- **Multi-Repo Management**: Automatic repo cloning and composer-link setup
- **Persistent Storage**: Shell history and auth configs persist across rebuilds
- **Multi-Platform**: Supports Linux, macOS, and Windows (WSL2)

## Quick Start

1. Clone this repository
2. Copy `.devcontainer/.env.example` to `/workspace/.env` and configure repositories
3. Open in VS Code/Cursor and click "Reopen in Container"
4. Services will start automatically, and repositories will be cloned if configured

## Configuration

### Environment Configuration

Copy `.devcontainer/.env.example` to `/workspace/.env` (workspace root) and configure as needed:

```bash
# Repository Configuration
REPOS_TO_CLONE=batch,common
COMPOSER_LINK_COMMON=true
COMMON_REPO_PATH=/workspace/common

# MySQL Configuration
MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_USER=dev
MYSQL_PASSWORD=dev
MYSQL_DATABASE=dev

# Valkey/Redis Configuration
VALKEY_HOST=valkey
VALKEY_PORT=6379

# LocalStack Configuration
LOCALSTACK_PORT=4566
```

All scripts load environment variables from `/workspace/.env` (workspace root) with sensible defaults. You can override any value by setting it in `.env`.

### Adding New Repositories

Add repositories to `REPOS_TO_CLONE` in `/workspace/.env`:

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

### Valkey (Redis-compatible)

- **Host**: `valkey` (configurable via `VALKEY_HOST` in `/workspace/.env`)
- **Port**: `6379` (configurable via `VALKEY_PORT` in `/workspace/.env`)
- **CLI Tool**: Redis CLI is installed via devcontainer feature
- **Alias**: `redis` (connects to Valkey service)

### MySQL

- **Host**: `mysql` (configurable via `MYSQL_HOST` in `/workspace/.env`)
- **Port**: `3306` (configurable via `MYSQL_PORT` in `/workspace/.env`)
- **User**: `dev` (configurable via `MYSQL_USER` in `/workspace/.env`)
- **Password**: `dev` (configurable via `MYSQL_PASSWORD` in `/workspace/.env`)
- **Database**: `dev` (configurable via `MYSQL_DATABASE` in `/workspace/.env`)
- **CLI Tool**: MySQL CLI is installed via devcontainer feature
- **Alias**: `mysql` (connects to MySQL service)

### LocalStack (AWS Services)

- **Endpoint**: `http://localstack:4566`
- **External**: `http://localhost:4566`
- **Services**: S3, SQS, SNS
- **Credentials**: 
  - `AWS_ACCESS_KEY_ID=test`
  - `AWS_SECRET_ACCESS_KEY=test`
  - `AWS_DEFAULT_REGION=us-east-1`
- **Aliases**: `aws-cli`, `s3-ls`, `sqs-ls`, `sns-ls`

## Authentication

### GitHub CLI

The devcontainer will use your host's GitHub CLI authentication if available. If not authenticated:

```bash
gh auth login
```

### Composer (Private Packagist)

Set `COMPOSER_AUTH` environment variable or create `~/.composer/auth.json`:

```json
{
  "http-basic": {
    "packagist.example.com": {
      "username": "token",
      "password": "your-token"
    }
  }
}
```

### npm

Set `NPM_TOKEN` environment variable or create `~/.npmrc`:

```
//registry.npmjs.org/:_authToken=your-token
```

### SSH

SSH agent forwarding is automatically configured. Your host's SSH keys are mounted read-only.

## Composer Link

The `common` repository is automatically linked to all other repositories using [composer-link](https://github.com/SanderSander/composer-link). The path to the common repository is configurable via `COMMON_REPO_PATH` in `/workspace/.env` (defaults to `/workspace/common`).

To manually link:

```bash
cd /workspace/my-repo
composer link ${COMMON_REPO_PATH:-/workspace/common}
```

To unlink:

```bash
composer unlink /workspace/common
```

## Shell Aliases

- `redis` - Connect to Valkey (uses `VALKEY_HOST` and `VALKEY_PORT` from `/workspace/.env`)
- `mysql` - Connect to MySQL (uses `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DATABASE` from `/workspace/.env`)
- `aws` - AWS CLI with LocalStack endpoint
- `test-services` - Test connectivity to all services

All aliases respect environment variables set in `/workspace/.env` and fall back to defaults if not set.

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

If ports are already in use, modify `/workspace/.env` to use different ports:

```bash
VALKEY_PORT=6380
MYSQL_PORT=3307
LOCALSTACK_PORT=4567
```

Or modify `compose.yaml` directly if needed.

## Networking

Services are accessible via the `rp` network. External applications can connect using:

- Service names (e.g., `mysql`, `valkey`) when on the same Docker network
- `localhost` with published ports (e.g., `localhost:3306`)

To connect an external container to the network:

```bash
docker network connect rp <container-name>
```

## Git-in-Git Handling

The `workspace/` directory is automatically excluded from the parent repository's git tracking using `.git/info/exclude`. This prevents git-in-git issues when cloning repositories into the workspace.

## Persistence

The following data persists across container rebuilds:

- Shell history (`~/.zsh_history`)
- Composer global configs (if not on host)
- npm configs (if not on host)
- Devcontainer storage volume

Host-mounted directories (if they exist):

- `~/.config/gh` - GitHub CLI config
- `~/.composer` - Composer config
- `~/.npm` - npm config
- `~/.ssh` - SSH keys (read-only)

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



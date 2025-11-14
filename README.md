# Devcontainer "Sandbox"

A standalone devcontainer repository providing shared services, tooling, and configuration for a multi-repo development environment.

## What is a Devcontainer?

A devcontainer is a Docker-based development environment that runs inside VS Code or Cursor. It provides a consistent, isolated environment with all the tools and services you need, regardless of your operating system (Windows, macOS, or Linux).

## Features

- **Shared Services**: Redis (Valkey), MySQL 8, LocalStack (S3, SQS, SNS)
- **Development Tools**: PHP 8.3 CLI with full extension suite, Composer, Xdebug, Git, GitHub CLI, Docker, kubectl, Vault CLI, Node.js (via fnm), Redis CLI, MySQL CLI
- **Multi-Repo Management**: Clone and link multiple repositories easily
- **Persistent Storage**: Shell history and authentication configs persist across rebuilds
- **Multi-Platform**: Works on Windows (WSL2), macOS, and Linux

## Prerequisites

- **VS Code** or **Cursor** installed
- **Docker Desktop** installed and running:
  - Windows: Install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
  - macOS: Install [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)
  - Linux: Install [Docker Engine](https://docs.docker.com/engine/install/)
- **Dev Containers extension** (usually installed automatically when opening a devcontainer)

## Quick Start

1. **Clone this repository** to your local machine
2. **Open in VS Code/Cursor**: Open the repository folder in your editor
3. **Reopen in Container**: When prompted, click "Reopen in Container" (or press `F1` and select "Dev Containers: Reopen in Container")
4. **Wait for setup**: The container will build and start services automatically (first time may take a few minutes)
5. **Clone your repositories**: Once inside the container, run:
   ```bash
   clone-repos batch,common
   ```
6. **Link common repository** (if needed):
   ```bash
   setup composer-link
   ```
7. **Configure authentication** (see Authentication section below)

## Available Commands

Once inside the container, you have access to these commands:

### Repository Management

- **`clone-repos [repo1,repo2,...]`** - Clone repositories from the `encodium` organization
  ```bash
  clone-repos batch,common,webstore
  # Or use default from .env: clone-repos
  ```

- **`link-common`** - Link the common repository to all workspace repositories using composer-link
  ```bash
  link-common
  ```

### Setup & Configuration

- **`setup`** - Run all setup functions (authentication, etc.)
- **`setup packagist-auth`** - Get instructions for configuring Private Packagist authentication
- **`setup npmrc`** - Configure npm authentication using GitHub CLI token
- **`setup composer-link`** - Link common repo to all workspace repositories
- **`setup github-cli`** - Check GitHub CLI authentication status

### Service Access

- **`redis`** - Connect to Redis CLI
- **`mysql`** - Connect to MySQL CLI
- **`awslocal`** - AWS CLI with LocalStack endpoint pre-configured
- **`test-services`** - Test connectivity to all services
- **`k`** - Shortcut for `kubectl`

## Configuration

### Environment Variables

You can customize the devcontainer by creating a `.env` file in the workspace root (`.devcontainer/.env.example` shows available options):

```bash
# Repository Configuration
REPOS_TO_CLONE=batch,common
COMMON_REPO_PATH=/workspace/common

# Service Configuration (optional - defaults work for most cases)
REDIS_HOST=redis
MYSQL_HOST=mysql
MYSQL_USER=dev
MYSQL_PASSWORD=dev
MYSQL_DATABASE=dev

# Port Configuration (only needed if host ports conflict)
REDIS_EXTERNAL_PORT=6379
MYSQL_EXTERNAL_PORT=3306
LOCALSTACK_EXTERNAL_PORT=4566
```

**Note**: Most users don't need to modify these. The defaults work out of the box. Only change ports if you have conflicts on your host machine.

### Adding New Repositories

Clone additional repositories anytime:

```bash
clone-repos new-repo,another-repo
```

Or add them to `REPOS_TO_CLONE` in `.env` and run `clone-repos` without arguments.

## Services

The devcontainer includes three services that start automatically:

### Redis (Valkey)

- **Inside container**: Use `redis` alias or connect to `redis:6379`
- **From host machine**: `localhost:6379` (or custom port if configured)
- **CLI**: Run `redis` command in the container

### MySQL

- **Inside container**: Use `mysql` alias or connect to `mysql:3306`
- **From host machine**: `localhost:3306` (or custom port if configured)
- **Credentials**: `dev` / `dev` (username / password)
- **Database**: `dev`
- **CLI**: Run `mysql` command in the container

### LocalStack (AWS Services)

- **Inside container**: Use `awslocal` alias or connect to `http://localstack:4566`
- **From host machine**: `http://localhost:4566` (or custom port if configured)
- **Services**: S3, SQS, SNS
- **Credentials**: `test` / `test` (access key / secret key)
- **CLI**: Run `awslocal s3 ls` or similar commands

**Testing Services**: Run `test-services` to verify all services are accessible.

## Authentication

Authentication credentials persist across container rebuilds. Configure them once and they'll be saved.

### GitHub CLI

Required for cloning repositories:

```bash
gh auth login
```

Follow the prompts to authenticate. Your credentials are saved in the persistent home volume.

### Composer (Private Packagist)

Get setup instructions:

```bash
setup packagist-auth
```

This will show you how to configure authentication. Visit https://packagist.com/orgs/encodium to get your credentials.

### npm (GitHub Packages)

Automatically configured using your GitHub CLI token:

```bash
setup npmrc
```

This uses your existing GitHub CLI authentication, so make sure `gh auth login` is done first.

### SSH

SSH agent forwarding is automatically configured. Your host's SSH keys are available in the container without copying them. Just use `git` commands normally.

## Composer Link

The `common` repository can be linked to all other repositories for local development. This allows you to test changes to common across multiple repos.

**Link common to all repositories:**
```bash
setup composer-link
```

**Unlink (if needed):**
```bash
cd /workspace/my-repo
composer unlink /workspace/common
```

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

### Container Won't Start

**Windows/macOS**: Ensure Docker Desktop is running and not paused.

**Linux**: Ensure Docker daemon is running:
```bash
sudo systemctl status docker
```

### Services Not Accessible

Test service connectivity:
```bash
test-services
```

If services show ❌, they may still be starting. Wait a minute and try again.

### Repository Cloning Fails

Ensure GitHub CLI is authenticated:
```bash
gh auth status
# If not authenticated:
gh auth login
```

### Port Conflicts

If you get port conflict errors, create `.devcontainer/.env` and set custom ports:
```bash
REDIS_EXTERNAL_PORT=6380
MYSQL_EXTERNAL_PORT=3307
LOCALSTACK_EXTERNAL_PORT=4567
```

Then rebuild the container.

### Container is Slow

First-time build downloads images and installs tools. Subsequent starts are faster. If the container feels slow:
- Check Docker Desktop resources (Settings → Resources)
- Ensure you have enough disk space
- Try restarting Docker Desktop

## How It Works

### Networking

- **Inside the container**: Services are accessible by name (`redis`, `mysql`, `localstack`) on standard ports
- **From your host machine**: Services are accessible via `localhost` on the same ports (or custom ports if configured)

### Persistence

Your home directory (`/home/vscode`) is stored in a Docker volume that persists across container rebuilds. This means:
- ✅ Shell history is saved
- ✅ Authentication credentials persist
- ✅ Custom configurations are preserved

If you need to start fresh, you can remove the volume (see Persistence section below).

## Persistence

Your home directory (`/home/vscode`) is stored in a Docker volume that persists across container rebuilds. This includes:

- Shell history (500,000 lines)
- GitHub CLI authentication
- Composer and npm configurations
- All other home directory files

**Note**: SSH keys are not stored. SSH agent forwarding uses your host's keys automatically.

### Starting Fresh

If you need to reset everything (e.g., after configuration changes):

**Windows (PowerShell):**
```powershell
docker volume rm devcontainer_home-data
```

**macOS/Linux:**
```bash
docker volume rm devcontainer_home-data
```

Then rebuild the container. All your data will be reset.


## Development Tools

The container includes:

- **PHP 8.3** with common extensions (bcmath, gd, intl, mbstring, mysqli, opcache, pdo, redis, xdebug, and more)
- **Composer** for PHP dependency management
- **Node.js** (via fnm) for JavaScript/TypeScript projects
- **Git** and **GitHub CLI** for version control
- **Docker** and **kubectl** for container orchestration
- **Vault CLI** for secrets management
- **fzf** for fuzzy finding in the terminal

## Additional Resources

- [VS Code Dev Containers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [Docker Documentation](https://docs.docker.com/)
- [Cursor Documentation](https://cursor.sh/docs)

## Getting Help

If you encounter issues:

1. Check the Troubleshooting section above
2. Verify Docker Desktop is running and up to date
3. Try rebuilding the container (F1 → "Dev Containers: Rebuild Container")
4. Check the container logs in VS Code/Cursor output panel



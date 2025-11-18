# Devcontainer "Sandbox"

A standalone devcontainer repository providing shared services, tooling, and configuration for a multi-repo development environment. The goal is to ensure a consistent, local development environment that improves developer onboarding, experience, and velocity.

## What is a Devcontainer?

A devcontainer is a Docker-based development environment that runs inside VS Code or Cursor. It provides a consistent, isolated environment with all the tools and services you need, regardless of your operating system (Windows, macOS, or Linux).

## Features

- **Shared Services**: Redis (Valkey), MySQL 8, LocalStack (S3, SQS, SNS)
- **Development Tools**: PHP 8.3 CLI with full extension suite, Composer, Xdebug, Git, GitHub CLI, Docker, kubectl, Vault CLI, Node.js (via fnm), Redis CLI, MySQL CLI
- **Multi-Repo Management**: Clone and link multiple repositories easily
- **Persistent Storage**: Shell history and authentication configs persist across rebuilds
- **Multi-Platform**: Works on Windows (WSL2), macOS, and Linux

## Windows Users: WSL2 Required

> [!IMPORTANT]  
> This devcontainer requires WSL2 (Windows Subsystem for Linux 2) on Windows.

If you haven't set up WSL2 yet, follow the [official WSL2 installation guide](https://learn.microsoft.com/en-us/windows/wsl/install) before proceeding.

> [!CAUTION]
> We do not have a license for Docker Desktop. Windows users should install Docker Engine inside WSL2 instead. See Docker installation instructions below.

## Prerequisites

- **VS Code** or **Cursor** installed
- **Docker Engine** installed and running:
  - **Windows (WSL2)**: Install Docker Engine directly in your WSL2 distribution following the [Docker Engine installation guide for Ubuntu](https://docs.docker.com/engine/install/ubuntu/) (or your WSL2 distribution's equivalent)
  - **macOS**: Install Docker Engine using [Colima](https://github.com/abiosoft/colima) (recommended) or [OrbStack](https://orbstack.dev/). Alternatively, use Homebrew: `brew install colima` then `colima start`
  - **Linux**: Install [Docker Engine](https://docs.docker.com/engine/install/) for your distribution
- **Dev Containers extension** (usually installed automatically when opening a devcontainer)
- **GitHub CLI** installed and authenticated on your host machine:
  - **macOS**: `brew install gh` ([Homebrew](https://brew.sh/)) or follow [GitHub CLI installation instructions](https://github.com/cli/cli/blob/trunk/docs/install_macos.md)
  - **Linux**: `brew install gh` ([Homebrew](https://brew.sh/)) or follow [GitHub CLI installation instructions](https://github.com/cli/cli/blob/trunk/docs/install_linux.md)
  - **Windows**: Follow [GitHub CLI installation instructions](https://github.com/cli/cli/blob/trunk/docs/install_windows.md)
  
  After installation, authenticate:
  ```bash
  # No need to create your own PAT/token! Github will create one for you as part of this process
  gh auth login
  # This will change your git to use the new token and HTTPS under the hood. Should require no
  # additional changes to your repos or remotes
  gh auth setup-git
  ```

### Other IDEs such as PhpStorm

Instructions TBD using `devcontainer` CLI tools

## Quick Start

1. **Clone this repository** to your local machine:
   ```bash
   git clone https://github.com/encodium/devcontainer.git
   cd devcontainer
   ```

2. **Copy the environment file** (if `.env.example` exists):
   ```bash
   cp .devcontainer/.env.example .devcontainer/.env
   ```
    > [!NOTE]  
    > - If you have multiple clones of the `devcontainer` repo, you must ensure the `COMPOSE_PROJECT_NAME` variable in your `.env` file is unique from the others
    > - You must also ensure all `_EXTERNAL_` port numbers are unique from the others or docker will fail to start all services

3. **Open in VS Code/Cursor**: Open the repository folder in your editor

4. **Reopen in Container**: When prompted, click "Reopen in Container" (or press `F1` and select "Dev Containers: Reopen in Container")

5. **Wait for setup**: The container will build and start services automatically (first time may take a few minutes)

6. **Clone your repositories**: Once inside the container, run:
   ```bash
   dc clone-repos batch,common
   ```

7. **Link common repository** (if needed):
   ```bash
   dc link-common
   ```

8. **Configure additional authentication** (see Authentication section below)

## Available Commands

Once inside the container, you have access to these commands:

### Devcontainer Commands (`dc`)

All devcontainer commands are accessed via the `dc` command:

- **`dc help`** - Show quick reference guide
- **`dc clone-repos [repo1,repo2,...]`** - Clone repositories from the `encodium` organization
  ```bash
  dc clone-repos batch,common,webstore
  # Or use default from .env: dc clone-repos
  ```
- **`dc link-common`** - Link the common repository to all workspace repositories using composer-link
- **`dc test-env`** - Test connectivity to all services and CLI authentication status
- **`dc packagist-auth`** - Check and configure Private Packagist authentication
- **`dc npmrc`** - Check and configure npm authentication using GitHub CLI token
- **`dc github-cli`** - Check GitHub CLI authentication status

### Service Access Aliases

- **`redis`** - Connect to Redis CLI
- **`mysql`** - Connect to MySQL CLI
- **`awslocal`** - AWS CLI with LocalStack endpoint pre-configured
- **`k`** - Shortcut for `kubectl`

## Configuration

### Environment Variables

You can customize the devcontainer by creating a `.env` file in the `.devcontainer` directory. If `.env.example` exists, copy it to get started:

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
dc clone-repos new-repo,another-repo
```

Or add them to `REPOS_TO_CLONE` in `.env` and run `dc clone-repos` without arguments.

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

**Testing Services**: Run `dc test-env` to verify all services and CLI authentication are accessible.

## Authentication

Authentication credentials persist across container rebuilds. Configure them once and they'll be saved.

### GitHub CLI

Required for cloning repositories. Authentication is automatically available via mount from your host machine.

**Manual Authentication (if needed):**

If you need to update your authentication, you can run this on your host machine or inside the container:

```bash
gh auth login
```

Follow the prompts to authenticate. Your credentials will be saved in the persistent home volume.

### Composer (Private Packagist)

Get setup instructions:

```bash
dc packagist-auth
```

This will show you how to configure authentication. Visit https://packagist.com/orgs/encodium to get your credentials.

### npm (GitHub Packages)

Automatically configured using your GitHub CLI token:

```bash
dc npmrc
```

This uses your existing GitHub CLI authentication, so make sure `gh auth login` is done first.

### SSH

SSH agent forwarding is automatically configured. Your host's SSH keys are available in the container without copying them. Just use `git` commands normally.

## Composer Link

The `common` repository can be linked to all other repositories for local development. This allows you to test changes to common across multiple repos.

**Link common to all repositories:**
```bash
dc link-common
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

### Devcontainer Fails to Start

#### Docker Daemon Not Running

**Windows (WSL2)**: Ensure Docker daemon is running:
```bash
sudo systemctl status docker
# If not running, start it:
sudo service docker start
```

**macOS**: Ensure Docker daemon is running:
```bash
# Check if Docker is running
docker ps
# If not, start Docker from Applications or via command line
```

**Linux**: Ensure Docker daemon is running:
```bash
sudo systemctl status docker
# If not running, start it:
sudo systemctl start docker
```

#### Port Conflicts

If the initialize script reports port conflicts or you get port binding errors, update the conflicting ports in `.devcontainer/.env`:

```bash
REDIS_EXTERNAL_PORT=6380
MYSQL_EXTERNAL_PORT=3307
LOCALSTACK_EXTERNAL_PORT=4567
```

**Suggested pattern**: Increment the hundreds place of each port number (e.g., 6379 → 6479).

Then rebuild the container.

#### Container is Slow

First-time build downloads images and installs tools. Subsequent starts are faster. If the container feels slow:
- Ensure you have enough disk space
- Check Docker resource limits (if configured)
- Try restarting the Docker daemon

#### Environment File Issues

If you see errors about missing `.env` file or invalid configuration:
- Ensure `.devcontainer/.env` exists (copy from `.devcontainer/.env.example` if needed)
- Verify all required variables are set
- Check that `COMPOSE_PROJECT_NAME` is unique if you have multiple devcontainer instances

### Other Issues (Inside Working Devcontainer)

#### Services Not Accessible

Test service connectivity and CLI authentication:
```bash
dc test-env
```

> [!TIP]
> If services show ❌, they may still be starting. Wait a minute and try again.

#### Repository Cloning Fails

Ensure GitHub CLI is authenticated:
```bash
gh auth status
# If not authenticated:
gh auth login
```

#### Authentication Issues

**GitHub CLI**: If `gh` commands fail, re-authenticate:
```bash
gh auth login
```

**Composer (Private Packagist)**: Get setup instructions:
```bash
dc packagist-auth
```

**npm (GitHub Packages)**: Configure using GitHub token:
```bash
dc npmrc
```

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
2. Check the terminal logs. Docker and devcontainer build logs output here (<kbd>CTRL/⌘</kbd>+<kbd>`</kbd>)
3. Try rebuilding the container (<kbd>F1</kbd> or <kbd>CTRL/⌘</kbd>+<kbd>SHIFT</kbd>+<kbd>P</kbd> → "Dev Containers: Rebuild Container")
4. Check the other logs in VS Code/Cursor output panel



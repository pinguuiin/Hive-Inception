*This project has been created as part of the 42 curriculum by piyu.*

# Hive-Inception

## Description

Inception is a system-administration project whose goal is to build a small, multi-service web infrastructure **from scratch using Docker**, running entirely inside a virtual machine. Everything is orchestrated with Docker Compose, and every image is built from our own Dockerfiles.

The stack hosts a self-signed-TLS WordPress site backed by its own database:

| Service   | Container             | Role                                                              |
|-----------|-----------------------|------------------------------------------------------------------|
| NGINX     | `inception_nginx`     | The **only** entry point — serves the site over HTTPS (443, TLS 1.3). |
| WordPress | `inception_wordpress` | The WordPress application, run by PHP-FPM.                        |
| MariaDB   | `inception_mariadb`   | The database storing all WordPress content.                      |

Request flow: **browser → NGINX (443, TLS) → WordPress (PHP-FPM, 9000) → MariaDB (3306)**.
Only NGINX is published to the host; WordPress and MariaDB stay on a private Docker network. Website files and the database are bind mounts on the host under `/home/piyu/data`.

```
                 host :443
                     │
            ┌────────▼────────┐
            │ inception_nginx │  NGINX + OpenSSL, TLS 1.3 only
            └────────┬────────┘
            fastcgi  │ :9000
            ┌────────▼──────────┐
            │inception_wordpress│  WordPress + PHP-FPM 8.4 + WP-CLI
            └────────┬──────────┘
             mysql   │ :3306
            ┌────────▼────────┐
            │inception_mariadb│  MariaDB
            └─────────────────┘

network: inception_net (bridge)
volumes: /home/piyu/data/wordpress  (nginx + wordpress → /var/www/html)
         /home/piyu/data/mariadb    (mariadb → /var/lib/mysql)
```

## Features

- Three isolated services, one container each, built from `alpine:3.23`.
- **HTTPS-only** entry point on port 443 (TLS 1.3), self-signed certificate.
- WordPress auto-installed and configured on first boot via WP-CLI, with two users (an administrator and a regular `author`).
- Passwords managed with **Docker secrets**; non-sensitive config via a `.env` file.
- Data persistence through host bind mounts; idempotent setup scripts that never wipe existing data.
- Automatic restart of containers on crash (`restart: unless-stopped`).
- A `Makefile` wrapping all Docker Compose operations.

## Project description — Docker, sources, and design choices

### Use of Docker and the sources in this project

Each service lives in `srcs/requirements/<service>/` and is built from its own `Dockerfile`; `srcs/docker-compose.yml` ties them together with one bridge network, host bind mounts, and Docker secrets. Configuration and entrypoint logic are kept next to each Dockerfile.

- **nginx** — `Dockerfile` installs NGINX + OpenSSL and generates a self-signed certificate; `conf/nginx.conf` serves `/var/www/html` over TLS 1.3 and passes `*.php` to `wordpress:9000` via FastCGI.
- **wordpress** — `Dockerfile` installs PHP-FPM 8.4 (+ required extensions) and WP-CLI; `tools/setup.sh` downloads WordPress, generates `wp-config.php`, waits for the database, installs WordPress and creates the second user, then `exec`s `php-fpm84 -F`. `conf/www.conf` configures the PHP-FPM pool.
- **mariadb** — `Dockerfile` installs MariaDB; `tools/setup.sh` initializes the data directory, creates the database/user/root password on first boot, then `exec`s `mysqld`. `conf/my.cnf` sets the bind address, port, and charset.

Key design choices:

- **No `latest` tags** — the base image is pinned (`alpine:3.23`, the penultimate stable Alpine at build time).
- **PID 1 done right** — all services run in the **foreground**. So the container's status and lifespan is syncing with the main service at PID 1 (via `exec` and `daemon off`), with no infinite loop hacks (e.g. `tail -f`, `sleep infinity`, or `while true`).
- **Single entry point** — only NGINX publishes a port (443); everything else is internal to `inception_net`.
- **Secrets over plaintext** — no password appears in any Dockerfile or in the Git repository; secrets are read from files mounted at `/run/secrets`.
- **Idempotent setup** — scripts detect existing state and skip re-initialization, so restarts preserve data.

### Virtual Machines vs Docker

A **virtual machine** virtualizes an entire machine: it runs a full guest OS (with its own kernel) on top of a hypervisor, which is heavy in RAM, disk, and boot time.
**Docker** uses OS-level containerization: containers share the host kernel and isolate only processes, filesystem, and network. Containers are therefore lighter and start in seconds.

### Secrets vs Environment Variables

**Environment variables** (via `.env`) are convenient for non-sensitive configuration (database name, site title, usernames, domain), but they are visible in the image metadata, `docker inspect`, and process listings. Therefore they are unsafe for passwords.
**Docker secrets** store sensitive values in files that are mounted read-only into the container at `/run/secrets/<name>` and are not built into the image or exposed in its environment. This project keeps all passwords in secrets and everything else in `.env`.

### Docker Network vs Host Network

With the **host network** the container binds directly to the host machine's network interfaces — no isolation, no port mapping, and port conflicts that will cause crash if running two containers using the same port on the host network.
A **Docker (bridge) network** gives containers a private, isolated network where each of them is assigned with an internal IP and reaches each other by service name, while only explicitly published ports are exposed to the host.

### Docker Volumes vs Bind Mounts

**Named volumes** are the storage mechanism completely managed by Docker, where Docker creates a dedicated directory inside its own internal storage area. It can be destroyed using `docker volume rm` or `docker compose down -v`.
**Bind mounts** map a specific host path into the container. Docker treats this host folder as user-owned property outside of its internal storage management. It is free from docker's cleanup commands and could avoid accidental loss of critical source code or configuration files. Bind mounts can only be cleaned up manually.

## Instructions

### Prerequisites

- A Linux host (the project targets an Alpine VM — see *VM setup* below).
- **Docker Engine** and the **Docker Compose v2 plugin** (`docker compose`).
- The domain resolving locally — add to `/etc/hosts`:

  ```
  127.0.0.1   piyu.42.fr www.piyu.42.fr
  ```

### Configuration

1. Copy the environment file and edit it:

   ```sh
   cp srcs/.env.example srcs/.env
   ```

2. Create the secret files (one secret per file, **no trailing newline**):

   ```sh
   mkdir -p secrets
   printf '%s' 'db-user-pass'   > secrets/mysql_password
   printf '%s' 'db-root-pass'   > secrets/mysql_root_password
   printf '%s' 'wp-admin-pass'  > secrets/wp_admin_password
   printf '%s' 'wp-user-pass'   > secrets/wp_user_password
   chmod 600 secrets/*
   ```

   `srcs/.env` and `secrets/` are git-ignored and never committed.

### Build and run

All commands run from the repository root via the `Makefile`:

```sh
make            # create host data dirs and start the stack (builds on first run)
make build      # force a full image rebuild, then start
make down       # stop and remove containers (data preserved)
make clean      # remove containers + volumes
make fclean     # clean + remove dangling containers/images/networks and /home/piyu/data
make re         # fclean, then a fresh build
make logs       # follow logs (make logs SERVICE=nginx for one service)
make ps         # list containers
```

Then open **https://piyu.42.fr** (admin panel at **https://piyu.42.fr/wp-admin**). The self-signed certificate triggers a browser warning the first time — proceed past it.

For detailed usage and troubleshooting, see [USER_DOC.md](USER_DOC.md) and [DEV_DOC.md](DEV_DOC.md).

## VM setup

The project is meant to run inside a virtual machine.

### Configuration

- VM: Alpine Linux x86_64
- RAM: 4GB
- CPUs: 2
- Disk: 30GB

### VM Setup (Alpine Linux 3.24)

- Network: `eth0` - first wired network interface (Ethernet)
- `DHCP` (Dynamic Host Configuration Protocol): on - automatically assigning IP addresses and other communication parameters to devices connected to the network using a client–server architecture
- NTP (Network Time Protocol) client: `chrony` - lighter, faster and more accurate than the traditional ntpd
- APK mirror: default or a geographically close one
- SSH server: `openssh` - standard SSH server
- Disk: `sda` (the main virtual hard disk) and possibly `sdb` if there are extra disks added
- Disk setup: `sys` - full installation of Alpine

## Repository layout

```
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/                        # local only, git-ignored
│   ├── mysql_password
│   ├── mysql_root_password
│   ├── wp_admin_password
│   └── wp_user_password
└── srcs/
    ├── .env                        # local only, git-ignored
    ├── .env.example                # committed template
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/my.cnf
        │   └── tools/setup.sh
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/nginx.conf
        └── wordpress/
            ├── Dockerfile
            ├── conf/www.conf
            └── tools/setup.sh
```

## Resources

Documentation and references used while building the project:

- Docker documentation — <https://docs.docker.com/>
- Docker Compose specification — <https://docs.docker.com/compose/>
- Docker secrets — <https://docs.docker.com/engine/swarm/secrets/>
- Dockerfile best practices — <https://docs.docker.com/develop/develop-images/dockerfile_best-practices/>
- NGINX documentation — <https://nginx.org/en/docs/>
- PHP-FPM documentation — <https://www.php.net/manual/en/install.fpm.php>
- MariaDB Knowledge Base — <https://mariadb.com/kb/en/>
- WordPress WP-CLI handbook — <https://developer.wordpress.org/cli/commands/>
- Alpine Linux wiki — <https://wiki.alpinelinux.org/>

### Use of AI

AI assistance was used as a support tool, with all output reviewed and tested by the author before inclusion:

- **Documentation** — drafting and structuring `README.md`, `USER_DOC.md`, and `DEV_DOC.md` from the project's source code and the subject requirements.
- **Explanations** — clarifying the concepts of Docker, NGINX, PHP-FPM and discussing the design choices above.
- **Review** — sanity-checking configuration files and setup scripts against the subject's constraints.

No AI-generated content was used without being understood and verified.

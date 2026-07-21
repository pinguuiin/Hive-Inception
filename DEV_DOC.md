# DEV_DOC.md — Developer Documentation

This document describes how to set up the Inception project from scratch, build and launch it, manage its containers and volumes, and where its data lives.

---

## 1. Architecture overview

Three services, each built from a **custom Dockerfile** (no pre-built application images are pulled — only the `alpine:3.23` base), orchestrated by a single `docker-compose.yml` and connected by one bridge network.

```
                 host :443
                     │
             ┌───────▼────────┐
             │ inception_nginx│  NGINX + OpenSSL, TLS 1.3 only
             └───────┬────────┘
             FastCGI │ :9000
           ┌─────────▼──────────┐
           │inception_wordpress │  WordPress + PHP-FPM 8.3 + WP-CLI
           └─────────┬──────────┘
               MySQL │ :3306
            ┌────────▼────────┐
            │inception_mariadb│  MariaDB
            └─────────────────┘

network:
  inception_net (bridge)
volumes (bind mounts on host):
  /home/piyu/data/wordpress  ← shared by nginx + wordpress (/var/www/html)
  /home/piyu/data/mariadb    ← mariadb (/var/lib/mysql)
```

## 2. Setting up the environment from scratch

### 2.1 Prerequisites

- Linux host (the project targets an Alpine VM; see `README.md`).
- SSH and GUI to enable cross-machine share and web browsing on the VM (see *Section 2.2* and *2.3*).
- **Docker Engine** and the **Docker Compose v2 plugin** (`docker compose`).
- `sudo`/root to create the host data directories.
- The domain resolving locally — add to `/etc/hosts`:

  ```
  127.0.0.1   piyu.42.fr www.piyu.42.fr
  ```

### 2.2 SSH installation and setup

#### 2.2.1 Install and enable SSH

``` sh
apk add openssh
rc-update add sshd
rc-service sshd start
```

#### 2.2.2 VirtualBox networking and SSH connection

-   Configure NAT port forwarding:
    -   Host port: `4241`
    -   Guest port: `22`
-   Connect from host:

``` sh
ssh -p 4241 piyu@localhost
```

Remove the old host key if you receive a host identification warning, and reconnect:

``` sh
ssh-keygen -f ~/.ssh/known_hosts -R "[localhost]:4241"
ssh -p 4241 piyu@localhost
```

#### 2.2.3 (Optional) Install sudo

``` sh
apk add sudo
adduser piyu wheel
visudo
# uncomment:
# %wheel ALL=(ALL:ALL) ALL
```

#### 2.2.4 (Optional) Add user to `docker` group

If you are logged in as a user that doesn't belong to the `docker` group, you have no permission to run docker. To fix it, add your user to the group:

```sh
sudo addgroup piyu docker
```

Then **log out of the SSH session and log back** in so the new group membership takes effect.

### 2.3 GUI installation and setup

#### 2.3.1 Install XFCE

``` sh
apk add xorg-server xinit xfce4 xfce4-terminal     libinput xf86-input-libinput
```

#### 2.3.2  Fix missing keyboard/mouse in the XFCE desktop - Enable eudev and configure VirtualBox

``` sh
apk add eudev eudev-openrc
rc-update add udev sysinit
rc-update add udev-trigger sysinit
rc-update add udev-settle sysinit
reboot
```

Verify that mouse and keyboard are listed:

``` sh
libinput list-devices
xinput list   # run it from your VM
```

Power off the VM first and go to VirtualBox Settings:

System → Motherboard - Pointing Device: **USB Tablet**

Display - Graphics Controller: **VBoxSVGA** - Video Memory: 128 MB - 3D Acceleration: Disabled (recommended)

#### 2.3.3 Start XFCE manually

``` sh
echo "exec startxfce4" > ~/.xinitrc
startx    # run from your VM
```

Run `startx` from the VM console, **not over SSH**.

#### 2.3.4 Troubleshooting

-   `startx: not found` → `apk add xinit`
-   `Only console users are allowed to run the X server` → run `startx` from the VM console.
-   `libinput list-devices` empty → install/enable `eudev`.
-   Mouse invisible/unusable → switch VirtualBox Pointing Device to **USB Tablet**.

### 2.4 Host data directories

The volumes are **bind mounts** under `/home/piyu/data`. You do **not** need to create them by hand: Both `make build` and `make up` creates the paths `/home/piyu/data/mariadb` and `/home/piyu/data/wordpress` if they are missing. To create them manually (e.g. when running Compose directly):

```sh
mkdir -p /home/piyu/data/wordpress /home/piyu/data/mariadb
```

> If you are using a different login name, update `DATA_PATH` in the `Makefile`, the paths in `srcs/docker-compose.yml` (the `volumes:` entries), and the `server_name`/`SSL certificate CN` in the NGINX config accordingly.

### 2.5 Environment file

Copy the template to `.env`:
```sh
cp srcs/.env.example srcs/.env
```

Then edit `srcs/.env`:

| Variable         | Notes                                                             |
|------------------|-------------------------------------------------------------------|
| `MYSQL_DATABASE` | DB name created by the MariaDB setup script.                       |
| `MYSQL_USER`     | Non-root DB user WordPress uses.                                   |
| `MYSQL_HOST`     | Must be `mariadb` (the compose service name).                      |
| `DOMAIN_NAME`    | e.g. `piyu.42.fr`. Used as the WordPress site URL.                 |
| `WP_TITLE`       | Site title.                                                        |
| `WP_ADMIN_USER`  | Admin username — **must not contain `admin`/`administrator`** (subject rule). |
| `WP_ADMIN_EMAIL` | Admin email.                                                       |
| `WP_USER`        | Second user (created with role `author`).                          |
| `WP_USER_EMAIL`  | Second user email.                                                 |

Passwords live in a separate directory `secrets/` (local, gitignored).

### 2.6 Secrets

`docker-compose.yml` declares four Docker secrets, each backed by a file in `../secrets/` (repo root), mounted into containers at `/run/secrets/<name>`:

| Secret                | File                          | Consumed by            |
|-----------------------|-------------------------------|------------------------|
| `mysql_password`      | `secrets/mysql_password`      | mariadb, wordpress     |
| `mysql_root_password` | `secrets/mysql_root_password` | mariadb                |
| `wp_admin_password`   | `secrets/wp_admin_password`   | wordpress              |
| `wp_user_password`    | `secrets/wp_user_password`    | wordpress              |

Create them with **no trailing newline** (the setup scripts treat the whole file content as the password):

```sh
mkdir -p secrets
printf '%s' 'db-user-pass'   > secrets/mysql_password
printf '%s' 'db-root-pass'   > secrets/mysql_root_password
printf '%s' 'wp-admin-pass'  > secrets/wp_admin_password
printf '%s' 'wp-user-pass'   > secrets/wp_user_password
chmod 600 secrets/*
```

The containers receive the secret **paths** via `*_FILE` environment variables (e.g. `MYSQL_PASSWORD_FILE=/run/secrets/mysql_password`); the `read_secret()` helper in each `tools/setup.sh` validates the file (set, exists, readable, non-empty) and exports the value into the process environment.

---

## 3. Building and launching

Start an SSH session in your host machine or run the command directly in the VM.

The `Makefile` (repo root) is the entry point; it wraps Docker Compose. The targets below are what it actually defines. Equivalent raw commands are shown so you can run them directly.

| Action                              | Make target       | Docker Compose equivalent                                        |
|-------------------------------------|-------------------|------------------------------------------------------------------|
| Create data dirs + start detached   | `make` / `make up`| `docker compose -f srcs/docker-compose.yml up -d`                |
| Create data dirs + force rebuild    | `make build`      | `docker compose -f srcs/docker-compose.yml up -d --build`         |
| Stop + remove containers            | `make down`       | `docker compose -f srcs/docker-compose.yml down`                 |
| Pause containers (keep them)        | `make stop`       | `docker compose -f srcs/docker-compose.yml stop`                 |
| Resume stopped containers           | `make start`      | `docker compose -f srcs/docker-compose.yml start`               |
| Restart the stack                   | `make restart`    | `... down` then `... up -d`                                       |
| Follow logs (all / one service)     | `make logs SERVICE=x` | `docker compose -f srcs/docker-compose.yml logs -f [x]`     |
| List container names + states       | `make ps`         | `docker compose -f srcs/docker-compose.yml ps`                  |
| Remove containers + volumes         | `make clean`      | `docker compose -f srcs/docker-compose.yml down -v`             |
| Full reset (+ images + host data)   | `make fclean`     | `... down -v`, `docker system prune -af`, `docker volume prune -f`, `sudo rm -rf /home/piyu/data` |
| Rebuild from clean                  | `make re`         | `make fclean && make build`                                      |

> `make` (aka `make up`) runs `docker compose up -d`, which builds the images automatically on the first run and runs all the containers.

### What happens on first launch

1. **mariadb** (`tools/setup.sh`):
- reads secrets
- unsets the inherited `MYSQL_HOST` so local admin commands use the Unix socket
- initializes the data directory if empty (`mariadb-install-db`)
- starts a temporary `--skip-networking` server
- creates the database + user + root password
- `exec`s the real `mysqld` as PID 1 (in the foreground).
2. **wordpress** (`tools/setup.sh`):
- reads secrets
- downloads WordPress core via WP-CLI
- generates `wp-config.php` (`--skip-check`, since MariaDB may not be up yet)
- waits for the DB to be ready with `wp db check`
- installs WordPress
- creates the second user (role `author`)
- `exec`s `php-fpm84 -F` as PID 1.
3. **nginx**:
- serves `/var/www/html` over TLS 1.3 on 443 and forwards `*.php` to `wordpress:9000` via FastCGI
- runs `nginx -g "daemon off;"` in the foreground.

All three use `exec ...` / `daemon off` so the service stays as **PID 1**.

---

## 4. Managing containers and volumes

Run from the repo root (add `-f srcs/docker-compose.yml` to each `docker compose` command, as shown).

### Status and logs

```sh
make ps                                               # container states, ports, etc
make logs                                             # all logs, follow
make logs SERVICE=wordpress                           # one service
```

### Lifecycle of a single service

```sh
docker compose -f srcs/docker-compose.yml up -d --build mariadb   # build one
docker compose -f srcs/docker-compose.yml stop mariadb
docker compose -f srcs/docker-compose.yml restart mariadb
```

### Shell / inspection inside a container

```sh
docker exec -it inception_wordpress sh
docker exec -it inception_mariadb mariadb -u root -p     # DB shell. Enter the root password
docker exec -it inception_wordpress wp --allow-root --path=/var/www/html option get siteurl     # WordPress health check
```

### Networks and volumes (Docker objects)

```sh
docker network ls | grep inception          # the bridge network
docker volume ls                            # (this project uses host bind mounts, not named volumes)
docker image ls | grep -E 'nginx|wordpress|mariadb'
```

### Cleanup

```sh
docker compose -f srcs/docker-compose.yml down          # keep data
docker compose -f srcs/docker-compose.yml down -v       # drop compose-managed volumes
docker system prune -af                                 # remove ALL the stopped containers/unused networks/dangling images/build cache
```

---

## 5. Where data is stored and how it persists

Persistence is achieved with **bind mounts** to the host, declared in `srcs/docker-compose.yml`:

| Host path                     | Mounted in container       | Contents                                  |
|-------------------------------|----------------------------|-------------------------------------------|
| `/home/piyu/data/wordpress`   | `nginx` & `wordpress` → `/var/www/html` | WordPress core, themes, plugins, uploads, `wp-config.php` |
| `/home/piyu/data/mariadb`     | `mariadb` → `/var/lib/mysql`            | MariaDB data files (all site content)     |

Because these are host directories, the data **survives** `docker compose down`, rebuilds, and host reboots. The setup scripts are **idempotent** — they detect existing state (`/var/lib/mysql/mysql` for the DB, `wp-load.php` / `wp core is-installed` for WordPress) and skip re-initialization, so restarting never wipes existing content.

To fully reset the project — removing containers, volumes, images, **and** the host data — use:

```sh
make fclean
```

which runs `down -v`, `docker system prune -af`, `docker volume prune -f`, and
`sudo rm -rf /home/piyu/data`.

---

## 6. Configuration reference

| File                                         | Purpose                                                            |
|----------------------------------------------|-------------------------------------------------------------------|
| `srcs/docker-compose.yml`                    | Service, network, volume, and secret definitions.                 |
| `srcs/requirements/nginx/conf/nginx.conf`    | TLS 1.3 server on 443, static root + FastCGI pass to `wordpress:9000`. |
| `srcs/requirements/nginx/Dockerfile`         | Installs nginx + openssl, generates the self-signed cert.          |
| `srcs/requirements/wordpress/conf/www.conf`  | PHP-FPM pool: listens `0.0.0.0:9000`, `pm=dynamic`, `clear_env=no`. |
| `srcs/requirements/wordpress/tools/setup.sh` | WordPress download/config/install + second user creation.         |
| `srcs/requirements/mariadb/conf/my.cnf`      | `bind-address=0.0.0.0`, port 3306, `utf8mb4`, `skip-name-resolve`. |
| `srcs/requirements/mariadb/tools/setup.sh`   | DB init, database/user/root-password creation.                    |

### Design notes

- **No `latest` tags** — every base image is pinned (`alpine:3.23`).
- **TLS** — NGINX terminates TLS with `ssl_protocols TLSv1.3;` and is the only published port (443).
- **Secrets vs env vars** — passwords go through Docker secrets (files under `/run/secrets`); only non-sensitive config is in `.env`.
- **PID 1** — each container's main process is the service itself via `exec` and `daemon off`.
- **Restart policy** — all services use `restart: unless-stopped` so that they would restart on crashes, error exits, but can still be manually stopped.

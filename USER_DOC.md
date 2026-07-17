# USER_DOC.md — User Documentation

This manual explains to the end users or administrators how to use the stack: what services are provides, how to start and stop it, how to reach the website and admin panel, where the credentials live, and how to confirm everything is running.

---

## 1. What this stack provides

Inception runs a small self-hosted WordPress website. It is made of three services, each in its own Docker container, wired together on a private Docker network:

| Service   | Container            | Role                                                                 |
|-----------|----------------------|---------------------------------------------------------------------|
| NGINX     | `inception_nginx`    | The **only** entry point. Serves the site over **HTTPS on port 443** (TLS 1.3). |
| WordPress | `inception_wordpress`| The WordPress application, run by **PHP-FPM**. Generates the pages.  |
| MariaDB   | `inception_mariadb`  | The database that stores all WordPress content (posts, users, settings). |

Traffic flow: **browser → NGINX (443, TLS) → WordPress (PHP-FPM, 9000) → MariaDB (3306)**.
Only NGINX is reachable from outside; WordPress and MariaDB stay on the internal network.

Website data is kept on the host so it survives container restarts and rebuilds:

- Website files: `/home/piyu/data/wordpress`
- Database files: `/home/piyu/data/mariadb`

---

## 2. Before you start

1. **Docker** and the **Docker Compose** plugin must be installed and running.
2. The domain name must resolve to your machine. Run this line to add the mapping to `/etc/hosts`:

   ```
   echo "127.0.0.1 piyu.42.fr www.piyu.42.fr" | sudo tee -a /etc/hosts
   ```

3. The secrets and environment files must exist (see section 5). Without them the containers will refuse to start.

---

## 3. Starting and stopping the project

All commands are run from the repository root, using the `Makefile`.

### Start (in the background)

```sh
make            # same as `make up`: creates the host data dirs and starts the stack
make build      # force a full image rebuild, then start
```

`make` (or `make up`) also creates the `/home/piyu/data` directories automatically if they don't exist. The first start takes a few minutes: it builds the images, initializes the database, and installs WordPress. Later starts are fast.

Other lifecycle targets:

```sh
make stop       # pause containers without removing them
make start      # resume previously stopped containers
make restart    # down + up
```

### Stop (keep data)

```sh
make down       # stop and remove the containers
```

The wordpress files and database **remain** on the binded local directory `/home/piyu/data`, so the next start restores everything.

### Stop and wipe everything (destroys data)

```sh
make clean      # remove containers + compose volumes (host data kept)
make fclean     # clean + remove images/build cache AND delete /home/piyu/data
make re         # fclean, then a fresh rebuild
```

Use `make fclean` only for a clean reinstall — it permanently deletes the site and database (it runs `sudo rm -rf /home/piyu/data`).

> The containers are configured with `restart: unless-stopped`, so they come back automatically after a crash or a host reboot (until you explicitly stop them).

---

## 4. Accessing the website and admin panel

- **Website:** open **https://piyu.42.fr** in your browser.
- **Admin panel:** open **https://piyu.42.fr/wp-admin**

Because the TLS certificate is **self-signed**, your browser will show a security warning the first time. This is expected — choose *Advanced → Proceed* to continue. Note that plain `http://` and any port other than 443 will **not** work; the site is HTTPS-only.

There are two accounts:

- an **administrator** account — full control of the site;
- a **regular user** account (role *author*) — can write posts but not manage the site.

The usernames come from `srcs/.env` (`WP_ADMIN_USER`, `WP_USER`); the passwords come from the secret files (see next section).

---

## 5. Locating and managing credentials

Credentials are split into two places, and **neither is committed to Git** (`.env` and `secrets/` are in `.gitignore`). Only an example of `.env` — `.env.example` is provided for the user to copy and override.

### Non-secret settings — `srcs/.env`

Copy the template and fill it in:

```sh
cp srcs/.env.example srcs/.env
```

Keys used:

| Variable          | Meaning                                   |
|-------------------|-------------------------------------------|
| `MYSQL_DATABASE`  | WordPress database name                    |
| `MYSQL_USER`      | Database user WordPress connects as         |
| `MYSQL_HOST`      | Database host (the service name, `mariadb`) |
| `DOMAIN_NAME`     | Site domain (e.g. `piyu.42.fr`)             |
| `WP_TITLE`        | Site title                                  |
| `WP_ADMIN_USER`   | WordPress administrator username            |
| `WP_ADMIN_EMAIL`  | Administrator email                         |
| `WP_USER`         | Second (regular) WordPress username         |
| `WP_USER_EMAIL`   | Regular user email                          |

### Passwords — `secrets/` directory

Each password is stored in its own file at the repository root, one secret per
file, with **no trailing newline**:

```
secrets/
├── mysql_password        # DB password for MYSQL_USER
├── mysql_root_password   # DB root password
├── wp_admin_password     # WordPress administrator password
└── wp_user_password      # WordPress regular-user password
```

Create them, for example:

```sh
mkdir -p secrets
printf '%s' 'your-db-password'        > secrets/mysql_password
printf '%s' 'your-db-root-password'   > secrets/mysql_root_password
printf '%s' 'your-wp-admin-password'  > secrets/wp_admin_password
printf '%s' 'your-wp-user-password'   > secrets/wp_user_password
chmod 600 secrets/*
```

Docker mounts these into the containers at `/run/secrets/...`; the startup scripts read them from there.
To rotate a password, edit the file and run `make re` to restart the stack.

> **Never** put passwords in the Dockerfiles, in `.env`, or anywhere tracked by Git. Only the files above hold secrets, and they stay local.

---

## 6. Checking that the services are running correctly

**Are all three containers up?**

```sh
make ps    # the full table with container names and states
```

You should see `nginx`, `wordpress`, and `mariadb` all in state `Up`.

**Watch the logs (all services, or one):**

```sh
make logs                       # all services, follow
make logs SERVICE=wordpress     # a single service
```

Healthy startup shows MariaDB becoming ready, then WordPress reporting
"Installing WordPress..." / "Starting PHP-FPM...". NGINX doesn't show any log, because it logs to files inside the container. You can access it by running
```sh
docker exec -it inception_nginx cat /var/log/nginx/access.log 2>&1
```

**Is the site answering over HTTPS?**

```sh
curl -kI https://piyu.42.fr
```

`-k` accepts the self-signed certificate. A `HTTP/1.1 200 OK` (or a redirect to WordPress) means the full chain NGINX → WordPress → MariaDB is working.
`-I` means fetching only the HTTP headers of a website. It is used by developers and admins to quickly inspect server configurations, status codes, and security settings.

**Quick database check:**

```sh
docker exec -it inception_mariadb mariadb -u root -p
```

Enter the root password (from `secrets/mysql_root_password`), then run
`SHOW DATABASES;` — you should see the WordPress database listed.

---

## 7. Troubleshooting

| Symptom                                   | Likely cause / fix                                                            |
|-------------------------------------------|-------------------------------------------------------------------------------|
| Browser can't reach `piyu.42.fr`          | Missing `/etc/hosts` entry (section 2), or the stack isn't started.            |
| Containers exit immediately at first run  | Missing/empty `secrets/` files or `srcs/.env` — the startup scripts abort.     |
| "Error establishing a database connection"| MariaDB still initializing — wait, then re-check `logs`.                        |
| Certificate warning in browser            | Expected: the certificate is self-signed. Proceed past the warning.           |
| Changes to `.env`/secrets not applied     | Restart: `fclean` then `build`.                                          |

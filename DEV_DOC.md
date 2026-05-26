# Developer Documentation

## Environment Setup from Scratch

### Prerequisites

- Linux VM (Ubuntu recommended)
- Docker Engine and Docker Compose v2 installed
- `git`, `make`

### Configuration Files

```
Inception_warp/
├── Makefile                    # Build entry point
├── secrets/                    # Passwords (gitignored)
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── credentials.txt
│   ├── redis_password.txt
│   └── ftp_password.txt
└── srcs/
    ├── .env                    # Non-sensitive config (gitignored)
    ├── docker-compose.yml      # Service definitions
    └── requirements/           # One directory per service
        ├── nginx/
        ├── wordpress/
        ├── mariadb/
        ├── redis/
        ├── adminer/
        ├── ftp/
        └── monitor-api/
```

### First-Time Setup

1. Clone the repo
2. Create `secrets/` directory with password files (see `secrets/*.txt`)
3. Create `srcs/.env` with your domain and usernames
4. Run `make`

## Building and Launching

```bash
make          # mkdir data dirs → docker compose up -d --build
make clean    # docker compose down -v
make fclean   # clean + prune all images + delete data
make re       # fclean + make
```

The Makefile calls `docker compose -f srcs/docker-compose.yml`.

## Container Management Commands

```bash
# View running containers
docker compose -f srcs/docker-compose.yml ps

# View logs for a specific service
docker compose -f srcs/docker-compose.yml logs wordpress

# Restart a single service
docker compose -f srcs/docker-compose.yml restart mariadb

# Open a shell inside a container
docker compose -f srcs/docker-compose.yml exec wordpress bash

# Check WordPress status
docker compose -f srcs/docker-compose.yml exec wordpress wp core version --allow-root
```

## Data Storage and Persistence

Data persists via Docker named volumes with the `local` driver:

- `mariadb_data` → `/home/guruvenu/data/mariadb` (database files)
- `wordpress_data` → `/home/guruvenu/data/wordpress` (WordPress PHP files, uploads)

These are **named volumes** (not bind mounts) as required by the subject. The `driver_opts` with `type: none` and `device` stores data at a predictable host path.

**To wipe all data**: `make fclean` or `sudo rm -rf /home/guruvenu/data/*`

## How Secrets Work

Passwords are stored in `secrets/*.txt` files and mounted into containers at `/run/secrets/<name>`. Each setup script reads them:

```bash
# Example from mariadb setup.sh:
if [ -f /run/secrets/db_password ]; then
    MYSQL_PASSWORD=$(cat /run/secrets/db_password)
fi
```

This keeps passwords out of environment variables, `docker inspect`, and process listings.

## Network Architecture

All containers are on the `inception` bridge network. Container-to-container communication uses Docker DNS (container names resolve to IPs).

```
Internet → :443 → [nginx] → :9000 → [wordpress] → :3306 → [mariadb]
                                   → :6379 → [redis]
                                   → :21   → [ftp]
                  [adminer] → :3306 → [mariadb]
                  [monitor] → checks all services via TCP
```

Only NGINX exposes port 443 to the host. All other inter-service traffic stays on the internal Docker network.

## Adding a New Service

1. Create `srcs/requirements/myservice/Dockerfile` (must use `debian:bullseye` or `alpine:3.19` base)
2. Add the service to `srcs/docker-compose.yml`
3. Connect it to the `inception` network
4. Add it to `SERVICES` and `CONNECTIVITY_MAP` in `monitor-api/app.py` for monitoring

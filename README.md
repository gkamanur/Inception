*This project has been created as part of the 42 curriculum by gkamanur.*

# Inception

## Description

Inception is a system administration project that sets up a complete web infrastructure using Docker containers. The goal is to learn Docker, Docker Compose, containerization, networking, and security best practices by building everything from scratch — no pre-built images allowed (except base Alpine/Debian).

The infrastructure includes:

- **NGINX** — Reverse proxy with TLS (HTTPS only on port 443)
- **WordPress + PHP-FPM** — Content management system
- **MariaDB** — Relational database for WordPress
- **Redis** — Object cache for WordPress performance
- **FTP (vsftpd)** — File transfer server pointing to WordPress files
- **Adminer** — Web-based database management tool
- **Monitor** — Custom health/connectivity monitoring dashboard

All services run in isolated containers on a single Docker bridge network. Data persists via Docker named volumes stored at `/home/gkamanur/data/`.

## Instructions

### Prerequisites

- Docker & Docker Compose installed
- Port 443 available on host
- Add `127.0.0.1 gkamanur.42.fr` to `/etc/hosts`

### Build & Run

```bash
make          # Creates data dirs, builds images, starts all containers
make clean    # Stops containers and removes volumes
make fclean   # Full cleanup: prune images + delete persistent data
make re       # Full rebuild from scratch
```

### Access

- **Dashboard**: `https://gkamanur.42.fr` (self-signed cert, accept in browser)
- **WordPress**: `https://gkamanur.42.fr/wordpress/`
- **WordPress Admin**: `https://gkamanur.42.fr/wordpress/wp-admin/`
- **Monitor API**: `https://gkamanur.42.fr/api/diagnostic`

## Resources

### References

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose File Reference](https://docs.docker.com/compose/compose-file/)
- [NGINX Configuration Guide](https://nginx.org/en/docs/)
- [WordPress CLI Handbook](https://developer.wordpress.org/cli/commands/)
- [MariaDB Knowledge Base](https://mariadb.com/kb/)
- [Docker Secrets Documentation](https://docs.docker.com/compose/how-tos/use-secrets/)

### AI Usage

AI was used for:
- Generating boilerplate Dockerfile structures
- Debugging container networking issues
- Generating the monitoring API health-check logic
- All AI-generated code was reviewed, tested, and understood before inclusion

## Project Comparisons

### Virtual Machines vs Docker

- **VM**: Runs a full OS with its own kernel; heavy resource usage (GB of RAM), slow boot. Strong isolation.
- **Docker**: Shares the host kernel; lightweight (MB of RAM), starts in seconds. Process-level isolation via namespaces/cgroups.
- **When to use**: VMs for full OS isolation (different kernels); Docker for microservices and reproducible deployments.

### Secrets vs Environment Variables

- **Environment variables** (`.env`): Simple key=value pairs loaded into containers. Visible in `docker inspect` and process listings.
- **Docker secrets**: Mounted as files at `/run/secrets/` inside the container. Never exposed in inspect output or logs. Recommended for passwords.
- **This project**: Non-sensitive config in `.env`, all passwords in `secrets/` files mounted via Docker Compose secrets.

### Docker Network vs Host Network

- **Host network** (`network: host`): Container shares the host's network stack directly. No isolation — all host ports are exposed.
- **Docker bridge network**: Containers get their own IP on a virtual network. They communicate by container name (DNS). Only explicitly published ports are reachable from the host.
- **This project**: Uses a bridge network called `inception`. Only NGINX publishes port 443 to the host.

### Docker Volumes vs Bind Mounts

- **Bind mounts**: Map a host directory directly into the container (`./data:/var/lib/mysql`). Tight coupling to host filesystem.
- **Named volumes**: Managed by Docker. Can use drivers and options. Portable and cleaner in compose files.
- **This project**: Uses named volumes with `local` driver and `device` option to store data at `/home/gkamanur/data/` — combines named volume benefits with a predictable host path.
  
# Standard way (modern Docker)
volumes:
  wordpress_data:
    driver: local
    driver_opts:
      type: bind
      device: ${DATA_PATH}/wordpress

# Alternative standard way
volumes:
  wordpress_data:
    external: true
    name: ${DATA_PATH}/wordpress

# Your current way (legacy/compatibility)
volumes:
  wordpress_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_PATH}/wordpress

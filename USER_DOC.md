# User Documentation

## What This Stack Provides

This project runs a complete web hosting environment with 7 services:

1. **NGINX** — The front door. All web traffic enters here via HTTPS (port 443).
2. **WordPress** — A blog/website CMS accessible at `/wordpress/`.
3. **MariaDB** — The database that stores all WordPress content.
4. **Redis** — A cache that makes WordPress faster.
5. **FTP** — Upload/download WordPress files remotely.
6. **Adminer** — A web UI to browse and manage the database.
7. **Monitor** — A live dashboard showing the health of all containers.

## Starting the Project

```bash
make        # Build and start everything
```

Wait ~30 seconds for all services to initialize (WordPress needs to download and configure itself on first run).

## Stopping the Project

```bash
make clean   # Stop containers (data is preserved in volumes)
make fclean  # Stop + delete all data (full reset)
```

## Accessing the Website

1. Add this line to your `/etc/hosts` file:
   ```
   127.0.0.1 gkamanur.42.fr
   ```

2. Open your browser and go to:
   - **Dashboard**: `https://gkamanur.42.fr`
   - **WordPress site**: `https://gkamanur.42.fr/wordpress/`
   - **WordPress admin panel**: `https://gkamanur.42.fr/wordpress/wp-admin/`

3. Accept the self-signed certificate warning in your browser.

## Credentials

All passwords are stored in the `secrets/` directory (not committed to git):

- `secrets/credentials.txt` — WordPress admin password
- `secrets/db_password.txt` — Database user password
- `secrets/db_root_password.txt` — Database root password
- `secrets/redis_password.txt` — Redis password
- `secrets/ftp_password.txt` — FTP password

The WordPress admin username is `inception_boss` (configured in `srcs/.env`).

## Checking Service Health

Open `https://gkamanur.42.fr` to see the monitoring dashboard. It shows:

- **Container Status**: Which containers are running
- **Health Checks**: Whether each service's port is responding
- **Connectivity Map**: Whether containers can reach each other
- **Failure Report**: Exact location and error if something is broken

The dashboard auto-refreshes every 5 seconds.

## Troubleshooting

**Containers won't start?**
```bash
docker compose -f srcs/docker-compose.yml logs    # Check logs
```

**WordPress shows database error?**
MariaDB may still be initializing. Wait 30 seconds and refresh.

**Certificate warning in browser?**
This is expected — we use a self-signed certificate. Click "Advanced" → "Proceed".

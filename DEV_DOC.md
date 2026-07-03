# Developer Documentation

## Set Up the Environment

Prerequisites:

- Docker
- Docker Compose
- A working shell on the target machine

Project configuration:

- Edit `srcs/.env` to set the username and domain values.
- Keep sensitive values in the `secrets/` directory.
- Make sure the host data directories can be created under the current user home directory.

## Build and Launch

Build and start the infrastructure from the repository root:

```bash
make
```

The Makefile calls Docker Compose from `srcs/`, builds the custom images, and starts the full stack.

## Container and Volume Management

Useful commands:

```bash
make create_dirs
make up
make down
make down-v
make fclean
make re
make status
make logs
```

Container access helpers:

```bash
make shell_db
make shell_wp
```

## Data Storage and Persistence

The project stores persistent data in Docker named volumes:

- MariaDB data is stored in the database volume.
- WordPress files are stored in the website volume.

The volumes are backed by host directories under the user home directory so data survives container rebuilds and restarts.

## Project Layout

- `Makefile`: orchestration helpers and cleanup targets.
- `srcs/docker-compose.yaml`: service definitions, network, volumes, and secrets.
- `srcs/requirements/mariadb/`: MariaDB Dockerfile, config, and entrypoint.
- `srcs/requirements/wordpress/`: WordPress Dockerfile, config, and entrypoint.
- `srcs/requirements/nginx/`: NGINX Dockerfile, TLS config, and entrypoint.
- `secrets/`: local secret files consumed by Docker secrets.
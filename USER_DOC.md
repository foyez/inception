# User Documentation

## Services Provided

This stack provides three services:

- NGINX: the HTTPS entrypoint exposed on port 443.
- WordPress: the web application served through PHP-FPM.
- MariaDB: the database used by WordPress.

## Start and Stop the Project

Create the host data directories and launch the stack:

```bash
make
```

You can also use the individual commands:

```bash
make create_dirs
make up
make down
make down-v
make fclean
```

## Access the Website and Admin Panel

- Website: `https://<login>.42.fr`
- WordPress admin panel: `https://<login>.42.fr/wp-admin`

Use the administrator credentials stored in the secret files under `secrets/`.

## Locate and Manage Credentials

Sensitive values are stored locally in these files:

- `secrets/db_password.txt`
- `secrets/db_root_password.txt`
- `secrets/credentials.txt`

Do not place passwords directly in `srcs/.env` or in Dockerfiles.

## Check That Services Are Running

Use one of these commands:

```bash
make status
make logs
```

If the website does not respond, check that the containers are running and that the domain name in `srcs/.env` matches the expected login.
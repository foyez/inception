# Inception Interview Guide

This guide is written to help you explain the project clearly in an interview. It focuses on two things for every part of the stack:

1. What it is.
2. Why it exists in this project.

It also explains the startup flow so you can describe how the containers depend on each other and how data persists.

## 1. High-Level Architecture

The project is a small web infrastructure composed of three services:

- NGINX: public entrypoint, TLS termination, reverse proxy.
- WordPress: application layer running PHP-FPM and WP-CLI.
- MariaDB: database layer.

Each service runs in its own container and is built from a custom Dockerfile. The containers communicate over a private Docker bridge network. Persistent data is stored with named volumes backed by host directories.

### Why this design

- Separation of concerns: web server, app server, and database are isolated.
- Easier debugging: each service has one job.
- Better security: only NGINX is exposed to the outside world.
- Better persistence: data survives container recreation.
- Better reproducibility: the whole stack can be rebuilt from the repository.

## 2. Startup Flow

You should be able to explain the stack in this order:

1. `make` creates the host data directories.
2. Docker Compose builds the images from the custom Dockerfiles.
3. MariaDB starts first and initializes the database if the volume is empty.
4. WordPress waits for MariaDB to be reachable, then downloads WordPress, creates `wp-config.php`, installs the site, and creates the secondary user.
5. NGINX generates a self-signed certificate, renders its config from a template, and starts in the foreground.

This flow matters because WordPress depends on MariaDB, and NGINX depends on WordPress being reachable through PHP-FPM.

## 3. Makefile Explained

File: `Makefile`

### `SRC_DIR = srcs`

This tells the Makefile where the Compose file lives.

### `include $(SRC_DIR)/.env`

This imports the username and domain variables from `.env` so `make` can create the correct local directories.

### `all: create_dirs up`

This means `make` first creates the host directories and then starts the stack.

### `create_dirs`

This creates:

- `$(HOME)/data/db`
- `$(HOME)/data/wordpress`

Why it exists:

- Docker named volumes are backed by local host directories in this project.
- The directories must exist and be writable before the containers start.
- Using `$(HOME)` makes the command work on the current machine, while on the VM the home directory is the learner’s home directory.

### `up`

Runs `docker compose up --build -d` from `srcs/`.

Why it exists:

- `--build` forces Docker to build the images from the Dockerfiles.
- `-d` starts containers in detached mode.

### `down`

Stops the stack without deleting volumes or images.

### `down-v`

Stops the stack and removes volumes.

Why the distinction matters:

- `down` keeps data.
- `down -v` removes persistent data.

### `fclean`

Stops the stack, removes images and volumes, and clears the host data directories.

### `status` and `logs`

- `status` shows the running containers.
- `logs` follows the Compose logs.

### `shell_db` and `shell_wp`

These open interactive shells inside the running MariaDB and WordPress containers.

### Interview questions you may get about Makefile

- Why not use shell scripts directly?
- Why create directories before Compose starts?
- Why does `fclean` remove data on the host?
- Why do you include `.env` in the Makefile?

## 4. Docker Compose Explained

File: `srcs/docker-compose.yaml`

### Services

#### `mariadb`

Builds the MariaDB image, names the container `mariadb`, restarts on crash, and uses the database volume.

#### `wordpress`

Builds the WordPress image, names the container `wordpress`, depends on MariaDB, and uses the WordPress volume.

#### `nginx`

Builds the NGINX image, names the container `nginx`, exposes only port `443`, and uses the WordPress volume to serve files.

### `image:`

The service images are named after the services themselves.

Why it matters:

- The project requires the image name to match the service name.
- It keeps the setup easy to identify.

### `restart: unless-stopped`

The container restarts if it crashes or if Docker restarts, unless you explicitly stop it.

Why it matters:

- Required by the project.
- Gives resilience if a container exits unexpectedly.

### `depends_on`

This defines startup order.

Important nuance:

- `depends_on` does not mean the service is ready, only that it has been started.
- That is why WordPress still waits for MariaDB inside its entrypoint.

### `ports: 443:443`

Only NGINX publishes port 443 to the host.

Why it matters:

- The infrastructure must be reachable only through HTTPS.
- MariaDB and WordPress should not be publicly exposed.

### `networks`

All services share the same bridge network named `inception`.

Why it matters:

- Containers can resolve each other by service name.
- Using a host network would break isolation and is forbidden by the project.

### `volumes`

Two named volumes are defined:

- `db_data` for MariaDB data.
- `wp_data` for WordPress files.

Why it matters:

- Data survives container deletion.
- The project explicitly requires named volumes.
- Bind mounts are not used for the project data itself.

### `secrets`

The secrets point to files in the `secrets/` directory.

Why it matters:

- Passwords should not be stored in plain environment variables or Dockerfiles.
- Secrets are mounted into the containers at runtime.

### Interview questions you may get about Compose

- Why use a bridge network instead of host networking?
- Why do you need both `depends_on` and a wait loop in WordPress?
- Why are volumes needed if containers already have writable filesystems?
- Why use secrets for passwords but env vars for domain/user names?

## 5. `.env` Explained

File: `srcs/.env`

Current purpose:

- `USERNAME` defines the learner login.
- `DOMAIN_NAME` becomes `<USERNAME>.42.fr`.
- WordPress metadata and DB identifiers are derived from the config.

Why use `.env`:

- Keeps non-sensitive configuration in one place.
- Makes the project reusable for different learner logins.
- Lets Compose and Make read the same variables.

What should not go here:

- Passwords.
- Root credentials.
- Sensitive tokens.

### Interview questions about `.env`

- Why not put passwords in `.env`?
- Why is the domain derived from the username?
- What is the difference between environment variables and secrets?

## 6. NGINX Explained

Files:

- `srcs/requirements/nginx/Dockerfile`
- `srcs/requirements/nginx/conf/nginx.conf`
- `srcs/requirements/nginx/tools/entrypoint.sh`

### NGINX role in the project

NGINX is the only public-facing service. It accepts HTTPS traffic, terminates TLS, and forwards PHP requests to WordPress.

### Why use NGINX

- It is a fast and reliable reverse proxy.
- It handles TLS termination well.
- It separates external traffic from the application container.

### Dockerfile

The NGINX Dockerfile installs:

- `nginx`
- `openssl`
- `gettext`

#### Why `openssl`

It is used to generate the self-signed certificate during container startup.

#### Why `gettext`

It provides `envsubst`, which is used to replace variables in the NGINX configuration template.

#### Why copy the config to a template path

The configuration is rendered at runtime, so the template is copied to a separate location first.

### `nginx.conf`

Important directives:

#### `listen 443 ssl;`

This tells NGINX to listen on HTTPS port 443 with SSL enabled.

#### `listen [::]:443 ssl;`

This enables IPv6 listening as well.

#### `http2 on;`

Enables HTTP/2 support.

#### `server_name ${DOMAIN_NAME};`

Uses the domain from the environment.

Why it matters:

- Makes the config reusable.
- Avoids hardcoding the learner login.

#### `ssl_certificate` and `ssl_certificate_key`

These point to the certificate and private key generated by the entrypoint.

#### `ssl_protocols TLSv1.2 TLSv1.3;`

Restricts the allowed TLS versions.

Why it matters:

- The project requires TLSv1.2 or TLSv1.3 only.
- Older TLS versions are less secure and should be disabled.

#### `fastcgi_pass wordpress:9000;`

This sends PHP requests to the WordPress container on port 9000.

Why it matters:

- NGINX does not execute PHP itself.
- PHP-FPM inside the WordPress container handles PHP execution.
- The service name `wordpress` works because both containers are on the same Docker network.

#### `fastcgi_param SCRIPT_FILENAME ...`

This tells PHP-FPM which file to execute.

Why it matters:

- Without it, PHP-FPM would not know which script the request is asking for.

### NGINX entrypoint

#### Guard clauses

The script checks that `DOMAIN_NAME` and `USERNAME` are present.

Why it matters:

- It fails early if the container is misconfigured.
- This is better than starting NGINX with invalid values.

#### `mkdir -p /etc/nginx/ssl`

Creates the directory for the certificate files.

#### `openssl req -x509 -nodes -days 365 ...`

Generates a self-signed certificate.

What each important flag means:

- `-x509`: create a self-signed certificate instead of a certificate signing request.
- `-nodes`: do not encrypt the private key with a passphrase.
- `-days 365`: certificate validity period.
- `-newkey rsa:2048`: generate a new RSA key pair.
- `-keyout`: path for the private key.
- `-out`: path for the certificate.
- `-subj`: certificate subject information, including the common name.

Why self-signed:

- The project asks you to set up TLS, not to buy or obtain a real certificate.
- Self-signed certificates are enough for local development and evaluation.

#### `envsubst '$DOMAIN_NAME $USERNAME' ...`

Replaces variables in the NGINX config template.

Why it matters:

- NGINX configuration files do not expand shell variables automatically.
- `envsubst` turns the template into a concrete config file at startup.

#### `nginx -t`

Tests the config before launching NGINX.

Why it matters:

- Catches syntax errors early.
- Prevents the container from starting with a broken config.

#### `exec nginx -g "daemon off;"`

This is a very important line to explain in an interview.

What it does:

- `exec` replaces the shell process with the NGINX process.
- `nginx -g "daemon off;"` tells NGINX not to daemonize itself.

Why it matters:

- In Docker, the container should usually keep the main service in the foreground as PID 1.
- If NGINX daemonizes itself, the shell entrypoint exits after starting NGINX in the background.
- When the PID 1 process exits, the container stops.
- Using `daemon off;` keeps NGINX attached to the container lifecycle.

This is the exact explanation you can give:

> If we do not use `daemon off`, NGINX will daemonize itself and run in the background. The entrypoint shell would then finish, the main process would exit, and Docker would stop the container.

### Interview questions about NGINX

- Why is NGINX the only exposed service?
- Why do you generate the certificate in the entrypoint instead of the Dockerfile?
- Why do you need `envsubst`?
- Why is `daemon off` necessary in a container?
- What does NGINX do with PHP requests?

## 7. WordPress Explained

Files:

- `srcs/requirements/wordpress/Dockerfile`
- `srcs/requirements/wordpress/tools/entrypoint.sh`

### WordPress role in the project

WordPress is the application layer. It contains PHP-FPM and WP-CLI so it can serve the site and configure it automatically.

### Dockerfile

The WordPress image installs:

- `php83`
- `php83-fpm`
- `php83-mysqli`
- `php83-phar`
- `php83-mbstring`
- `mariadb-client`
- `curl`
- `bash`

#### Why PHP-FPM

PHP-FPM is the process manager that executes PHP scripts for NGINX.

#### Why `php83-mysqli`

WordPress needs MySQL/MariaDB connectivity.

#### Why `php83-phar` and WP-CLI

WP-CLI is used to download and configure WordPress automatically.

#### Why `mariadb-client`

It provides tools like `mariadb-admin` for waiting on the database.

### WordPress entrypoint

#### `DB_PASSWORD=$(cat /run/secrets/db_password ...)`

Reads the DB password from a Docker secret.

Why it matters:

- Password is not hardcoded into the image.
- Password is not stored in `.env`.

#### `WP_ADMIN_PASSWORD=$(cat /run/secrets/credentials ...)`

Reads the WordPress administrator password from a secret.

#### `mariadb-admin ping ...`

This waits until MariaDB is reachable.

Why it matters:

- `depends_on` only ensures startup order, not readiness.
- WordPress must not try to install before MariaDB can accept connections.

#### `wp core download`

Downloads WordPress core files into the persistent webroot.

Why it matters:

- The website files must exist in the WordPress volume.
- If the volume is empty, the container must populate it.

#### `wp config create`

Generates `wp-config.php`.

Why it matters:

- This file contains the DB connection settings for WordPress.
- It needs the database name, user, password, and host.

#### `wp core install`

Installs the WordPress site once.

Key flags:

- `--url`: the public site URL.
- `--title`: the site title.
- `--admin_user`: the admin username.
- `--admin_password`: the admin password.
- `--admin_email`: the admin email.
- `--skip-email`: do not send install emails.

Why it matters:

- This sets up the initial administrator account.
- The project requires two users in the database, including an administrator.

#### `wp user create`

Creates the second user if it does not already exist.

Why it matters:

- Satisfies the requirement for two database users.
- Creates a regular user separate from the administrator.

#### `chown -R nobody:nobody /var/www/html`

Adjusts ownership of the WordPress files.

Why it matters:

- The web server should be able to read and use the files.
- This avoids permission issues after the files are created.

#### `php-fpm -t`

Tests PHP-FPM configuration.

#### `exec php-fpm -F`

Starts PHP-FPM in the foreground.

Why it matters:

- Same container rule as NGINX: the main service should stay in the foreground.
- `-F` keeps PHP-FPM attached to the container process tree.

### Interview questions about WordPress

- Why do you need WP-CLI?
- Why wait for MariaDB inside the container instead of only using `depends_on`?
- Why use a secret for the admin password?
- Why is PHP-FPM separate from NGINX?
- Why does the site install itself on first start?

## 8. MariaDB Explained

Files:

- `srcs/requirements/mariadb/Dockerfile`
- `srcs/requirements/mariadb/tools/entrypoint.sh`

### MariaDB role in the project

MariaDB stores the WordPress database and the user accounts created for the site.

### Dockerfile

The image installs:

- `mariadb`
- `mariadb-client`

Why both:

- `mariadb` provides the server.
- `mariadb-client` provides administration tools.

### MariaDB entrypoint

#### `DB_ROOT_PASSWORD` and `DB_PASSWORD`

These are loaded from Docker secrets.

Why it matters:

- The passwords are never written into the Dockerfile.
- The secrets can be replaced locally without rebuilding the image.

#### `/run/mysqld` setup

MariaDB needs a runtime socket directory with correct ownership.

#### `if [ ! -d "/var/lib/mysql/mysql" ]`

Checks whether the database volume is empty.

Why it matters:

- Initialization should only happen once.
- If the volume already contains data, we must not recreate the database from scratch.

#### `mariadb-install-db`

Initializes the database files.

#### `mariadbd --skip-networking &`

Starts a temporary database server without network access so the initialization SQL can run locally.

Why `skip-networking` here:

- The temporary server is only used for initialization.
- It reduces exposure while the DB is being bootstrapped.

#### `mariadb-admin --socket=... ping`

Checks readiness using the local socket.

Why it matters:

- Waits until the server is actually ready before sending SQL.
- Socket-based checks are reliable during initialization.

#### Initialization SQL

The SQL block:

- removes anonymous users,
- removes the test database,
- creates the WordPress database,
- creates the WordPress user,
- grants privileges,
- sets the root password,
- flushes privileges.

Why it matters:

- The database must be secure and usable by WordPress.
- The root account should not keep the default password.
- WordPress needs its own dedicated user, not the root user.

#### `exec mariadbd --user=mysql --skip-networking=0`

Starts the real MariaDB server in the foreground with networking enabled.

Why it matters:

- `exec` makes MariaDB the PID 1 process.
- `--skip-networking=0` enables TCP access so WordPress can connect over the Docker network.

### Interview questions about MariaDB

- Why do you initialize the database only once?
- Why start a temporary server before the final one?
- Why use the socket for initialization checks?
- Why create a separate WordPress user?
- Why is the root password changed during initialization?

## 9. TLS, SSL, and Certificates

### SSL vs TLS

In practice, people often say SSL, but the modern and correct protocol is TLS.

- SSL is the older family of protocols.
- TLS is the newer secure protocol used today.

For this project, you should say TLS when you want to be technically precise.

### What a certificate is

A certificate is a file that binds a domain name to a public key.

It allows the browser to verify:

- who the server claims to be,
- that the connection is encrypted,
- that the certificate is valid for the requested domain.

### Why generate a self-signed certificate

The project is local infrastructure work, so a self-signed certificate is enough.

Why not a public CA certificate:

- The project does not need external trust.
- A real CA certificate would require DNS and public validation.
- The point here is to understand TLS setup, not to buy a production certificate.

### `openssl req -x509 ...`

This creates a self-signed certificate and private key.

Key points to explain:

- `-x509`: produces a certificate.
- `-nodes`: keeps the private key unencrypted so NGINX can start automatically.
- `-subj`: sets the certificate subject, including the common name.

### Why the key is not encrypted

If the private key had a passphrase, NGINX would need interactive input at startup. That is not suitable for containers.

### Why the certificate and key are generated at runtime

- The domain name comes from the environment.
- Runtime generation allows one image to work for different learner logins.
- The certificate is tied to the configured domain.

## 10. Docker Concepts You Should Be Able to Explain

### Image vs Container

- An image is the blueprint.
- A container is the running instance created from that image.

### Why custom Dockerfiles are required

The project forbids using ready-made images for the services themselves.

### Why not use `latest`

`latest` is ambiguous and can change unexpectedly.

Fixed versions make the stack reproducible.

### Why no `tail -f`, `sleep infinity`, or infinite loops

The main service should run normally in the foreground.

Using fake keep-alive loops hides the real lifecycle and is discouraged in the project.

### Why `exec` matters in entrypoints

`exec` replaces the shell with the actual service process.

Why it matters:

- Signal handling works correctly.
- The service becomes PID 1.
- Docker sees the real process as the container’s main task.

### Why PID 1 matters

PID 1 has special signal handling behavior in Linux containers.

If the shell remains PID 1 and the real service is launched indirectly, signals may not be handled the way you expect.

## 11. Practical Interview Questions and Strong Answers

### “Why do you need a private network?”

Because the containers need to talk to each other by service name without exposing internal services to the host.

### “Why expose only port 443?”

Because NGINX should be the only public entrypoint and all browser traffic should use HTTPS.

### “Why not mount the database directly with a bind mount?”

Because the project requires named volumes and named volumes are better suited for portable persistent service data.

### “Why do you need both environment variables and secrets?”

Environment variables are good for non-sensitive config; secrets are for passwords and credentials that should not be visible in normal configuration files.

### “Why do you need `envsubst` for NGINX?”

Because NGINX does not expand shell variables directly in its config file. `envsubst` renders the final config before NGINX starts.

### “Why do you need `daemon off`?”

Because if NGINX daemonizes itself, the entrypoint shell exits and the container stops. The service must stay in the foreground.

### “Why wait for MariaDB inside the WordPress container?”

Because `depends_on` only controls startup order, not readiness. The database may still be initializing when WordPress starts.

### “Why use WP-CLI?”

Because it allows the container to install and configure WordPress automatically on first startup.

### “Why use a self-signed certificate?”

Because this is a local project and the goal is to configure TLS, not to obtain public trust from a certificate authority.

## 12. One-Sentence Summaries You Can Memorize

- NGINX is the only public entrypoint and handles HTTPS.
- WordPress runs PHP-FPM and installs itself through WP-CLI.
- MariaDB stores the site data and is initialized only once.
- Docker Compose wires the services together with a private network, secrets, and named volumes.
- `exec` and foreground mode keep the main process attached to the container lifecycle.
- TLS is used because the project requires encrypted HTTPS traffic on port 443.

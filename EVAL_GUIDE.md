# Inception — evaluation & interview prep

## 1. Before the evaluator arrives

Run this once to make sure you're starting clean (the eval sheet does this too):

```bash
docker stop $(docker ps -qa); docker rm $(docker ps -qa)
docker rmi -f $(docker images -qa)
docker volume rm $(docker volume ls -q)
docker network rm $(docker network ls -q) 2>/dev/null
make
```

Then confirm the site works before they sit down:
- `https://<login>.42.fr` loads WordPress (not the install page)
- `http://<login>.42.fr` does **not** connect
- `docker compose -f srcs/docker-compose.yaml ps` shows all 3 containers up

## 2. Commands you'll be asked to run

| What they check | Command |
|---|---|
| Containers created | `docker compose -f srcs/docker-compose.yaml ps` |
| Network exists | `docker network ls` → look for `inception` |
| Volumes exist + correct path | `docker volume ls` then `docker volume inspect <name>` → mountpoint should show `/home/<login>/data/...` |
| DB not empty | `make shell_db` → `mariadb -u root -p` → `SHOW DATABASES;` |
| Login to DB | You explain: root password + user password come from the two secret files, `mariadb -u <user> -p<pass> <db>` |

## 3. Live config-change rehearsal

They'll pick a service and a new port. Practice this exact sequence once with NGINX so it's automatic:

1. Edit `srcs/docker-compose.yaml` — change `"443:443"` to e.g. `"8443:443"` (left side = host port, right side stays 443 since that's what's inside the container and in `nginx.conf`).
2. `cd srcs && docker compose up -d --build nginx` (or `make re` if they want a full rebuild).
3. Verify: `https://<login>.42.fr:8443` loads the site.

Key point to say out loud: you're only remapping the **host** port. The container still listens on 443 internally — nothing in `nginx.conf` needs to change unless they ask you to change the *internal* port too, in which case you'd also edit the `listen` directive in `nginx.conf` and rebuild.

## 4. Known soft spots — have an answer ready

- **MariaDB entrypoint starts `mariadbd &` then kills it.** This only happens on first run, to initialize the database with no network exposed. It's killed before the real, foreground `exec mariadbd` starts — that's the actual PID 1 process. Say this proactively if they read the script.
- **`.env` and `secrets/` aren't in the repo.** That's intentional (gitignored) — point to `.gitignore` and explain the preliminary check requires this.
- **Alpine version.** You're pinned to `alpine:3.23`, which is the penultimate stable line (3.24 is current). Know this can shift — check `alpinelinux.org` if you rebuild close to the defense.

## 5. Concept refresher (plain English)

**Docker image vs. container**
An image is a read-only template — the filesystem plus instructions baked in by the Dockerfile. A container is a running instance of that image, with its own writable layer on top. One image, many containers.

**Image used with vs. without Compose**
Used alone (`docker run`), you manually manage networking, volumes, and startup order for every container. Compose reads one YAML file and does all of that declaratively — one command builds, networks, and starts everything together, in the right order (`depends_on`), with consistent config.

**Docker vs. VMs**
A VM virtualizes a whole computer, including its own kernel — heavy, slow to boot. A container shares the host's kernel and only isolates the process and filesystem — lightweight, starts in seconds. That's why three containers here cost far less than three VMs.

**Docker network**
A private virtual network Docker creates so containers can find each other by service name (`wordpress` resolves to the WordPress container's IP) without exposing anything to the host by default. Your `inception` network is a bridge network — only NGINX publishes a port to the host; WordPress and MariaDB are reachable only from inside that network.

**Volumes vs. bind mounts**
Both persist data outside the container's writable layer. A named volume is managed by Docker (`docker volume ls` shows it, Docker decides where it lives). A bind mount points directly at a host path you choose. Your setup is actually a hybrid — named volumes (`db_data`, `wp_data`) configured with the `local` driver and `type: none, o: bind` options, so Docker manages the volume name but the actual data sits at a host path you control (`$HOME/data/...`). This is what satisfies both "must be a named volume" and "must be inspectable at `/home/login/data/`."

**Secrets vs. environment variables**
Environment variables are visible in `docker inspect`, process listings, and logs — fine for non-sensitive config like a domain name. Docker secrets are mounted as files under `/run/secrets/` inside the container only, never shown in `docker inspect` or `ps`. That's why passwords go through secrets and everything else goes through `.env`.

**NGINX's role here**
NGINX is the only container with a published port. It terminates TLS (decrypts HTTPS), serves static files directly, and forwards anything ending in `.php` to WordPress over FastCGI on port 9000. It never talks to MariaDB directly.

**FastCGI / PHP-FPM**
NGINX can serve static files but can't execute PHP. PHP-FPM is a process manager that runs PHP and listens for requests over the FastCGI protocol. `fastcgi_pass wordpress:9000` in your `nginx.conf` tells NGINX where to forward `.php` requests; `SCRIPT_FILENAME` tells PHP-FPM which file to run.

**TLS / SSL, in brief**
TLS encrypts traffic between browser and server so it can't be read or tampered with in transit. Your entrypoint generates a self-signed certificate with `openssl req -x509` — self-signed means you're your own certificate authority, so browsers show a trust warning, but the traffic is still genuinely encrypted with real TLS 1.2/1.3. A CA-signed cert (like Let's Encrypt) only adds *trust*, not *encryption strength* — that's why a self-signed cert is acceptable for this project.

**Why WordPress needs no NGINX in its own image**
Separation of concerns, and it's a hard requirement: NGINX is the single public-facing layer; WordPress's job is only to run PHP-FPM against the shared `wp_data` volume, which NGINX also mounts read-only-in-spirit to serve static assets like images and CSS.

**Makefile flow, one line each**
`all` → creates host data dirs, then brings the stack up. `up` → `docker compose up --build -d`. `down` → stop, keep data. `down-v` → stop and delete volumes. `fclean` → stop, delete images + volumes + host data. `re` → `fclean` then `all`, i.e. a full reset and rebuild.

## 6. Likely trap questions

- *"Why not just use the official WordPress/MariaDB images?"* → Forbidden by the subject; you built every image from a bare Alpine base yourself, which is also why you understand every layer.
- *"What happens if MariaDB isn't ready when WordPress starts?"* → WordPress's entrypoint loops on `mariadb-admin ping` until MariaDB answers, before touching `wp-config.php`.
- *"What if I reboot the VM right now?"* → Bind-mounted host directories under `$HOME/data` survive a reboot untouched; `docker compose up` (via `make`) reconnects the existing volumes, so WordPress and MariaDB come back with all prior data intact — nothing gets reinitialized because the entrypoints check for existing state first (`if [ ! -d /var/lib/mysql/mysql ]`, `if [ ! -f wp-config.php ]`).
- *"Why does the admin username matter?"* → Subject requires it not literally contain `admin`/`Admin`, to avoid the most-guessed WordPress username in brute-force attacks — confirm your `.env` actually complies before they log in.
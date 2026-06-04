# Traveling Ruby

Companion repo for [A Pattern for Local Dev: Runtime on the Host, Services in Containers](https://flox.dev/blog/a-pattern-for-local-dev/).

A Rails 8 API backed by PostgreSQL, with the same development environment declared three ways using **Flox**, **Nix**, and **Guix** — declared, graph-backed technologies that define the full runtime surface: language, native libraries, build toolchain, and CLI tools. A **mise** config is included to show where project-scoped version managers reach their limits.

## The pattern

The project runtime runs directly on the host, inside a declared environment. Backing services (PostgreSQL) run in containers. Engineers don't work inside containers; they connect to services using host, port, and credential settings defined in the environment.

## Why declared, graph-backed environments

This project doesn't just need Ruby. It also needs PostgreSQL client libraries, libyaml, a C compiler, make, pkg-config, curl, CA certificates, time zone data, and a few developer utilities. Flox, Nix, and Guix declare all of these as part of the project environment and resolve them deterministically via a package graph. mise can declare the Ruby version — the rest falls back to whatever the host system happens to provide.

## The four environments

| File | Tool | What it declares |
|------|------|-----------------|
| `.flox/env/manifest.toml` | [Flox](https://flox.dev) | Full runtime: Ruby, native libs, toolchain, env vars, aliases, services |
| `flake.nix` | [Nix](https://nixos.org) | Full runtime: same packages, same shell hooks |
| `manifest.scm` + `setup-env.sh` | [Guix](https://guix.gnu.org) | Full runtime: same packages, shell init sourced separately |
| `.mise.toml` | [mise](https://mise.jdx.dev) | Ruby version, env vars, and task aliases only |

All four provide the same developer experience once activated: identical aliases (`dbup`, `dev`, `tests`, `rs`, `rc`, etc.), identical environment variables, and identical gem paths. The difference is in what they can declare — Flox, Nix, and Guix provide the native libraries and build toolchain that mise expects the host to supply.

## Quick Start (Flox)

### Prerequisites

- [Flox](https://flox.dev/docs/install-flox/) installed
- Docker Engine (Linux) or Docker Desktop (macOS)

### Setup

```bash
git clone https://github.com/flox/traveling-ruby && cd traveling-ruby
flox activate

dbup                        # start PostgreSQL in Docker
bundle install              # install gems
bundle exec rails db:setup  # create and seed the database
dev                         # start the Rails server
```

### Quick Start (Nix)

```bash
cd traveling-ruby
nix develop

dbup
bundle install
bundle exec rails db:setup
dev
```

### Quick Start (Guix)

```bash
cd traveling-ruby
guix shell -m manifest.scm
source setup-env.sh

dbup
bundle install
bundle exec rails db:setup
dev
```

### Verify

```bash
curl http://localhost:3000/health
# => {"status":"ok","database":"connected"}

curl http://localhost:3000/items
# => [{"id":1,"name":"Example Item","description":"Created by db:seed ..."}]

curl -X POST http://localhost:3000/items \
  -H "Content-Type: application/json" \
  -d '{"item": {"name": "Hello", "description": "From a declared environment"}}'
```

## All Commands

These aliases are available in all four environments:

| Command | What it does |
|---------|-------------|
| `dbup` | Start PostgreSQL container |
| `dbdown` | Stop PostgreSQL container (data preserved) |
| `dbreset` | Destroy and recreate database from scratch |
| `dev` | Start Rails development server |
| `rs` | Start Rails server (binds to 0.0.0.0) |
| `rc` | Open Rails console |
| `tests` | Run the test suite |
| `build-image` | Build the production Docker image |

In mise, these are invoked as `mise run dbup`, `mise run dev`, etc.

## Gem caches are isolated per environment

Each environment stores compiled gems in a separate cache directory to avoid native extension conflicts across different Ruby builds:

| Environment | Cache directory |
|---|---|
| Flox | `$FLOX_ENV_CACHE/bundler/` (managed by Flox) |
| Nix | `~/.cache/traveling-rails-poc-nix/bundler/` |
| Guix | `~/.cache/traveling-rails-poc-guix/bundler/` |
| mise | `~/.cache/traveling-rails-poc/bundler/` |

Run `bundle install` once per environment.

## CI

The GitHub Actions workflow installs Flox and runs tests inside `flox activate`. CI uses the same declared runtime as local development — no separate Ruby version matrix or system dependency list to maintain.

## Production container

The `Dockerfile` mirrors the runtime declared in the environment manifests using equivalent Debian packages. The mapping is explicit and documented in the Dockerfile header. See [DESIGN.md](DESIGN.md) for details.

```bash
build-image
docker run -p 3000:3000 \
  -e DATABASE_HOST=host.docker.internal \
  -e DATABASE_USER=postgres \
  -e DATABASE_PASSWORD=postgres \
  -e SECRET_KEY_BASE=$(bundle exec rails secret) \
  traveling-rails-poc
```

## Repo Structure

```
.
├── .flox/                    # Flox environment
│   └── env/manifest.toml     #   packages, env vars, aliases, services
├── flake.nix                 # Nix equivalent (nix develop)
├── manifest.scm              # Guix equivalent (guix shell -m manifest.scm)
├── setup-env.sh              #   shell init for the Guix environment
├── .mise.toml                # mise equivalent (languages + tasks only)
├── .github/workflows/ci.yml  # CI via Flox
├── docker-compose.yml        # PostgreSQL for local dev
├── Dockerfile                # Production image
├── scripts/                  # Developer workflow commands
│   ├── dev                   #   start dev server
│   ├── db-up                 #   start PostgreSQL
│   ├── db-down               #   stop PostgreSQL
│   ├── db-reset              #   reset database
│   ├── test                  #   run tests
│   └── build-image           #   build production image
├── app/                      # Rails application
├── config/                   # Rails configuration
├── db/                       # Migrations and seeds
├── test/                     # Test suite
└── DESIGN.md                 # Architecture and tradeoff analysis
```

## Further Reading

- [DESIGN.md](DESIGN.md) — architecture notes and tradeoff analysis
- [Flox documentation](https://flox.dev/docs/)
- [Nix manual](https://nixos.org/manual/nix/stable/)
- [Guix manual](https://guix.gnu.org/manual/)
- [mise documentation](https://mise.jdx.dev/)

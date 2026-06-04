#!/usr/bin/env bash
# setup-env.sh — shell initialization for the Guix dev environment
#
# Equivalent of the Flox [hook] on-activate + [profile] sections.
# Source this after entering the Guix shell:
#   guix shell -m manifest.scm
#   source setup-env.sh

# ---------------------------------------------------------------
# Project paths (equivalent of $FLOX_ENV_PROJECT / $FLOX_ENV_CACHE)
# ---------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FLOX_ENV_PROJECT="$SCRIPT_DIR"
export FLOX_ENV_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/traveling-rails-poc-guix"
mkdir -p "$FLOX_ENV_CACHE"

# ---------------------------------------------------------------
# [vars] — static variables
# ---------------------------------------------------------------
export APP_NAME="traveling-rails-poc"

# ---------------------------------------------------------------
# [hook] on-activate — runtime-configurable variables
# ---------------------------------------------------------------
export DATABASE_HOST="${DATABASE_HOST:-localhost}"
export DATABASE_PORT="${DATABASE_PORT:-5432}"
export DATABASE_USER="${DATABASE_USER:-postgres}"
export DATABASE_PASSWORD="${DATABASE_PASSWORD:-postgres}"
export RAILS_ENV="${RAILS_ENV:-development}"

# Ruby/Bundler environment — store everything in cache dir
RUBY_LIB_VERSION="3.4.0"
export BUNDLE_PATH="$FLOX_ENV_CACHE/bundler"
export BUNDLE_BIN="$FLOX_ENV_CACHE/bundler/bin"
export GEM_HOME="$FLOX_ENV_CACHE/bundler/ruby/$RUBY_LIB_VERSION"
export GEM_PATH="$GEM_HOME/gems:${GEM_PATH:-}"
export BOOTSNAP_CACHE_DIR="$FLOX_ENV_CACHE/bootsnap"
export PATH="$FLOX_ENV_PROJECT/bin:$BUNDLE_BIN:$GEM_HOME/bin:$PATH"

# Ensure pkg-config can find libyaml for psych gem compilation.
# Guix profiles merge dev outputs, but verify and fix up if needed.
if ! pkg-config --exists yaml-0.1 2>/dev/null; then
    for _profile_dir in $GUIX_ENVIRONMENT $GUIX_PROFILE; do
        if [ -f "$_profile_dir/lib/pkgconfig/yaml-0.1.pc" ]; then
            export PKG_CONFIG_PATH="$_profile_dir/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
            break
        fi
    done
    unset _profile_dir
fi

# ---------------------------------------------------------------
# [profile] — aliases and functions
# ---------------------------------------------------------------
alias be="bundle exec"
alias rs="bundle exec rails server -b 0.0.0.0"
alias rc="bundle exec rails console"
alias dbup="$FLOX_ENV_PROJECT/scripts/db-up"
alias dbdown="$FLOX_ENV_PROJECT/scripts/db-down"
alias dbreset="$FLOX_ENV_PROJECT/scripts/db-reset"
alias dev="$FLOX_ENV_PROJECT/scripts/dev"
alias tests="$FLOX_ENV_PROJECT/scripts/test"
alias build-image="$FLOX_ENV_PROJECT/scripts/build-image"

# Wrap bundle to auto-generate binstubs after install
bundle() {
    local run_binstubs=0

    if (( $# == 0 )); then
        run_binstubs=1
    elif [[ "$1" == "install" ]]; then
        run_binstubs=1
    fi

    command bundle "$@"
    local rc=$?

    if (( rc == 0 && run_binstubs == 1 )); then
        command bundle binstubs --all
    fi

    return $rc
}

# Display environment info
if command -v gum &>/dev/null; then
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 56 --margin "1 0" --padding "1 2" \
        "$APP_NAME" \
        "" \
        "Ruby $(ruby --version | cut -d' ' -f2)" \
        "Rails app · PostgreSQL in Docker"

    gum style --foreground 248 \
        "  Database: $DATABASE_HOST:$DATABASE_PORT" \
        "  Scripts:  scripts/{dev,db-up,db-down,db-reset,test}" \
        "  Run:      bundle install  (first time setup)"
else
    echo "══════════════════════════════════════════════════════"
    echo "  $APP_NAME"
    echo ""
    echo "  Ruby $(ruby --version | cut -d' ' -f2)"
    echo "  Rails app · PostgreSQL in Docker"
    echo "══════════════════════════════════════════════════════"
    echo "  Database: $DATABASE_HOST:$DATABASE_PORT"
    echo "  Scripts:  scripts/{dev,db-up,db-down,db-reset,test}"
    echo "  Run:      bundle install  (first time setup)"
fi

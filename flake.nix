{
  description = "traveling-rails-poc — Rails dev environment (replaces Flox manifest)";

  inputs = {
    # Pinned to the exact nixpkgs rev from the Flox lockfile
    nixpkgs.url = "github:flox/nixpkgs/b40629efe5d6ec48dd1efba650c797ddbd39ace0";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system: f system);
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            name = "traveling-rails-poc";

            # Build tools — mkShell wires these into PATH, PKG_CONFIG_PATH, etc.
            nativeBuildInputs = with pkgs; [
              pkg-config
              gnumake
            ] ++ (if pkgs.stdenv.isDarwin then [ clang ] else [ gcc ]);

            # Libraries — mkShell propagates dev outputs (headers, .pc files)
            buildInputs = with pkgs; [
              libyaml
              postgresql
            ];

            # Runtime support and developer/operator tools
            packages = with pkgs; [
              ruby
              cacert
              tzdata
              curl
              gum
              coreutils
              gnused
            ];

            # [vars] — static environment variables
            APP_NAME = "traveling-rails-poc";

            shellHook = ''
              # ---------------------------------------------------------------
              # Equivalent of Flox $FLOX_ENV_PROJECT / $FLOX_ENV_CACHE
              # ---------------------------------------------------------------
              export FLOX_ENV_PROJECT="$(pwd)"
              export FLOX_ENV_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/traveling-rails-poc-nix"
              mkdir -p "$FLOX_ENV_CACHE"

              # ---------------------------------------------------------------
              # [hook] on-activate — runtime-configurable variables
              # ---------------------------------------------------------------
              export DATABASE_HOST="''${DATABASE_HOST:-localhost}"
              export DATABASE_PORT="''${DATABASE_PORT:-5432}"
              export DATABASE_USER="''${DATABASE_USER:-postgres}"
              export DATABASE_PASSWORD="''${DATABASE_PASSWORD:-postgres}"
              export RAILS_ENV="''${RAILS_ENV:-development}"

              # Runtime support paths supplied by the dev shell
              export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              export NIX_SSL_CERT_FILE="$SSL_CERT_FILE"
              export TZDIR="${pkgs.tzdata}/share/zoneinfo"

              # Ruby/Bundler environment — store everything in cache dir
              RUBY_LIB_VERSION="3.4.0"
              export BUNDLE_PATH="$FLOX_ENV_CACHE/bundler"
              export BUNDLE_BIN="$FLOX_ENV_CACHE/bundler/bin"
              export GEM_HOME="$FLOX_ENV_CACHE/bundler/ruby/$RUBY_LIB_VERSION"
              export GEM_PATH="$GEM_HOME/gems:''${GEM_PATH:-}"
              export BOOTSNAP_CACHE_DIR="$FLOX_ENV_CACHE/bootsnap"
              export PATH="$FLOX_ENV_PROJECT/bin:$BUNDLE_BIN:$GEM_HOME/bin:$PATH"

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
            '';
          };
        });
    };
}

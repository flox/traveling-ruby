;; GNU Guix development manifest — equivalent of the Flox environment
;;
;; Usage:
;;   guix shell -m manifest.scm
;;   source setup-env.sh
;;
;; Note: Guix runs on Linux only. macOS-specific packages from the Flox
;; manifest (orbstack, clang) are not applicable here.

(use-modules (gnu packages)
             (guix profiles))

(packages->manifest
 (list
  ;; Language runtime
  (specification->package "ruby@3.4")          ; Ruby 3.4.x - the app runtime

  ;; Database client / pg build support
  (specification->package "postgresql@16")     ; PostgreSQL client libs + psql CLI

  ;; Native library dependencies
  (specification->package "libyaml")           ; Required by psych/YAML-related native extensions

  ;; Build toolchain for native gem extensions
  ;; Guix is Linux-focused, so use gcc-toolchain here rather than a Darwin clang/gcc split.
  (specification->package "gcc-toolchain")     ; C compiler/toolchain for native extensions
  (specification->package "make")              ; GNU Make
  (specification->package "pkg-config")        ; Finds library paths for compilation

  ;; Runtime support / local-dev parity
  (specification->package "nss-certs")         ; CA certificates, Guix equivalent of cacert
  (specification->package "tzdata")            ; Time zone data

  ;; Developer utilities
  (specification->package "curl")              ; HTTP client for API testing

  ;; Cross-platform compatibility
  (specification->package "coreutils")         ; GNU coreutils
  (specification->package "sed")))             ; GNU sed
  
;; gum (charmbracelet/gum) is not packaged in Guix.
;; setup-env.sh will check for it and fall back to plain echo if missing.
;; To install gum manually:
;;   go install github.com/charmbracelet/gum@latest

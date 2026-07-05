# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Host-visible version + lifecycle channel for container game servers**
  (feature-parity groundwork for kgsm-watchdog's container UPnP + run-state,
  reusing the existing `${instance_events_dir}` bind mount — no new mount
  needed). Every game's in-container management script (`vrising`, `empyrion`,
  `theforest`, `lotrrtm`, `abioticfactor`, `enshrouded`) plus
  `templates/container.manage.sh`:
  - `_save_version` now also best-effort writes the version to
    `${KGSM_EVENTS_DIR:-/run/kgsm}/version`, since `$instance_version_file`
    lives in the un-mounted working-dir root and the host previously had no
    way to see the real installed build id.
  - New `_emit_lifecycle <type>` appends one NDJSON line
    (`{"type":"...","ts":"<ISO-8601-UTC>"}`) to
    `${KGSM_EVENTS_DIR:-/run/kgsm}/lifecycle.ndjson`, always best-effort/
    guarded (never fails the caller, never emits on a guard failure — mirrors
    the presence shim's honesty rule). `_start` truncates (fresh inode) the
    channel at the top of every start and emits `instance_started`
    immediately before the final `exec` of the game. `instance_stopping` is
    emitted from the trap that actually governs `INT`/`TERM` (the *last*
    `trap ... SIGNAL` registration wins in bash — for the UPnP-enabled games
    that is `trap '_exit_print_logs' TERM EXIT INT`, now split into a
    signal-scoped `EXIT` trap and an `INT TERM` trap so the lifecycle emit
    doesn't fire on every ordinary command exit). **Known limitation:** once
    `_start` reaches the final `exec` of the game, the bash process is
    replaced entirely, so this trap is unreachable for the remainder of the
    container's life — `instance_stopping` only fires if a signal arrives
    during the pre-exec setup window, same pre-existing limitation the
    UPnP-disable trap already had. `instance_started` is unaffected (emitted
    from within bash, before the exec).

- **Host→container console command channel.** Every game's in-container
  management script (`vrising`, `empyrion`, `theforest`, `lotrrtm`,
  `abioticfactor`, `enshrouded`) plus `templates/container.manage.sh`: `_start`
  now creates a fresh FIFO at `${KGSM_EVENTS_DIR:-/run/kgsm}/command.fifo`
  (fully guarded — `mkfifo` failure falls back to launching without the
  redirect, never hangs boot), starts a `tail -f /dev/null` keepalive writer
  on it *before* the game opens it for reading (so that open never blocks
  waiting for a writer), and redirects the game's stdin from it on the final
  `exec`. This is an independent channel from the existing stdin-FIFO
  stop/save path (`$instance_socket_file`, native-only / `_start_background`)
  — that path is untouched. Host-side, kgsm's
  `manage.container.d/04-io.sh` `_send_input`/`_send_save_command` now write
  directly to `${instance_events_dir}/command.fifo` instead of the previously
  broken `docker exec -i ... --input` roundtrip (that roundtrip targeted
  `$instance_socket_file`, which containers — always launched via the
  foreground `_start()` — never created).

- **Auto-update-before-start for container game servers.** Every game's
  in-container management script (`vrising`, `empyrion`, `theforest`, `lotrrtm`,
  `abioticfactor`, `enshrouded`) plus the `templates/container.manage.sh`
  skeleton now honor the `INSTANCE_AUTO_UPDATE` env var (injected by KGSM from
  the instance's `instance_auto_update_before_start` flag). When set, `_start`
  runs `_update` (SteamCMD) to refresh the game to the latest version before
  launching — mirroring native KGSM instances. Previously the game was only
  installed on first start (empty volume) and then never updated, so a
  bind-mounted install would stay pinned to an old version.

### Changed
- **Migrated `enshrouded` from the legacy `entrypoint.sh` to the standard
  `enshrouded.manage.sh`** used by every other image (start/stop/save/update/
  backup/version contract, stdin-FIFO stop path, log handling). enshrouded was
  the last image still on the original pre-standardization style. The wine
  prefix setup (`wineboot` + `winetricks corefonts`/`vcrun2022` + `winecfg`)
  moved from per-boot into an image-build step, so it bakes into the image
  instead of re-running on every container start. Added `enshrouded/build.sh`
  (was missing) and removed the stray `VOLUME` declaration from its Dockerfile.

## [1.0.0] - 2026-06-30

### Added
- Initial versioned release.

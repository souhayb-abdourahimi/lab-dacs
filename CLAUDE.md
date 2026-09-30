# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Personal security/sysadmin lab (BUT Informatique DACS). Ansible turns a bare Debian/Ubuntu/Fedora/Rocky/Alma VM into a hardened, monitored server (Docker stacks for Prometheus/Loki/Alloy/Grafana and AdGuard Home, CrowdSec + firewall bouncer, ufw/firewalld, SSH hardening, ntfy push alerts). A separate, optional module (`detection-pc`) protects the user's own workstation against physical access.

**Everything is written in French**: code comments, variable/task/role names (`parefeu`, `alertes`, `retirer`, `lab_test_conteneur`…), docs, commit messages. Keep new code and docs in French and in the same style.

## Commands

```bash
make deps                 # pip install -r requirements-dev.txt + ansible-galaxy collections
make lint                 # shellcheck + yamllint --strict + ansible-lint (production) + ruff check/format
make shellcheck | yamllint | ansible-lint | ruff   # individual linters
make test                 # Molecule (Docker) on DISTRO=debian12
make test DISTRO=rocky9   # also debian13, ubuntu2404
make test-all             # all four CI distros
make e2e                  # real QEMU/KVM VM running the real ./install.sh (E2E_DISTRO=debian13|ubuntu2404)
make deploy               # re-run site.yml after a first ./install.sh
```

- `ansible.cfg` requires `ansible/.vault_pass`; the Makefile substitutes a dummy one (`.cache/vault-factice`) for lint/tests. When running `ansible-lint`/`molecule` by hand, set `ANSIBLE_VAULT_PASSWORD_FILE` to any dummy file.
- Molecule runs from `ansible/` with `MOLECULE_DISTRO` and `MOLECULE_IMAGE` env vars (see Makefile for image names). Sequence includes an **idempotence** step: a second converge must report 0 changed.
- shellcheck runs on `git ls-files '*.sh' 'detection-pc/commandes/*'` at `-S style` (so the extension-less scripts in `detection-pc/commandes/` are checked too; new files must be `git add`ed to be linted).
- Python (`detection-pc/scripts/surveillance-activite.py`) must pass `ruff check` and `ruff format --check` (py39 target, line length 120).

## Architecture

**Two entry points, two playbooks:**
- `install.sh` → `ansible/site.yml` (hosts: `serveurs`). Interactive: installs ansible-core ≥ 2.16 if needed (distro package, else pipx/venv), installs collections, writes `inventory/hosts.yml`, creates and encrypts `group_vars/all.yml` with Ansible Vault, then deploys.
- `install-pc.sh` → `ansible/pc.yml` (hosts: localhost, role `detection_pc`; `--retirer` uninstalls via `retirer.yml`). Webcam capture is opt-in (`webcam_active: false` by default).
- `lib/commun.sh` is sourced by both scripts (package manager detection for apt/dnf/pacman/zypper, Ansible install, `yaml_quote`). These control-machine scripts must stay bash + POSIX tools only (no `grep -P`, `sed -E`, `sort -V`, `readlink -f`).

**Role order in `site.yml` matters:** `secrets → selinux → docker → supervision → adguard → alertes → parefeu → crowdsec → ssh`. `site.yml` pre_tasks install Python via `raw`, gather facts, assert OS support, and set shared facts used across roles: `ssh_service` (`ssh` vs `sshd`) and `lab_dacs_dir` (deploy dir, default `~<ansible_user>/lab-dacs`, read from getent).

**The `secrets` role normalises vault variables** into `secrets_*` facts (`secrets_adguard_user`, `secrets_adguard_password` split on the *first* `:` of `adguard_auth`; `secrets_ntfy_serveur` with trailing `/` stripped) and renders `/etc/lab-alertes.conf`, which the alert scripts source at runtime. Other roles should consume the `secrets_*` facts, not raw vault vars. Secrets are deliberately tested with tricky characters (`' : # " $`, spaces) — preserve correct quoting/escaping.

**Roles copy files from top-level directories** via `{{ playbook_dir }}/../<dir>`: `supervision/` (compose + Prometheus/Loki/Alloy/Grafana provisioning incl. dashboards), `adguard/`, `alertes/` (scripts + systemd units/timers), `detection-pc/` (scripts, commandes, systemd, udev). Edit the source files there; the role just deploys them. `docker/` and `configs/` (nginx, web stack) are **not** deployed by Ansible yet and are excluded from ansible-lint.

**OS branching** is done per role with separate task files (`docker/tasks/{debian,fedora,el}.yml`, `parefeu/tasks/{ufw,firewalld}.yml`, `crowdsec/tasks/installer_{debian,redhat}.yml`). SELinux is never disabled; paths get `container_file_t` when enforcing.

**Container test mode:** `lab_test_conteneur: true` (set in `molecule.yml`) skips the firewall and sshd restart. Anything that can't run in a privileged systemd container must be guarded by this variable.

## Testing layers (CI: `.github/workflows/`)

- `lint.yml` — static analysis.
- `molecule.yml` — `site.yml` in Docker on debian12/debian13/ubuntu2404/rocky9; `ansible/molecule/default/verify.yml` checks Grafana, Loki + "Sécurité" dashboard, AdGuard DNS, CrowdSec, sshd config, alert timers.
- `e2e-vm.yml` — `tests/e2e/scenario.sh`: boots a cloud-image VM (`lancer-vm.sh`), drives the real `./install.sh` through `install.exp` (expect — update it if install.sh prompts change), runs `verifier.sh` before/after/after-rerun (firewall, CrowdSec bans, Loki/Grafana counters, ntfy delivery), and requires a 0-changed second run.

## Secrets and generated files

Never commit `ansible/group_vars/all.yml`, `ansible/inventory/hosts.yml`, `ansible/.vault_pass`, or `.env` files; only the `*.example` templates are versioned (see `ansible/.gitignore`).

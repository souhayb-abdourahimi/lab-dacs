# lab-dacs — raccourcis de développement et de déploiement
#
#   make lint                 analyse statique (shellcheck, yamllint, ansible-lint, ruff)
#   make test                 test Molecule de site.yml (DISTRO=debian12 par défaut)
#   make test DISTRO=rocky9   ... sur une autre distribution
#   make test-all             ... sur toutes les distributions de la CI
#   make deploy               (re)déploie le serveur (inventaire + coffre créés par install.sh)
#   make pc                   installe la détection d'accès sur CE poste
#   make deps                 installe les outils de développement (requirements-dev.txt)

SHELL := /bin/bash
.DEFAULT_GOAL := help

DISTRO ?= debian12
DISTROS := debian12 debian13 ubuntu2404 rocky9
IMAGE_debian12   := geerlingguy/docker-debian12-ansible:latest
IMAGE_debian13   := geerlingguy/docker-debian13-ansible:latest
IMAGE_ubuntu2404 := geerlingguy/docker-ubuntu2404-ansible:latest
IMAGE_rocky9     := geerlingguy/docker-rockylinux9-ansible:latest

# ansible.cfg attend ansible/.vault_pass : sans coffre (lint, tests), un faux suffit
VAULT_FACTICE := $(CURDIR)/.cache/vault-factice
VAULT_PASS := $(if $(wildcard ansible/.vault_pass),$(CURDIR)/ansible/.vault_pass,$(VAULT_FACTICE))

$(VAULT_FACTICE):
	@mkdir -p $(@D) && printf 'factice' > $@

.PHONY: help deps lint shellcheck yamllint ansible-lint ruff test test-all deploy install pc

help: ## Affiche cette aide
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  make %-14s %s\n", $$1, $$2}'

deps: ## Installe les outils de développement et les collections Ansible
	python3 -m pip install -r requirements-dev.txt
	cd ansible && ansible-galaxy collection install -r requirements.yml

lint: shellcheck yamllint ansible-lint ruff ## Toute l'analyse statique

shellcheck: ## Scripts shell
	git ls-files -z '*.sh' 'detection-pc/commandes/*' | xargs -0 shellcheck -S style

yamllint: ## Fichiers YAML
	yamllint --strict .

ansible-lint: $(VAULT_FACTICE) ## Playbooks et rôles (profil production)
	ANSIBLE_VAULT_PASSWORD_FILE=$(VAULT_PASS) ansible-lint

ruff: ## Scripts Python (lint + format)
	ruff check .
	ruff format --check .

test: $(VAULT_FACTICE) ## Test Molecule sur DISTRO (debian12, debian13, ubuntu2404, rocky9)
	@test -n "$(IMAGE_$(DISTRO))" || { echo "DISTRO inconnue : $(DISTRO) ($(DISTROS))"; exit 1; }
	cd ansible && MOLECULE_DISTRO=$(DISTRO) MOLECULE_IMAGE=$(IMAGE_$(DISTRO)) \
		ANSIBLE_VAULT_PASSWORD_FILE=$(VAULT_PASS) molecule test

test-all: ## Test Molecule sur toutes les distributions
	@for d in $(DISTROS); do $(MAKE) --no-print-directory test DISTRO=$$d || exit 1; done

deploy: ## Déploie le serveur (après un premier ./install.sh)
	@test -f ansible/inventory/hosts.yml || { echo "Pas d'inventaire : lancez d'abord ./install.sh"; exit 1; }
	cd ansible && ansible-playbook site.yml --ask-become-pass

install: ## Déploiement guidé complet (Ansible, coffre, inventaire, déploiement)
	./install.sh

pc: ## Détection d'accès physique sur ce poste de travail
	./install-pc.sh

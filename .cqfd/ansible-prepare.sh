#!/bin/bash
# Clone (if needed) the SEAPATH ansible repo and run its prepare.sh.
# Override location/source via env vars.
set -e

ANSIBLE_REPO="${ANSIBLE_REPO:-./ansible}"
ANSIBLE_URL="${ANSIBLE_URL:-https://github.com/seapath/ansible.git}"
ANSIBLE_REF="${ANSIBLE_REF:-main}"

if [ ! -d "$ANSIBLE_REPO/.git" ]; then
    git clone "$ANSIBLE_URL" "$ANSIBLE_REPO"
fi

git -C "$ANSIBLE_REPO" fetch --all
git -C "$ANSIBLE_REPO" checkout "$ANSIBLE_REF"

cd "$ANSIBLE_REPO"
./prepare.sh

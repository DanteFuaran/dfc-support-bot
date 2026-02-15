#!/bin/bash

# ═══════════════════════════════════════════════
# DFC SUPPORT BOT — Обёртка установки
# ═══════════════════════════════════════════════

set -e

REPO_URL="https://github.com/DanteFuaran/dfc-support-bot.git"
REPO_BRANCH="main"
INSTALL_DIR="/opt/dfc-support-bot"
TMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TMP_DIR"
    echo -e "\n🧹 Очистка временных файлов произведена"
    echo
}
trap cleanup EXIT

echo -e "📦 Загрузка установщика..."
git clone -b "$REPO_BRANCH" --depth 1 "$REPO_URL" "$TMP_DIR" > /dev/null 2>&1

chmod +x "$TMP_DIR/install.sh"
exec bash "$TMP_DIR/install.sh"

#!/bin/bash

# ═══════════════════════════════════════════════
# DFC SUPPORT BOT — Обёртка установки
# ═══════════════════════════════════════════════

REPO_URL="https://github.com/DanteFuaran/dfc-support-bot.git"
REPO_BRANCH="dev"
TMP_DIR=$(mktemp -d)

echo -e "📦 Загрузка установщика..."
if ! git clone -b "$REPO_BRANCH" --depth 1 "$REPO_URL" "$TMP_DIR" > /dev/null 2>&1; then
    echo -e "❌ Не удалось загрузить репозиторий"
    rm -rf "$TMP_DIR"
    exit 1
fi

chmod +x "$TMP_DIR/install.sh"
exec bash "$TMP_DIR/install.sh" --install "$TMP_DIR"

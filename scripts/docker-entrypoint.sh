#!/bin/sh
set -e

echo "Starting DFC Support Bot..."

# Создаём директории данных и логов если не существуют
mkdir -p /opt/dfc-sb/data
mkdir -p /opt/dfc-sb/logs

exec python run.py

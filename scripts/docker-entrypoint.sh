#!/bin/sh
set -e

echo "Starting DFC Support Bot..."

# Создаём директорию данных если не существует
mkdir -p /opt/dfc-sb/data

exec python run.py

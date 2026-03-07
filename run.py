import sys
import os
# Отключаем создание __pycache__
sys.dont_write_bytecode = True

import asyncio
import logging
from logging.handlers import RotatingFileHandler
from bot.main import main

# Базовая настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

# Ротируемый файловый лог: /opt/dfc-sb/logs/support.log
# Максимум 500 МБ на файл, хранить до 3 архивов
_log_dir = "/opt/dfc-sb/logs"
os.makedirs(_log_dir, exist_ok=True)
_file_handler = RotatingFileHandler(
    filename=os.path.join(_log_dir, "support.log"),
    maxBytes=500 * 1024 * 1024,  # 500 MB
    backupCount=3,
    encoding="utf-8",
)
_file_handler.setFormatter(logging.Formatter(
    fmt="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
))
logging.getLogger().addHandler(_file_handler)

# Отключаем логирование aiogram
logging.getLogger("aiogram").setLevel(logging.WARNING)
logging.getLogger("aiohttp").setLevel(logging.WARNING)

if __name__ == "__main__":
    print()  # Пустая строка перед запуском
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        # Сообщение о ручной остановке уже выводится в main.py
        pass
    print()  # Пустая строка после остановки
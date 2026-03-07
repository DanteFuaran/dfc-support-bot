import asyncio
import logging
import time
from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties

from bot.config import (
    BOT_TOKEN,
    SUPPORT_GROUP_ID,
    INACTIVITY_TIMEOUT,
    INACTIVITY_DAYS,
)
from bot.handlers import commands, user, support
from bot.handlers.helpers import close_topic_system
from bot.utils.storage import storage

# Получаем логгер
logger = logging.getLogger(__name__)


async def auto_close_inactive_topics(bot: Bot):
    """Автозакрытие неактивных тем."""
    while True:
        now = time.time()
        for user_id, topic_id in list(storage.user_topics.items()):
            last = storage.get_last_activity(topic_id)
            if last and now - last > INACTIVITY_TIMEOUT:
                logger.info(f"🕒 Автозакрытие темы #{topic_id} (пользователь {user_id})")
                try:
                    await close_topic_system(bot, topic_id, user_id, closed_by="system", close_type="support")
                except Exception as e:
                    logger.error(f"❌ Ошибка автозакрытия темы #{topic_id}: {e}")
                    # Всё равно очищаем storage, чтобы не застрять на мёртвой теме
                    storage.remove_topic(str(user_id))
                    storage.save()
        await asyncio.sleep(600)


async def main():
    # ======== ЗАПУСК И ИНИЦИАЛИЗАЦИЯ =========
    logger.info("🟢 Бот запущен.")
    logger.info("===========================================================")

    # ======== СТАТИСТИКА ПРИ ЗАПУСКЕ =========
    logger.info(f"📦 Открытых тем: {len(storage.user_topics)}")
    logger.info(f"🕒 Автозакрытие неактивных тем: {INACTIVITY_DAYS} суток")
    logger.info("⚙️ Конфигурация загружена успешно.")
    logger.info("===========================================================")

    # ======== ИНИЦИАЛИЗАЦИЯ БОТА =========
    bot = Bot(
        token=BOT_TOKEN,
        default=DefaultBotProperties(parse_mode="HTML")
    )
    dp = Dispatcher()
    dp["storage"] = storage

    # ======== РЕГИСТРАЦИЯ КОМАНД =========
    from aiogram.types import BotCommand, BotCommandScopeAllGroupChats, BotCommandScopeAllPrivateChats
    
    # Команды для группы поддержки
    group_commands = [
        BotCommand(command="close", description="🛑 Закрыть обращение"),
        BotCommand(command="keyboard", description="⌨️ Отправить меню пользователю"),
        BotCommand(command="resolve", description="✅ Отметить как решённый"),
        BotCommand(command="unresolve", description="❌ Отметить как нерешённый"),
    ]
    
    # Команды для личных чатов
    private_commands = [
        BotCommand(command="start", description="🚀 Начать общение"),
    ]
    
    try:
        await bot.set_my_commands(group_commands, scope=BotCommandScopeAllGroupChats())
        await bot.set_my_commands(private_commands, scope=BotCommandScopeAllPrivateChats())
        logger.info("✅ Команды бота зарегистрированы")
    except Exception as e:
        logger.warning(f"⚠️ Не удалось зарегистрировать команды: {e}")

    # ======== ПРОВЕРКА ГРУППЫ ПОДДЕРЖКИ =========
    try:
        chat = await bot.get_chat(SUPPORT_GROUP_ID)
        if not chat.is_forum:
            logger.warning("⚠️ Указанная группа не является форумом!")
    except Exception as e:
        logger.error(f"❌ Ошибка проверки группы: {e}")

    # ======== НАСТРОЙКА ХЕНДЛЕРОВ =========
    dp.include_router(commands.router)
    dp.include_router(user.router)
    dp.include_router(support.router)

    # ======== ЗАПУСК ФОНОВЫХ ЗАДАЧ =========
    asyncio.create_task(auto_close_inactive_topics(bot))

    # ======== ЗАПУСК БОТА =========
    try:
        await bot.delete_webhook(drop_pending_updates=True)
        await dp.start_polling(bot)
    except Exception as e:
        logger.error(f"❌ Ошибка при работе бота: {e}")
    finally:
        storage.save()
        logger.info("===========================================================")
        logger.info("⚙️ Конфигурация сохранена успешно.")
        logger.info("💾 Данные успешно сохранены.")
        logger.info("🛑 Бот остановлен.")
        logger.info("===========================================================")
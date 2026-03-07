from aiogram import Bot
from bot.config import SUPPORT_GROUP_ID
from bot.utils.storage import storage
from bot.utils.keyboards import get_user_keyboard
import datetime
import asyncio
import logging

logger = logging.getLogger(__name__)

# Словарь для хранения данных пользователей
user_data_cache = {}


async def create_user_topic(bot: Bot, user_id: str, user_name: str, username: str) -> int:
    """Создаёт новую тему для пользователя, карточку и уведомление в общий чат."""
    topic = await bot.create_forum_topic(
        chat_id=SUPPORT_GROUP_ID,
        name=f"ID: {user_id}"
    )
    topic_id = topic.message_thread_id

    # Сохраняем данные пользователя и время создания темы
    creation_time = datetime.datetime.now()
    user_data_cache[topic_id] = {
        'user_id': user_id,
        'user_name': user_name,
        'username': username,
        'creation_time': creation_time
    }
    formatted_time = creation_time.strftime("%Y-%m-%d %H:%M:%S")

    # 🧾 Карточка пользователя внутри темы
    user_card = (
        f"👤 <b>Карточка пользователя</b>\n"
        f"━━━━━━━━━━━━━━━\n"
        f"👤 Имя пользователя: {user_name}\n"
        f"🆔 ID: <code>{user_id}</code>\n"
        f"💬 Профиль: {username}\n\n"
        
        f"🕒 Время: {formatted_time}\n"
        f"━━━━━━━━━━━━━━━"
    )

    try:
        msg = await bot.send_message(
            chat_id=SUPPORT_GROUP_ID,
            message_thread_id=topic_id,
            text=user_card,
            parse_mode="HTML"
        )
        await bot.pin_chat_message(SUPPORT_GROUP_ID, msg.message_id, disable_notification=True)

        # 🔗 Генерация ссылки на тему
        chat_link_id = str(SUPPORT_GROUP_ID).replace("-100", "")
        topic_link = f"https://t.me/c/{chat_link_id}/{topic_id}"

        # 📢 Отправляем уведомление в общий чат группы
        notification_msg = await bot.send_message(
            chat_id=SUPPORT_GROUP_ID,
            text=(
                f"🆕 <b>НОВОЕ ОБРАЩЕНИЕ</b>\n"
                f"━━━━━━━━━━━━━━━\n"
                f"👤 Имя пользователя: {user_name}\n"
                f"🆔 ID: <code>{user_id}</code>\n"
                f"💬 Профиль: {username}\n\n"

                f"📂 Тема: <a href='{topic_link}'>№{topic_id}</a>\n\n"
 
                f"🕒 Время: {formatted_time}\n"
                f"━━━━━━━━━━━━━━━"
            ),
            parse_mode="HTML",
            message_thread_id=None
        )
        
        # Сохраняем ID сообщения уведомления для последующего редактирования
        storage.link_group_message(notification_msg.message_id, topic_id)

    except Exception as e:
        logger.warning(f"Не удалось отправить карточку или уведомление: {e}")

    return topic_id


async def close_topic_system(bot: Bot, topic_id: int, user_id: int, closed_by: str, close_type: str, send_user_notification: bool = True):
    """
    Закрывает тему в группе и уведомляет участников.
    close_type: "success" | "unsuccess" | "support"
    send_user_notification: отправлять ли стандартное уведомление пользователю
    """
    completion_time = datetime.datetime.now()
    formatted_completion_time = completion_time.strftime("%Y-%m-%d %H:%M:%S")
    
    # Получаем данные пользователя из кэша
    user_name = "Неизвестно"
    username = "Неизвестно"
    duration = "Неизвестно"
    
    # Пробуем найти данные в кэше по topic_id
    if topic_id in user_data_cache:
        user_data = user_data_cache[topic_id]
        user_name = user_data['user_name']
        username = user_data['username']
        creation_time = user_data['creation_time']
        
        # Вычисляем длительность обращения
        time_diff = completion_time - creation_time
        total_seconds = int(time_diff.total_seconds())
        hours = total_seconds // 3600
        minutes = (total_seconds % 3600) // 60
        seconds = total_seconds % 60
        
        if hours > 0:
            duration = f"{hours}ч {minutes}м {seconds}с"
        elif minutes > 0:
            duration = f"{minutes}м {seconds}с"
        else:
            duration = f"{seconds}с"
        
        # Удаляем из кэша
        del user_data_cache[topic_id]

    # Определяем статус и заголовок
    if close_type == "success":
        status_emoji = "✅"
        status_text = "Вопрос решён"
        header_emoji = "✅"
        header_text = "ВОПРОС РЕШЁН"
    elif close_type == "unsuccess":
        status_emoji = "❌"
        status_text = "Вопрос не решён"
        header_emoji = "❌"
        header_text = "ВОПРОС НЕ РЕШЁН"
    else:
        status_emoji = "🛑"
        status_text = "Вопрос закрыт поддержкой"
        header_emoji = "🛑"
        header_text = "ВОПРОС ЗАКРЫТ ПОДДЕРЖКОЙ"

    # 🆕 ОТПРАВКА УВЕДОМЛЕНИЯ ПОЛЬЗОВАТЕЛЮ ПРИ ЗАКРЫТИИ ПОДДЕРЖКОЙ
    if closed_by == "support" and send_user_notification:
        try:
            await bot.send_message(
                chat_id=user_id,
                text=f"🛑 <b>Обращение было закрыто поддержкой.</b>\n"
                     f"Если будут новые вопросы - просто напишите мне.",
                parse_mode="HTML",
                reply_markup=get_user_keyboard()
            )
        except Exception as e:
            logger.warning(f"Не удалось отправить уведомление пользователю {user_id}: {e}")

    # 🧩 Закрываем тему форума
    topic_closed = False
    try:
        await bot.close_forum_topic(chat_id=SUPPORT_GROUP_ID, message_thread_id=topic_id)
        topic_closed = True
    except Exception as e:
        error_text = str(e).lower()
        # Если тема уже закрыта или удалена — это не ошибка, продолжаем очистку
        if "thread not found" in error_text or "topic_closed" in error_text or "already closed" in error_text:
            logger.info(f"Тема #{topic_id} уже закрыта/удалена в Telegram, очищаю storage.")
            topic_closed = True
        else:
            logger.warning(f"Ошибка при закрытии темы #{topic_id}: {e}")

    # 🗒 Формируем сообщение для группы (только если закрыл пользователь, а не поддержка)
    if topic_closed and closed_by != "support":
        try:
            await bot.send_message(
                chat_id=SUPPORT_GROUP_ID,
                message_thread_id=topic_id,
                text=f"{status_emoji} {status_text}."
            )
        except Exception as e:
            logger.warning(f"Ошибка при уведомлении группы о закрытии темы #{topic_id}: {e}")

    # 📢 Редактируем сообщение в общем чате (с задержкой чтобы избежать flood control)
    try:
        # Добавляем задержку перед редактированием
        await asyncio.sleep(2)
        
        # 🔗 Генерация ссылки на тему
        chat_link_id = str(SUPPORT_GROUP_ID).replace("-100", "")
        topic_link = f"https://t.me/c/{chat_link_id}/{topic_id}"
        
        # Форматируем username
        formatted_username = username if username != "нет username" and username != "Неизвестно" else "Отсутствует"

        updated_message = (
            f"{header_emoji} <b>{header_text}</b>\n"
            f"━━━━━━━━━━━━━━━\n"
            f"👤 Имя пользователя: {user_name}\n"
            f"🆔 ID: <code>{user_id}</code>\n"
            f"💬 Профиль: {formatted_username}\n\n"

            f"📂 Тема: <a href='{topic_link}'>№{topic_id}</a>\n\n"

            f"📊 Статус: {status_emoji} {status_text}\n"
            f"🕒 Время решения: {duration}\n"
            f"━━━━━━━━━━━━━━━"
        )
        
        # Ищем ID сообщения уведомления для этого topic_id
        notification_msg_id = None
        for group_msg_id, stored_topic_id in storage.g2u.items():
            if stored_topic_id == topic_id:
                notification_msg_id = group_msg_id
                break
        
        if notification_msg_id:
            # Редактируем существующее сообщение
            await bot.edit_message_text(
                chat_id=SUPPORT_GROUP_ID,
                message_id=notification_msg_id,
                text=updated_message,
                parse_mode="HTML"
            )

    except Exception as e:
        logger.error(f"Ошибка обновления сообщения в общем чате: {e}")

    # 🧹 Удаляем тему из хранилища
    try:
        storage.remove_topic(str(user_id))
        storage.save()
    except Exception as e:
        logger.warning(f"Ошибка при удалении темы из хранилища: {e}")
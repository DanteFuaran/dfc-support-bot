from aiogram import Router, types
from bot.utils.senders import send_to_user
from bot.utils.storage import storage
from bot.config import SUPPORT_GROUP_ID
import datetime

router = Router()


@router.message(lambda msg: msg.chat.id == SUPPORT_GROUP_ID and msg.message_thread_id)
async def handle_support_message(message: types.Message, bot):
    """Пересылка ответа поддержки пользователю."""
    # Игнорируем сообщения от самого бота
    if message.from_user.id == bot.id:
        return

    topic_id = message.message_thread_id
    user_id = storage.find_user_by_topic(topic_id)

    if not user_id:
        return

    # Проверка что сообщение не пустое
    has_content = (
        message.text or message.caption or message.photo or
        message.document or message.video or message.audio or
        message.voice or message.sticker or message.animation
    )

    if not has_content:
        await message.reply("⚠️ Пустое сообщение не отправлено пользователю.")
        return

    try:
        sent_msg_id = await send_to_user(bot, int(user_id), message)

        if sent_msg_id:
            storage.update_activity(topic_id)
            storage.save()
            now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            print(f"{now} | INFO     | №{topic_id}: 📤 Поддержка написала сообщение.")
        else:
            now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            print(f"{now} | ERROR    | №{topic_id}: ❌ Не удалось отправить сообщение пользователю")

    except Exception as e:
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"{now} | ERROR    | №{topic_id}: ❌ Ошибка при отправке пользователю: {e}")


@router.edited_message(lambda msg: msg.chat.id == SUPPORT_GROUP_ID and msg.message_thread_id)
async def handle_support_edited_message(message: types.Message, bot):
    """Редактирование сообщений поддержки — синхронно обновляет текст у пользователя."""
    if message.from_user.id == bot.id:
        return

    topic_id = message.message_thread_id
    user_id = storage.find_user_by_topic(topic_id)
    if not user_id:
        return

    user_msg_id = storage.get_user_msg_by_group_msg(message.message_id)
    if not user_msg_id:
        return

    if not message.text and not message.caption:
        return

    try:
        if message.text:
            await bot.edit_message_text(
                chat_id=int(user_id),
                message_id=user_msg_id,
                text=message.text
            )
        elif message.caption and (message.photo or message.document or message.video):
            await bot.edit_message_caption(
                chat_id=int(user_id),
                message_id=user_msg_id,
                caption=message.caption
            )
    except Exception as e:
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"{now} | WARNING  | №{topic_id}: ⚠️ Не удалось обновить сообщение: {e}") {e}")
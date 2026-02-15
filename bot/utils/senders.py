from aiogram import Bot, types
from bot.utils.keyboards import get_user_keyboard
from bot.utils.storage import storage


async def forward_to_group(
    bot: Bot,
    group_id: int,
    message: types.Message,
    thread_id: int,
) -> int | None:
    """
    Пересылка сообщения пользователя в группу поддержки.
    Использует Telegram forward_message — сообщения отображаются
    с реальным именем и аватаром пользователя.
    """
    try:
        sent = await bot.forward_message(
            chat_id=group_id,
            from_chat_id=message.chat.id,
            message_id=message.message_id,
            message_thread_id=thread_id,
        )

        if sent:
            storage.link_user_message(message.message_id, sent.message_id)
            return sent.message_id

        return None

    except Exception as e:
        print(f"⚠️ Ошибка при пересылке в группу: {e}")
        return None


async def send_to_user(
    bot: Bot,
    user_id: int,
    message: types.Message,
    reply_to: int | None = None,
) -> int | None:
    """
    Отправка ответа поддержки пользователю от имени бота.
    """
    try:
        # Определяем reply_to
        reply_to_id = reply_to
        if not reply_to_id and message.reply_to_message:
            replied_group_msg_id = message.reply_to_message.message_id
            reply_to_id = storage.get_user_msg_by_group_msg(replied_group_msg_id)

        kwargs = {
            "chat_id": user_id,
            "reply_markup": get_user_keyboard(),
        }
        if reply_to_id:
            kwargs["reply_to_message_id"] = reply_to_id

        sent = None
        if message.text:
            sent = await bot.send_message(**kwargs, text=message.text)
        elif message.photo:
            sent = await bot.send_photo(**kwargs, photo=message.photo[-1].file_id, caption=message.caption or "")
        elif message.document:
            sent = await bot.send_document(**kwargs, document=message.document.file_id, caption=message.caption or "")
        elif message.video:
            sent = await bot.send_video(**kwargs, video=message.video.file_id, caption=message.caption or "")
        elif message.voice:
            sent = await bot.send_voice(**kwargs, voice=message.voice.file_id, caption=message.caption or "")
        elif message.audio:
            sent = await bot.send_audio(**kwargs, audio=message.audio.file_id, caption=message.caption or "")
        elif message.sticker:
            sent = await bot.send_sticker(chat_id=user_id, sticker=message.sticker.file_id, reply_markup=get_user_keyboard())
        elif message.animation:
            sent = await bot.send_animation(**kwargs, animation=message.animation.file_id, caption=message.caption or "")
        else:
            # Для прочих типов — копируем
            sent = await bot.copy_message(
                chat_id=user_id,
                from_chat_id=message.chat.id,
                message_id=message.message_id,
                reply_to_message_id=reply_to_id,
            )

        if sent:
            storage.link_group_message(message.message_id, sent.message_id)
            return sent.message_id

        return None

    except Exception as e:
        print(f"⚠️ Ошибка при отправке пользователю: {e}")
        return None
        return None
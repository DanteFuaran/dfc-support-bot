from aiogram import Router, types
from aiogram.filters import Command
from bot.utils.keyboards import get_user_keyboard, get_resolution_inline_keyboard
from bot.utils.storage import storage
from bot.handlers.helpers import close_topic_system
from bot.config import SUPPORT_GROUP_ID
import asyncio

router = Router()


@router.message(Command("start"))
async def cmd_start(message: types.Message):
    """Приветственное сообщение пользователю."""
    await message.answer(
        "👋 Здравствуйте!\nОпишите, пожалуйста, вашу проблему.",
        reply_markup=get_user_keyboard(),
    )


@router.message(Command("topics"))
async def cmd_topics(message: types.Message):
    """Показывает список активных тем (только в группе поддержки)."""
    if message.chat.id != SUPPORT_GROUP_ID:
        return

    if not storage.user_topics:
        await message.reply("📭 Активных тем нет.")
        return

    lines = [f"👥 Активные темы: {len(storage.user_topics)}"]
    for uid, tid in storage.user_topics.items():
        lines.append(f"• Пользователь <code>{uid}</code> → тема #{tid}")

    await message.reply("\n".join(lines), parse_mode="HTML")


@router.message(Command("close"))
async def cmd_close(message: types.Message, bot):
    """Закрывает тему по команде поддержки (используется в группе)."""
    if message.chat.id != SUPPORT_GROUP_ID or not message.message_thread_id:
        return

    topic_id = message.message_thread_id
    user_id = storage.find_user_by_topic(topic_id)

    if not user_id:
        await message.reply("❌ Пользователь для этой темы не найден.")
        return

    try:
        await close_topic_system(
            bot,
            topic_id=topic_id,
            user_id=int(user_id),
            closed_by="support",
            close_type="support",
        )
        # Добавляем задержку перед ответом чтобы избежать flood control
        await asyncio.sleep(1)
        # Отправляем сообщение без цитирования (не reply)
        await bot.send_message(
            chat_id=SUPPORT_GROUP_ID,
            message_thread_id=topic_id,
            text="🛑 Вопрос закрыт поддержкой."
        )
    except Exception as e:
        # Добавляем задержку перед ответом об ошибке
        await asyncio.sleep(1)
        await message.reply(f"⚠️ Не удалось закрыть тему: {e}")


@router.message(Command("end"))
async def cmd_end(message: types.Message, bot):
    """Отправляет пользователю инлайн-клавиатуру для опроса о решении вопроса."""
    if message.chat.id != SUPPORT_GROUP_ID or not message.message_thread_id:
        return

    topic_id = message.message_thread_id
    user_id = storage.find_user_by_topic(topic_id)

    if not user_id:
        await message.reply("❌ Пользователь для этой темы не найден.")
        return

    try:
        await bot.send_message(
            chat_id=int(user_id),
            text="<b>Ваш вопрос решён?</b>\nПожалуйста, нажмите на соответствующую кнопку:",
            parse_mode="HTML",
            reply_markup=get_resolution_inline_keyboard(),
        )
        await asyncio.sleep(1)
        await bot.send_message(
            chat_id=SUPPORT_GROUP_ID,
            message_thread_id=topic_id,
            text="✅ Пользователю отправлен опрос о решении вопроса."
        )
    except Exception as e:
        await asyncio.sleep(1)
        await message.reply(f"⚠️ Не удалось отправить опрос пользователю: {e}")


@router.message(lambda msg: msg.text == "/+" and msg.chat.id == SUPPORT_GROUP_ID and msg.message_thread_id)
async def cmd_resolve_success(message: types.Message, bot):
    """Админ-команда для быстрого закрытия с результатом 'Вопрос решён'."""
    topic_id = message.message_thread_id
    user_id = storage.find_user_by_topic(topic_id)

    if not user_id:
        await message.reply("❌ Пользователь для этой темы не найден.")
        return

    try:
        await close_topic_system(
            bot,
            topic_id=topic_id,
            user_id=int(user_id),
            closed_by="support",
            close_type="success",
        )
        await asyncio.sleep(1)
        await bot.send_message(
            chat_id=SUPPORT_GROUP_ID,
            message_thread_id=topic_id,
            text="✅ Вопрос помечен как решённый."
        )
        await bot.send_message(
            chat_id=int(user_id),
            text="✅ Ваш вопрос был отмечен как решённый.\nЕсли будут новые вопросы - просто напишите мне.",
        )
    except Exception as e:
        await asyncio.sleep(1)
        await message.reply(f"⚠️ Не удалось закрыть тему: {e}")


@router.message(lambda msg: msg.text == "/-" and msg.chat.id == SUPPORT_GROUP_ID and msg.message_thread_id)
async def cmd_resolve_unsuccess(message: types.Message, bot):
    """Админ-команда для быстрого закрытия с результатом 'Вопрос не решён'."""
    topic_id = message.message_thread_id
    user_id = storage.find_user_by_topic(topic_id)

    if not user_id:
        await message.reply("❌ Пользователь для этой темы не найден.")
        return

    try:
        await close_topic_system(
            bot,
            topic_id=topic_id,
            user_id=int(user_id),
            closed_by="support",
            close_type="unsuccess",
        )
        await asyncio.sleep(1)
        await bot.send_message(
            chat_id=SUPPORT_GROUP_ID,
            message_thread_id=topic_id,
            text="❌ Вопрос помечен как нерешённый."
        )
        await bot.send_message(
            chat_id=int(user_id),
            text="❌ Ваш вопрос был отмечен как нерешённый.\nМне искренне жаль, что я не смог вам помочь.\nЕсли будут новые вопросы - просто напишите мне.",
        )
    except Exception as e:
        await asyncio.sleep(1)
        await message.reply(f"⚠️ Не удалось закрыть тему: {e}")
from aiogram.types import ReplyKeyboardMarkup, KeyboardButton, InlineKeyboardMarkup, InlineKeyboardButton, ReplyKeyboardRemove


def get_user_keyboard() -> ReplyKeyboardRemove:
    """
    Убираем постоянную клавиатуру у пользователя.
    Теперь опрос происходит через инлайн-кнопки после команды /end.
    """
    return ReplyKeyboardRemove()


def get_resolution_inline_keyboard() -> InlineKeyboardMarkup:
    """
    Инлайн-клавиатура для опроса пользователя о результате решения вопроса.
    Появляется после команды администратора /end.
    """
    buttons = [
        [
            InlineKeyboardButton(text="✅ Вопрос решён", callback_data="resolve_success"),
            InlineKeyboardButton(text="❌ Вопрос не решён", callback_data="resolve_unsuccess"),
        ]
    ]
    
    return InlineKeyboardMarkup(inline_keyboard=buttons)
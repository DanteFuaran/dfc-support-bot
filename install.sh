#!/bin/bash

# ═══════════════════════════════════════════════
# DFC SUPPORT BOT — Установщик и панель управления
# Версия: 0.1.7
# ═══════════════════════════════════════════════

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
DARKGRAY='\033[1;30m'
NC='\033[0m'

# Пути
PROJECT_DIR="/opt/dfc-support-bot"
REPO_URL="https://github.com/DanteFuaran/dfc-support-bot.git"
REPO_BRANCH="main"
GITHUB_RAW_URL="https://raw.githubusercontent.com/DanteFuaran/dfc-support-bot"
CONTAINER_NAME="dfc-sb"
IMAGE_NAME="dfc-sb:local"

# Определяем ветку из .update если есть
SCRIPT_CWD="$(cd "$(dirname "$0")" && pwd)"
for _uf in "$SCRIPT_CWD/assets/update/.update" "$PROJECT_DIR/assets/update/.update"; do
    if [ -f "$_uf" ]; then
        _br=$(grep '^branch:' "$_uf" | cut -d: -f2 | tr -d ' \n')
        [ -n "$_br" ] && REPO_BRANCH="$_br"
        break
    fi
done

# Источник файлов (при установке — tmp-папка)
SOURCE_DIR=""

# ═══════════════════════════════════════════════
# ВОССТАНОВЛЕНИЕ ТЕРМИНАЛА
# ═══════════════════════════════════════════════
cleanup_terminal() {
    stty sane 2>/dev/null || true
    tput cnorm 2>/dev/null || true
}

handle_interrupt() {
    cleanup_terminal
    echo
    echo -e "${RED}⚠️  Скрипт был остановлен пользователем${NC}"
    echo
    exit 130
}

trap cleanup_terminal EXIT
trap handle_interrupt INT

# ═══════════════════════════════════════════════
# ВЕРСИЯ
# ═══════════════════════════════════════════════
get_local_version() {
    for _uf in "$PROJECT_DIR/assets/update/.update" "$SCRIPT_CWD/assets/update/.update"; do
        if [ -f "$_uf" ]; then
            local ver
            ver=$(grep '^version:' "$_uf" 2>/dev/null | cut -d: -f2 | tr -d ' \n')
            [ -n "$ver" ] && echo "$ver" && return
        fi
    done
    echo "0.1.8"
}

get_remote_version() {
    local latest_sha
    latest_sha=$(curl -sL --max-time 5 "https://api.github.com/repos/DanteFuaran/dfc-support-bot/commits/$REPO_BRANCH" 2>/dev/null | grep -m 1 '"sha"' | cut -d'"' -f4)

    if [ -n "$latest_sha" ]; then
        curl -sL --max-time 5 "https://raw.githubusercontent.com/DanteFuaran/dfc-support-bot/$latest_sha/assets/update/.update" 2>/dev/null | grep '^version:' | cut -d: -f2 | tr -d ' \n'
    else
        curl -sL --max-time 5 "https://raw.githubusercontent.com/DanteFuaran/dfc-support-bot/$REPO_BRANCH/assets/update/.update?t=$(date +%s)" 2>/dev/null | grep '^version:' | cut -d: -f2 | tr -d ' \n'
    fi
}

check_for_updates() {
    local remote_version
    remote_version=$(get_remote_version)

    if [ -z "$remote_version" ]; then
        return 1
    fi

    local local_version
    local_version=$(get_local_version)

    if [ "$remote_version" != "$local_version" ]; then
        local IFS=.
        local i remote_parts=($remote_version) local_parts=($local_version)
        for ((i=0; i<${#remote_parts[@]}; i++)); do
            local r=${remote_parts[i]:-0}
            local l=${local_parts[i]:-0}
            if (( r > l )); then
                echo "$remote_version"
                return 0
            elif (( r < l )); then
                return 1
            fi
        done
        return 1
    fi

    return 1
}

# ═══════════════════════════════════════════════
# ИНТЕРАКТИВНОЕ МЕНЮ
# ═══════════════════════════════════════════════
show_arrow_menu() {
    set +e
    local title="$1"
    shift
    local options=("$@")
    local num_options=${#options[@]}
    local selected=0

    local original_stty
    original_stty=$(stty -g 2>/dev/null)

    tput civis 2>/dev/null || true
    stty -icanon -echo min 1 time 0 2>/dev/null || true

    _restore_term() {
        stty "$original_stty" 2>/dev/null || stty sane 2>/dev/null || true
        tput cnorm 2>/dev/null || true
    }

    trap "_restore_term" RETURN

    while true; do
        clear
        echo -e "${BLUE}══════════════════════════════════════${NC}"
        echo -e "${GREEN}   $title${NC}"
        echo -e "${BLUE}══════════════════════════════════════${NC}"
        echo

        for i in "${!options[@]}"; do
            if [[ "${options[$i]}" =~ ^[─━═[:space:]]*$ ]]; then
                echo -e "${options[$i]}"
            elif [ $i -eq $selected ]; then
                echo -e "${BLUE}▶${NC} ${YELLOW}${options[$i]}${NC}"
            else
                echo -e "  ${options[$i]}"
            fi
        done

        echo
        echo -e "${BLUE}══════════════════════════════════════${NC}"
        echo -e "${DARKGRAY}Используйте ↑↓ для навигации, Enter для выбора${NC}"

        local key
        read -rsn1 key 2>/dev/null || key=""

        if [[ "$key" == $'\e' ]]; then
            local seq1="" seq2=""
            read -rsn1 -t 0.1 seq1 2>/dev/null || seq1=""
            if [[ "$seq1" == '[' ]]; then
                read -rsn1 -t 0.1 seq2 2>/dev/null || seq2=""
                case "$seq2" in
                    'A')
                        ((selected--))
                        if [ $selected -lt 0 ]; then selected=$((num_options - 1)); fi
                        while [[ "${options[$selected]}" =~ ^[─═[:space:]]*$ ]]; do
                            ((selected--))
                            if [ $selected -lt 0 ]; then selected=$((num_options - 1)); fi
                        done
                        ;;
                    'B')
                        ((selected++))
                        if [ $selected -ge $num_options ]; then selected=0; fi
                        while [[ "${options[$selected]}" =~ ^[─═[:space:]]*$ ]]; do
                            ((selected++))
                            if [ $selected -ge $num_options ]; then selected=0; fi
                        done
                        ;;
                esac
            fi
        else
            local key_code
            if [ -n "$key" ]; then
                key_code=$(printf '%d' "'$key" 2>/dev/null || echo 0)
            else
                key_code=13
            fi

            if [ "$key_code" -eq 10 ] || [ "$key_code" -eq 13 ]; then
                _restore_term
                return $selected
            fi
        fi
    done
}

# ═══════════════════════════════════════════════
# УТИЛИТЫ
# ═══════════════════════════════════════════════
reading() {
    local prompt="$1"
    local var_name="$2"
    local input
    echo
    local ps=$'\001\033[34m\002➜\001\033[0m\002  \001\033[33m\002'"$prompt"$'\001\033[0m\002 '
    read -e -p "$ps" input
    eval "$var_name='$input'"
}

confirm_action() {
    echo
    echo -e "${YELLOW}⚠️  Нажмите Enter для подтверждения, или Esc для отмены.${NC}"
    local key
    while true; do
        read -s -n 1 key
        if [[ "$key" == $'\x1b' ]]; then return 1; fi
        if [[ "$key" == "" ]]; then break; fi
    done
    echo -e "${RED}⚠️  Вы уверены? Это действие нельзя отменить.${NC}"
    echo -e "${YELLOW}⚠️  Нажмите Enter для подтверждения, или Esc для отмены.${NC}"
    while true; do
        read -s -n 1 key
        if [[ "$key" == $'\x1b' ]]; then return 1; fi
        if [[ "$key" == "" ]]; then return 0; fi
    done
}

show_spinner() {
    local pid=$!
    local delay=0.08
    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0 msg="$1"
    while kill -0 $pid 2>/dev/null; do
        printf "\r${GREEN}%s${NC}  %s" "${spin[$i]}" "$msg"
        i=$(( (i+1) % 10 ))
        sleep $delay
    done
    printf "\r${GREEN}✅${NC} %s\n" "$msg"
}

is_installed() {
    [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/docker-compose.yml" ]
}

is_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"
}

# ═══════════════════════════════════════════════
# УСТАНОВКА
# ═══════════════════════════════════════════════
install_bot() {
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}   🚀 УСТАНОВКА DFC SUPPORT BOT${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo

    # Проверка root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Запустите с правами root${NC}"
        exit 1
    fi

    # Проверка Docker
    if ! command -v docker &>/dev/null; then
        echo -e "${YELLOW}📦 Docker не установлен. Устанавливаю...${NC}"
        curl -fsSL https://get.docker.com | sh >/dev/null 2>&1 &
        show_spinner "Установка Docker"
    fi
    echo -e "${GREEN}✅${NC} Docker установлен"

    # Создание сети
    docker network create remnawave-network 2>/dev/null || true

    # Проверяем существует ли уже
    if [ -d "$PROJECT_DIR" ]; then
        echo -e "${YELLOW}⚠️  Папка $PROJECT_DIR уже существует.${NC}"
        echo -ne "${RED}Перезаписать? (y/N): ${NC}"
        read confirm
        case "$confirm" in
            [yY][eE][sS]|[yY])
                cd /opt 2>/dev/null || true
                cd "$PROJECT_DIR" 2>/dev/null && docker compose down >/dev/null 2>&1 || true
                cd /opt
                docker rmi "$IMAGE_NAME" -f >/dev/null 2>&1 || true
                rm -rf "$PROJECT_DIR"
                ;;
            *)
                echo -e "${RED}❌ Установка отменена.${NC}"
                return
                ;;
        esac
    fi

    # Клонируем во временную папку если SOURCE_DIR ещё не задан
    if [ -z "$SOURCE_DIR" ] || [ ! -d "$SOURCE_DIR/bot" ]; then
        SOURCE_DIR=$(mktemp -d)
        git clone -b "$REPO_BRANCH" --depth 1 "$REPO_URL" "$SOURCE_DIR" >/dev/null 2>&1 &
        show_spinner "Клонирование репозитория"
    else
        echo -e "${GREEN}✅${NC} Используем загруженный репозиторий"
    fi

    # Настройка .env
    echo
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}   ⚙️ НАСТРОЙКИ .ENV${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"

    reading "Введите токен Telegram бота:" BOT_TOKEN
    reading "Введите ID группы поддержки (-100...):" SUPPORT_GROUP_ID
    reading "Дни до автозакрытия тикетов [5]:" INACTIVITY_DAYS
    INACTIVITY_DAYS=${INACTIVITY_DAYS:-5}

    # Создаём продакшн папку с минимальной структурой
    mkdir -p "$PROJECT_DIR"/{data,logs,assets/update}

    # Копируем только нужные файлы
    cp -f "$SOURCE_DIR/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml"
    cp -rf "$SOURCE_DIR/assets/"* "$PROJECT_DIR/assets/" 2>/dev/null || true
    cp -f "$SOURCE_DIR/install.sh" "$PROJECT_DIR/assets/update/install.sh"
    chmod +x "$PROJECT_DIR/assets/update/install.sh"

    # Генерируем .env
    cat > "$PROJECT_DIR/.env" << EOF
BOT_TOKEN=$BOT_TOKEN
SUPPORT_GROUP_ID=$SUPPORT_GROUP_ID
INACTIVITY_DAYS=$INACTIVITY_DAYS
EOF
    echo -e "\n${GREEN}✅${NC} Конфигурация сохранена"

    # Сборка Docker образа из tmp
    echo
    cd "$SOURCE_DIR"
    docker build -t "$IMAGE_NAME" . >/dev/null 2>&1 &
    show_spinner "Сборка Docker образа"

    # Запуск
    cd "$PROJECT_DIR"
    docker compose up -d >/dev/null 2>&1 &
    show_spinner "Запуск контейнера"

    sleep 2

    # Очистка tmp
    if [ -n "$SOURCE_DIR" ] && [[ "$SOURCE_DIR" == /tmp/* ]]; then
        rm -rf "$SOURCE_DIR"
    fi

    # Создание глобальной команды
    create_cli_command

    echo
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}   🎉 УСТАНОВКА ЗАВЕРШЕНА!${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"

    if is_running; then
        echo -e "${GREEN}✅${NC} Бот успешно запущен"
    else
        echo -e "${RED}❌${NC} Не удалось запустить бота"
        echo -e "${YELLOW}Проверьте логи: docker logs $CONTAINER_NAME${NC}"
    fi

    echo -e "${WHITE}✅ Команда управления:${NC} ${YELLOW}dfc-sb${NC}"
    echo
}

# ═══════════════════════════════════════════════
# CLI КОМАНДА
# ═══════════════════════════════════════════════
create_cli_command() {
    cat > /usr/local/bin/dfc-sb << 'CLIPATH'
#!/bin/bash
if [ -f "/opt/dfc-support-bot/assets/update/install.sh" ]; then
    exec /opt/dfc-support-bot/assets/update/install.sh
else
    echo "❌ DFC Support Bot не установлен."
    exit 1
fi
CLIPATH
    chmod +x /usr/local/bin/dfc-sb
}

# ═══════════════════════════════════════════════
# ОБНОВЛЕНИЕ
# ═══════════════════════════════════════════════
update_bot() {
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}   🔄 ОБНОВЛЕНИЕ DFC SUPPORT BOT${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo

    local old_version=$(get_local_version)

    # Клонируем во временную папку
    local TEMP_DIR
    TEMP_DIR=$(mktemp -d)

    git clone -b "$REPO_BRANCH" --depth 1 "$REPO_URL" "$TEMP_DIR" >/dev/null 2>&1 &
    show_spinner "Загрузка обновлений"

    # Показываем версии
    local new_version=""
    if [ -f "$TEMP_DIR/assets/update/.update" ]; then
        new_version=$(grep '^version:' "$TEMP_DIR/assets/update/.update" | cut -d: -f2 | tr -d ' \n')
    fi

    echo -e "${WHITE}Установленная версия:${NC} v$old_version"
    if [ -n "$new_version" ]; then
        echo -e "${WHITE}Доступная версия:${NC}     v$new_version"
    fi
    echo

    if [ "$old_version" = "$new_version" ]; then
        echo -e "${GREEN}✅ У вас уже установлена последняя версия${NC}"
        echo
        read -p "Нажмите Enter для возврата..."
        rm -rf "$TEMP_DIR"
        return
    fi

    # Останавливаем контейнер
    cd "$PROJECT_DIR"
    docker compose down >/dev/null 2>&1 || true
    docker rmi "$IMAGE_NAME" -f >/dev/null 2>&1 || true

    # Сборка нового образа из tmp
    cd "$TEMP_DIR"
    docker build -t "$IMAGE_NAME" . >/dev/null 2>&1 &
    show_spinner "Сборка нового образа"

    # Обновляем файлы в продакшн (только docker-compose, assets, install.sh)
    cp -f "$TEMP_DIR/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml"
    cp -rf "$TEMP_DIR/assets/"* "$PROJECT_DIR/assets/" 2>/dev/null || true
    cp -f "$TEMP_DIR/install.sh" "$PROJECT_DIR/assets/update/install.sh"
    chmod +x "$PROJECT_DIR/assets/update/install.sh"

    # Запуск
    cd "$PROJECT_DIR"
    docker compose up -d >/dev/null 2>&1 &
    show_spinner "Запуск обновлённого бота"

    # Обновляем CLI
    create_cli_command

    # Очистка
    rm -rf "$TEMP_DIR"
    rm -f /tmp/dfc_sb_update_available /tmp/dfc_sb_last_update_check 2>/dev/null

    sleep 2

    echo
    if is_running; then
        local final_version=$(get_local_version)
        echo -e "${GREEN}✅ Обновление до v${final_version} завершено!${NC}"
    else
        echo -e "${RED}❌ Бот не запустился после обновления${NC}"
        echo -e "${YELLOW}Проверьте логи: docker logs $CONTAINER_NAME${NC}"
    fi
    echo
    read -p "Нажмите Enter для возврата в меню..."
}

# ═══════════════════════════════════════════════
# ПАНЕЛЬ УПРАВЛЕНИЯ
# ═══════════════════════════════════════════════
show_full_menu() {
    local LOCAL_VERSION=$(get_local_version)
    [ -z "$LOCAL_VERSION" ] && LOCAL_VERSION="0.1.7"

    # Создаём команду если нет
    if [ ! -f "/usr/local/bin/dfc-sb" ]; then
        create_cli_command
    fi

    while true; do
        LOCAL_VERSION=$(get_local_version)

        # Проверяем наличие обновлений
        local update_notice=""
        if [ -f /tmp/dfc_sb_update_available ]; then
            local new_version
            new_version=$(cat /tmp/dfc_sb_update_available)
            update_notice=" ${YELLOW}(Доступно: v$new_version)${NC}"
        fi

        show_arrow_menu "🚀 DFC SUPPORT BOT v${LOCAL_VERSION}" \
            "🔄  Обновить$update_notice" \
            "ℹ️   Просмотр логов" \
            "📊  Логи в реальном времени" \
            "──────────────────────────────────────" \
            "🔃  Перезагрузить бота" \
            "⬆️   Включить бота" \
            "⬇️   Выключить бота" \
            "──────────────────────────────────────" \
            "⚙️   Изменить настройки" \
            "🔄  Переустановить" \
            "🗑️   Удалить бота" \
            "──────────────────────────────────────" \
            "❌  Выход"
        local choice=$?

        case $choice in
            0) update_bot ;;
            1) # Логи
                clear
                echo -e "${BLUE}══════════════════════════════════════${NC}"
                echo -e "${GREEN}   📋 ПОСЛЕДНИЕ ЛОГИ${NC}"
                echo -e "${BLUE}══════════════════════════════════════${NC}"
                echo
                docker logs --tail 50 "$CONTAINER_NAME" 2>&1
                echo
                read -p "Нажмите Enter для возврата..."
                ;;
            2) # Логи реального времени
                clear
                echo -e "${YELLOW}Для выхода нажмите Ctrl+C${NC}"
                echo
                docker logs -f --tail 20 "$CONTAINER_NAME" 2>&1 || true
                ;;
            3) ;; # разделитель
            4) # Перезагрузить
                cd "$PROJECT_DIR"
                docker compose restart >/dev/null 2>&1
                echo -e "${GREEN}✅ Бот перезагружен${NC}"
                sleep 2
                ;;
            5) # Включить
                cd "$PROJECT_DIR"
                docker compose up -d >/dev/null 2>&1
                echo -e "${GREEN}✅ Бот запущен${NC}"
                sleep 2
                ;;
            6) # Выключить
                cd "$PROJECT_DIR"
                docker compose down >/dev/null 2>&1
                echo -e "${RED}⬇️  Бот остановлен${NC}"
                sleep 2
                ;;
            7) ;; # разделитель
            8) # Изменить настройки
                edit_settings
                ;;
            9) # Переустановить
                clear
                echo -e "${RED}⚠️  ПЕРЕУСТАНОВКА БОТА${NC}"
                echo -e "${YELLOW}Все файлы будут удалены и установлены заново.${NC}"
                echo -e "${YELLOW}Данные (data/) будут сохранены.${NC}"
                if confirm_action; then
                    # Сохраняем данные и .env
                    local temp_backup=$(mktemp -d)
                    cp -rf "$PROJECT_DIR/data" "$temp_backup/" 2>/dev/null || true
                    cp -f "$PROJECT_DIR/.env" "$temp_backup/.env" 2>/dev/null || true

                    delete_bot_silent
                    install_bot

                    # Восстанавливаем данные
                    if [ -d "$temp_backup/data" ]; then
                        cp -rf "$temp_backup/data/"* "$PROJECT_DIR/data/" 2>/dev/null || true
                    fi
                    if [ -f "$temp_backup/.env" ]; then
                        cp -f "$temp_backup/.env" "$PROJECT_DIR/.env"
                    fi
                    rm -rf "$temp_backup"
                    cd "$PROJECT_DIR"
                    docker compose restart >/dev/null 2>&1
                fi
                ;;
            10) # Удалить
                clear
                echo -e "${RED}⚠️  ПОЛНОЕ УДАЛЕНИЕ БОТА${NC}"
                echo -e "${YELLOW}Все файлы, данные и Docker образы будут удалены.${NC}"
                if confirm_action; then
                    delete_bot_full
                    exit 0
                fi
                ;;
            11) ;; # разделитель
            12) # Выход
                clear
                exit 0
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════
# РЕДАКТИРОВАНИЕ НАСТРОЕК
# ═══════════════════════════════════════════════
edit_settings() {
    local ENV_FILE="$PROJECT_DIR/.env"

    while true; do
        local current_token=$(grep '^BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)
        local current_group=$(grep '^SUPPORT_GROUP_ID=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)
        local current_days=$(grep '^INACTIVITY_DAYS=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)

        # Маскируем токен
        local masked_token
        if [ ${#current_token} -gt 10 ]; then
            masked_token="${current_token:0:5}...${current_token: -5}"
        else
            masked_token="$current_token"
        fi

        show_arrow_menu "⚙️  НАСТРОЙКИ" \
            "🔑  Токен бота: $masked_token" \
            "🆔  ID группы: $current_group" \
            "⏱️   Автозакрытие: $current_days дней" \
            "──────────────────────────────────────" \
            "↩️   Назад"
        local choice=$?

        case $choice in
            0) # Токен
                reading "Новый токен бота:" new_value
                if [ -n "$new_value" ]; then
                    sed -i "s|^BOT_TOKEN=.*|BOT_TOKEN=$new_value|" "$ENV_FILE"
                    echo -e "${GREEN}✅ Токен обновлён. Перезапустите бота.${NC}"
                    sleep 2
                fi
                ;;
            1) # ID группы
                reading "Новый ID группы:" new_value
                if [ -n "$new_value" ]; then
                    sed -i "s|^SUPPORT_GROUP_ID=.*|SUPPORT_GROUP_ID=$new_value|" "$ENV_FILE"
                    echo -e "${GREEN}✅ ID группы обновлён. Перезапустите бота.${NC}"
                    sleep 2
                fi
                ;;
            2) # Автозакрытие
                reading "Количество дней до автозакрытия:" new_value
                if [ -n "$new_value" ]; then
                    sed -i "s|^INACTIVITY_DAYS=.*|INACTIVITY_DAYS=$new_value|" "$ENV_FILE"
                    echo -e "${GREEN}✅ Автозакрытие обновлено. Перезапустите бота.${NC}"
                    sleep 2
                fi
                ;;
            3) ;; # разделитель
            4) return ;; # Назад
        esac
    done
}

# ═══════════════════════════════════════════════
# УДАЛЕНИЕ
# ═══════════════════════════════════════════════
delete_bot_silent() {
    cd /opt 2>/dev/null || true
    if [ -d "$PROJECT_DIR" ]; then
        cd "$PROJECT_DIR" 2>/dev/null && docker compose down >/dev/null 2>&1 || true
        cd /opt
    fi
    docker rmi "$IMAGE_NAME" -f >/dev/null 2>&1 || true
    rm -rf "$PROJECT_DIR"
    rm -f /usr/local/bin/dfc-sb
}

delete_bot_full() {
    echo
    cd /opt 2>/dev/null || true
    if [ -d "$PROJECT_DIR" ]; then
        cd "$PROJECT_DIR" 2>/dev/null && docker compose down >/dev/null 2>&1 || true
        cd /opt
    fi
    docker rmi "$IMAGE_NAME" -f >/dev/null 2>&1 || true
    rm -rf "$PROJECT_DIR"
    rm -f /usr/local/bin/dfc-sb
    rm -f /tmp/dfc_sb_update_available /tmp/dfc_sb_last_update_check 2>/dev/null
    echo -e "${GREEN}✅ Бот полностью удалён${NC}"
    echo
}

# ═══════════════════════════════════════════════
# МЕНЮ УСТАНОВКИ (для нового пользователя)
# ═══════════════════════════════════════════════
show_install_menu() {
    local LOCAL_VERSION=$(get_local_version)
    [ -z "$LOCAL_VERSION" ] && LOCAL_VERSION="0.1.7"

    show_arrow_menu "🚀 DFC SUPPORT BOT v${LOCAL_VERSION}" \
        "📦  Установить" \
        "──────────────────────────────────────" \
        "❌  Выход"
    local choice=$?

    case $choice in
        0) install_bot ;;
        1) ;; # разделитель
        2) clear; exit 0 ;;
    esac
}

# ═══════════════════════════════════════════════
# ТОЧКА ВХОДА
# ═══════════════════════════════════════════════

# Обработка аргумента --install (вызов из install-wrapper.sh)
if [ "$1" = "--install" ] && [ -n "$2" ]; then
    SOURCE_DIR="$2"
fi

# Проверка обновлений только если бот установлен
if is_installed; then
    UPDATE_CHECK_FILE="/tmp/dfc_sb_last_update_check"
    current_time=$(date +%s)
    last_check=0

    if [ -f "$UPDATE_CHECK_FILE" ]; then
        last_check=$(cat "$UPDATE_CHECK_FILE" 2>/dev/null || echo 0)
    fi

    time_diff=$((current_time - last_check))
    if [ $time_diff -gt 3600 ] || [ ! -f /tmp/dfc_sb_update_available ]; then
        new_version=$(check_for_updates)
        if [ $? -eq 0 ] && [ -n "$new_version" ]; then
            echo "$new_version" > /tmp/dfc_sb_update_available
        else
            rm -f /tmp/dfc_sb_update_available 2>/dev/null
        fi
        echo "$current_time" > "$UPDATE_CHECK_FILE"
    fi
    show_full_menu
else
    show_install_menu
fi

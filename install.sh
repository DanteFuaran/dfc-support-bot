#!/bin/bash

# ═══════════════════════════════════════════════
# DFC SUPPORT BOT — Установщик и панель управления
# Версия: 0.2.8
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
SCRIPT_VERSION="0.2.8"  # версия этого скрипта (хардкод — надёжен при bash <(curl ...))

# Единый источник версии и ветки: $PROJECT_DIR/version или $SCRIPT_CWD/version
# Формат файла: version: x.x.x / branch: main
SCRIPT_CWD="$(cd "$(dirname "$0")" && pwd)"
for _uf in "$PROJECT_DIR/version" "$SCRIPT_CWD/version"; do
    if [ -f "$_uf" ]; then
        _br=$(grep '^branch:' "$_uf" | cut -d: -f2 | tr -d ' \n')
        [ -n "$_br" ] && REPO_BRANCH="$_br"
        break
    fi
done

# Статус проверки обновлений (заполняется асинхронно)
UPDATE_AVAILABLE=0
AVAILABLE_VERSION=""
CHECK_UPDATE_PID=""
UPDATE_STATUS_FILE=""

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
    # Приоритет: production ($PROJECT_DIR/version), затем текущая папка ($SCRIPT_CWD/version)
    for _uf in "$PROJECT_DIR/version" "$SCRIPT_CWD/version"; do
        if [ -f "$_uf" ]; then
            local ver
            ver=$(grep '^version:' "$_uf" 2>/dev/null | cut -d: -f2 | tr -d ' \n')
            [ -n "$ver" ] && echo "$ver" && return
        fi
    done
    echo ""
}

parse_version_from_content() {
    local content="$1"
    local _v
    _v=$(echo "$content" | grep '^version:' 2>/dev/null | cut -d: -f2 | tr -d ' \n')
    [ -n "$_v" ] && echo "$_v" && return
    # plain format — первая непустая строка вида x.y.z
    echo "$content" | grep -v '^#\|^[[:space:]]*$' 2>/dev/null | head -1 | tr -d ' \n'
}

check_updates_available() {
    UPDATE_STATUS_FILE=$(mktemp)
    echo "0|" > "$UPDATE_STATUS_FILE"

    {
        _cu_lv=$(grep '^version:' "$PROJECT_DIR/version" 2>/dev/null | cut -d: -f2 | tr -d ' \n')
        _cu_rc=$(curl -sL --max-time 10 "${GITHUB_RAW_URL}/main/version" 2>/dev/null)
        _cu_rv=$(parse_version_from_content "$_cu_rc")

        if [ -n "$_cu_rv" ] && [ -n "$_cu_lv" ]; then
            _cu_ln=$(echo "$_cu_lv" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
            _cu_rn=$(echo "$_cu_rv" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
            if [ "$_cu_ln" -lt "$_cu_rn" ] 2>/dev/null; then
                echo "1|$_cu_rv" > "$UPDATE_STATUS_FILE"
            else
                echo "0|$_cu_rv" > "$UPDATE_STATUS_FILE"
            fi
        elif [ -n "$_cu_rv" ]; then
            echo "0|$_cu_rv" > "$UPDATE_STATUS_FILE"
        fi
    } &
    CHECK_UPDATE_PID=$!
}

wait_for_update_check() {
    if [ -n "$CHECK_UPDATE_PID" ]; then
        wait "$CHECK_UPDATE_PID" 2>/dev/null || true
        CHECK_UPDATE_PID=""
    fi
    if [ -n "$UPDATE_STATUS_FILE" ] && [ -f "$UPDATE_STATUS_FILE" ]; then
        local update_info
        update_info=$(cat "$UPDATE_STATUS_FILE" 2>/dev/null || echo "0|")
        UPDATE_AVAILABLE=$(echo "$update_info" | cut -d'|' -f1)
        AVAILABLE_VERSION=$(echo "$update_info" | cut -d'|' -f2)
        rm -f "$UPDATE_STATUS_FILE" 2>/dev/null || true
        UPDATE_STATUS_FILE=""
    fi
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
    mkdir -p "$PROJECT_DIR"/{data,logs}

    # Копируем только нужные файлы
    cp -f "$SOURCE_DIR/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml"
    cp -f "$SOURCE_DIR/version" "$PROJECT_DIR/version" 2>/dev/null || true
    cp -f "$SOURCE_DIR/install.sh" "$PROJECT_DIR/install.sh"
    chmod +x "$PROJECT_DIR/install.sh"

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
if [ -f "/opt/dfc-support-bot/install.sh" ]; then
    exec /opt/dfc-support-bot/install.sh
else
    echo "❌ DFC Support Bot не установлен."
    exit 1
fi
CLIPATH
    chmod +x /usr/local/bin/dfc-sb
    ln -sf /usr/local/bin/dfc-sb /usr/local/bin/dfc-support-bot
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
    if [ -f "$TEMP_DIR/version" ]; then
        new_version=$(grep '^version:' "$TEMP_DIR/version" | cut -d: -f2 | tr -d ' \n')
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

    # Обновляем файлы в продакшн (docker-compose, version, install.sh)
    cp -f "$TEMP_DIR/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml"
    cp -f "$TEMP_DIR/version" "$PROJECT_DIR/version" 2>/dev/null || true
    cp -f "$TEMP_DIR/install.sh" "$PROJECT_DIR/install.sh"
    chmod +x "$PROJECT_DIR/install.sh"

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
    local LOCAL_VERSION
    LOCAL_VERSION=$(get_local_version)
    [ -z "$LOCAL_VERSION" ] && LOCAL_VERSION="0.2.8"

    # Создаём команду если нет
    if [ ! -f "/usr/local/bin/dfc-sb" ]; then
        create_cli_command
    fi

    # Ждём результата фоновой проверки обновлений
    wait_for_update_check

    while true; do
        LOCAL_VERSION=$(get_local_version)
        [ -z "$LOCAL_VERSION" ] && LOCAL_VERSION="0.2.8"

        # Формируем метку кнопки обновления
        local update_label="🔄  Обновить"
        if [ "$UPDATE_AVAILABLE" = "1" ] && [ -n "$AVAILABLE_VERSION" ]; then
            update_label="🔄  Обновить ${YELLOW}( Доступно обновление — версия $AVAILABLE_VERSION ! )${NC}"
        fi

        local menu_title="     🚀 DFC SUPPORT BOT v${LOCAL_VERSION}\n${DARKGRAY}Проект развивается благодаря вашей поддержке\n        https://github.com/DanteFuaran${NC}"
        
        show_arrow_menu "$menu_title" \
            "$update_label" \
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
    rm -f /usr/local/bin/dfc-support-bot
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
    rm -f /usr/local/bin/dfc-support-bot
    rm -f /tmp/dfc_sb_update_available /tmp/dfc_sb_last_update_check 2>/dev/null
    echo -e "${GREEN}✅ Бот полностью удалён${NC}"
    echo
}

# ═══════════════════════════════════════════════
# МЕНЮ УСТАНОВКИ (для нового пользователя)
# ═══════════════════════════════════════════════
show_install_menu() {
    # Версия этого скрипта — всегда известна, надёжно работает даже при bash <(curl ...)
    local DISPLAY_VERSION="$SCRIPT_VERSION"

    # Ждём фоновую проверку — если в репо есть более новая версия, покажем её
    wait_for_update_check
    if [ -n "$AVAILABLE_VERSION" ]; then
        _im_sn=$(echo "$SCRIPT_VERSION" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
        _im_an=$(echo "$AVAILABLE_VERSION" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
        [ "$_im_an" -gt "$_im_sn" ] 2>/dev/null && DISPLAY_VERSION="$AVAILABLE_VERSION"
    fi

    local menu_title="     🚀 DFC SUPPORT BOT v${DISPLAY_VERSION}\n${DARKGRAY}Проект развивается благодаря вашей поддержке\n        https://github.com/DanteFuaran${NC}"

    show_arrow_menu "$menu_title" \
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

# Запускаем проверку обновлений в фоне (не блокирует UI)
check_updates_available

if is_installed; then
    show_full_menu
else
    show_install_menu
fi

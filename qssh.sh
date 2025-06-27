#!/data/data/com.termux/files/usr/bin/bash

C_BOLD_BLUE="\033[1;34m"
C_BOLD_GREEN="\033[1;32m"
C_BOLD_YELLOW="\033[1;33m"
C_BOLD_RED="\033[1;31m"
C_BOLD_CYAN="\033[1;36m"
C_BOLD_MAGENTA="\033[1;35m"
C_BOLD_WHITE="\033[1;37m"
C_RESET="\033[0m"

CONFIG_FILE="$HOME/.ssh/ssh_quick_connect.conf"
BIN_PATH="$PREFIX/bin/qssh"

touch "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

check_dependencies() {
    if ! command -v ssh &> /dev/null; then
        echo -e "${C_BOLD_YELLOW}正在安装 openssh...${C_RESET}"
        pkg install -y openssh
        if [[ $? -ne 0 ]]; then
            echo -e "${C_BOLD_RED}错误：无法安装 openssh，请手动安装：pkg install openssh${C_RESET}"
            exit 1
        fi
        echo -e "${C_BOLD_GREEN}openssh 已安装${C_RESET}"
    fi

    if ! command -v sshpass &> /dev/null; then
        echo -e "${C_BOLD_YELLOW}正在安装 sshpass...${C_RESET}"
        pkg install -y sshpass
        if [[ $? -ne 0 ]]; then
            echo -e "${C_BOLD_RED}错误：无法安装 sshpass，请手动安装：pkg install sshpass${C_RESET}"
            exit 1
        fi
        echo -e "${C_BOLD_GREEN}sshpass 已安装${C_RESET}"
    fi
}

install_qssh() {
    if [[ ! -f "$BIN_PATH" || "$(cat "$0")" != "$(cat "$BIN_PATH")" ]]; then
        echo -e "${C_BOLD_YELLOW}正在安装 qssh 全局命令...${C_RESET}"
        cp "$0" "$BIN_PATH"
        chmod +x "$BIN_PATH"
        if [[ $? -eq 0 ]]; then
            echo -e "${C_BOLD_GREEN}qssh 已安装为全局命令，可使用 'qssh' 运行${C_RESET}"
        else
            echo -e "${C_BOLD_RED}错误：无法安装 qssh，请确保有写入权限：$PREFIX/bin${C_RESET}"
            exit 1
        fi
    fi
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        echo ""
    fi
}

save_config() {
    local username="$1"
    local hostname="$2"
    local port="$3"
    local auth_type="$4"
    local auth_value="$5"
    local remarks="$6"
    echo "$username:$hostname:$port:$auth_type:$auth_value:$remarks" >> "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo -e "${C_BOLD_GREEN}已保存 $username@$hostname ($remarks) 的配置${C_RESET}"
}

add_ssh_config() {
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 添加新的 SSH 配置       │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    echo -e "${C_BOLD_CYAN}请输入用户名 (默认 root):${C_RESET}"
    read -p "" username
    username=${username:-root}
    echo -e "${C_BOLD_CYAN}请输入主机地址 (例如 192.168.1.1):${C_RESET}"
    read -p "" hostname
    echo -e "${C_BOLD_CYAN}请输入端口 (默认 22):${C_RESET}"
    read -p "" port
    port=${port:-22}
    echo -e "${C_BOLD_CYAN}使用密码 (p) 还是 SSH 密钥 (k)? [p/k]:${C_RESET}"
    read -p "" auth_choice

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo -e "${C_BOLD_RED}端口必须是数字，使用默认端口 22${C_RESET}"
        port=22
    fi

    if [[ -z "$hostname" ]]; then
        echo -e "${C_BOLD_RED}错误：主机地址不能为空${C_RESET}"
        return 1
    fi

    if [[ "$auth_choice" == "k" ]]; then
        echo -e "${C_BOLD_CYAN}请输入 SSH 密钥文件路径 (例如 ~/.ssh/id_rsa):${C_RESET}"
        read -p "" key_file
        key_file="${key_file/#\~/$HOME}"
        if [[ ! -f "$key_file" ]]; then
            echo -e "${C_BOLD_RED}错误：密钥文件 $key_file 不存在${C_RESET}"
            return 1
        fi
        chmod 600 "$key_file"
        auth_type="key"
        auth_value="$key_file"
    else
        echo -e "${C_BOLD_CYAN}请输入密码:${C_RESET}"
        read -s -p "" password
        echo
        auth_type="password"
        auth_value="$password"
    fi

    echo -e "${C_BOLD_CYAN}请输入备注 (可选，按 Enter 跳过):${C_RESET}"
    read -p "" remarks
    save_config "$username" "$hostname" "$port" "$auth_type" "$auth_value" "$remarks"
}

edit_config() {
    if [[ ! -s "$CONFIG_FILE" ]]; then
        echo -e "${C_BOLD_RED}没有保存的配置${C_RESET}"
        return
    fi
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 编辑 SSH 配置           │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    echo -e "${C_BOLD_MAGENTA}可用配置:${C_RESET}"
    load_config | awk -F: '{print "\033[1;33m" NR ". " $1 "@" $2 ":" $3 " (" $4 ") [" ($6 ? $6 : "无") "]\033[0m"}'
    echo -e "${C_BOLD_CYAN}选择要编辑的配置编号 (输入 0 取消):${C_RESET}"
    read -p "" selection
    if [[ "$selection" == "0" ]]; then
        echo -e "${C_BOLD_GREEN}已取消编辑${C_RESET}"
        return
    fi
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]]; then
        echo -e "${C_BOLD_RED}无效的选择${C_RESET}"
        return
    fi
    local total_lines=$(wc -l < "$CONFIG_FILE")
    if [[ "$selection" -gt "$total_lines" ]]; then
        echo -e "${C_BOLD_RED}无效的选择${C_RESET}"
        return
    fi
    config_line=$(load_config | sed -n "${selection}p")
    IFS=':' read -r old_username old_hostname old_port old_auth_type old_auth_value old_remarks <<< "$config_line"
    echo -e "${C_BOLD_YELLOW}当前配置: $old_username@$old_hostname:$old_port ($old_auth_type) [$old_remarks]${C_RESET}"
    echo -e "${C_BOLD_CYAN}请输入新用户名 (当前: $old_username, 按 Enter 保留):${C_RESET}"
    read -p "" username
    username=${username:-$old_username}
    echo -e "${C_BOLD_CYAN}请输入新主机地址 (当前: $old_hostname, 按 Enter 保留):${C_RESET}"
    read -p "" hostname
    hostname=${hostname:-$old_hostname}
    echo -e "${C_BOLD_CYAN}请输入新端口 (当前: $old_port, 按 Enter 保留):${C_RESET}"
    read -p "" port
    port=${port:-$old_port}
    echo -e "${C_BOLD_CYAN}使用密码 (p) 还是 SSH 密钥 (k)? (当前: $old_auth_type, 按 Enter 保留) [p/k]:${C_RESET}"
    read -p "" auth_choice
    auth_choice=${auth_choice:-$old_auth_type}

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo -e "${C_BOLD_RED}端口必须是数字，使用当前端口 $old_port${C_RESET}"
        port=$old_port
    fi

    if [[ -z "$hostname" ]]; then
        echo -e "${C_BOLD_RED}错误：主机地址不能为空${C_RESET}"
        return 1
    fi

    if [[ "$auth_choice" == "k" ]]; then
        echo -e "${C_BOLD_CYAN}请输入新 SSH 密钥文件路径 (当前: $old_auth_value, 按 Enter 保留):${C_RESET}"
        read -p "" key_file
        key_file=${key_file:-$old_auth_value}
        key_file="${key_file/#\~/$HOME}"
        if [[ ! -f "$key_file" ]]; then
            echo -e "${C_BOLD_RED}错误：密钥文件 $key_file 不存在${C_RESET}"
            return 1
        fi
        chmod 600 "$key_file"
        auth_type="key"
        auth_value="$key_file"
    else
        echo -e "${C_BOLD_CYAN}请输入新密码 (按 Enter 保留当前密码):${C_RESET}"
        read -s -p "" password
        echo
        auth_type="password"
        auth_value=${password:-$old_auth_value}
    fi

    echo -e "${C_BOLD_CYAN}请输入新备注 (当前: $old_remarks, 按 Enter 保留):${C_RESET}"
    read -p "" remarks
    remarks=${remarks:-$old_remarks}

    local temp_file=$(mktemp)
    load_config > "$temp_file"
    sed -i "${selection}s/.*/$username:$hostname:$port:$auth_type:$auth_value:$remarks/" "$temp_file"
    mv "$temp_file" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo -e "${C_BOLD_GREEN}已更新 $username@$hostname ($remarks) 的配置${C_RESET}"
}

delete_ssh_config() {
    if [[ ! -s "$CONFIG_FILE" ]]; then
        echo -e "${C_BOLD_RED}没有保存的配置${C_RESET}"
        return
    fi
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 删除 SSH 配置           │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    echo -e "${C_BOLD_MAGENTA}可用配置:${C_RESET}"
    load_config | awk -F: '{print "\033[1;33m" NR ". " $1 "@" $2 ":" $3 " (" $4 ") [" ($6 ? $6 : "无") "]\033[0m"}'
    echo -e "${C_BOLD_CYAN}选择要删除的配置编号 (输入 0 取消):${C_RESET}"
    read -p "" selection
    if [[ "$selection" == "0" ]]; then
        echo -e "${C_BOLD_GREEN}已取消删除${C_RESET}"
        return
    fi
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]]; then
        echo -e "${C_BOLD_RED}无效的选择${C_RESET}"
        return
    fi
    local total_lines=$(wc -l < "$CONFIG_FILE")
    if [[ "$selection" -gt "$total_lines" ]]; then
        echo -e "${C_BOLD_RED}无效的选择${C_RESET}"
        return
    fi
    sed -i "${selection}d" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo -e "${C_BOLD_GREEN}配置已删除${C_RESET}"
}

ssh_connect() {
    local username="$1"
    local hostname="$2"
    local port="$3"
    local auth_type="$4"
    local auth_value="$5"
    local remarks="$6"

    echo -e "${C_BOLD_BLUE}正在连接到 $username@$hostname:$port ($remarks)...${C_RESET}"
    if [[ "$auth_type" == "password" ]]; then
        check_dependencies
        sshpass -p "$auth_value" ssh -o StrictHostKeyChecking=no -p "$port" "$username@$hostname"
    else
        ssh -o StrictHostKeyChecking=no -p "$port" -i "$auth_value" "$username@$hostname"
    fi
    if [[ $? -eq 0 ]]; then
        echo -e "${C_BOLD_GREEN}成功连接到 $username@$hostname ($remarks)${C_RESET}"
    else
        echo -e "${C_BOLD_RED}连接失败${C_RESET}"
    fi
}

list_configs() {
    if [[ ! -s "$CONFIG_FILE" ]]; then
        echo -e "${C_BOLD_RED}没有保存的配置${C_RESET}"
        return
    fi
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 已保存的配置           │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    load_config | awk -F: '{print "\033[1;33m地址: " $1 "@" $2 ", 端口: " $3 ", 认证类型: " $4 ", 备注: " ($6 ? $6 : "无") "\033[0m"}'
}

main() {
    check_dependencies
    install_qssh
    while true; do
        echo -e "${C_BOLD_BLUE}=====================================${C_RESET}"
        echo -e "${C_BOLD_MAGENTA}         SSH 快捷连接工具         ${C_RESET}"
        echo -e "${C_BOLD_BLUE}=====================================${C_RESET}"
        echo -e "${C_BOLD_GREEN}1. 添加新的 SSH 配置${C_RESET}"
        echo -e "${C_BOLD_YELLOW}2. 连接已保存的 SSH${C_RESET}"
        echo -e "${C_BOLD_CYAN}3. 列出所有保存的配置${C_RESET}"
        echo -e "${C_BOLD_RED}4. 删除 SSH 配置${C_RESET}"
        echo -e "${C_BOLD_MAGENTA}5. 编辑 SSH 配置${C_RESET}"
        echo -e "${C_BOLD_WHITE}6. 退出${C_RESET}"
        echo -e "${C_BOLD_BLUE}=====================================${C_RESET}"
        echo -e "${C_BOLD_CYAN}请选择操作 (1-6):${C_RESET}"
        read -p "" choice

        case $choice in
            1)
                add_ssh_config
                ;;
            2)
                if [[ ! -s "$CONFIG_FILE" ]]; then
                    echo -e "${C_BOLD_RED}没有保存的配置，请先添加${C_RESET}"
                    continue
                fi
                echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
                echo -e "${C_BOLD_BLUE}│ 选择要连接的配置       │${C_RESET}"
                echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
                echo -e "${C_BOLD_MAGENTA}可用配置:${C_RESET}"
                load_config | awk -F: '{print "\033[1;33m" NR ". " $1 "@" $2 ":" $3 " (" $4 ") [" ($6 ? $6 : "无") "]\033[0m"}'
                echo -e "${C_BOLD_CYAN}选择要连接的配置编号:${C_RESET}"
                read -p "" selection
                config_line=$(load_config | sed -n "${selection}p")
                if [[ -z "$config_line" ]]; then
                    echo -e "${C_BOLD_RED}无效的选择${C_RESET}"
                    continue
                fi
                IFS=':' read -r username hostname port auth_type auth_value remarks <<< "$config_line"
                ssh_connect "$username" "$hostname" "$port" "$auth_type" "$auth_value" "$remarks"
                ;;
            3)
                list_configs
                ;;
            4)
                delete_ssh_config
                ;;
            5)
                edit_config
                ;;
            6)
                echo -e "${C_BOLD_WHITE}退出程序${C_RESET}"
                exit 0
                ;;
            *)
                echo -e "${C_BOLD_RED}无效选项，请重新选择${C_RESET}"
                ;;
        esac
    done
}

main
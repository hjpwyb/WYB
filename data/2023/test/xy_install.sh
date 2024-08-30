#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2086

PATH=${PATH}:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/opt/homebrew/bin
export PATH

Blue="\033[1;34m"
Green="\033[1;32m"
Red="\033[1;31m"
Yellow="\033[1;33m"
NC="\033[0m"
INFO="[${Green}INFO${NC}]"
ERROR="[${Red}ERROR${NC}]"
WARN="[${Yellow}WARN${NC}]"

function INFO() {
    echo -e "${INFO} ${1}"
}
function ERROR() {
    echo -e "${ERROR} ${1}"
}
function WARN() {
    echo -e "${WARN} ${1}"
}

function root_need() {
    if [[ $EUID -ne 0 ]]; then
        ERROR '此脚本必须以 root 身份运行！'
        exit 1
    fi
}

function ___install_docker() {

    if ! which docker; then
        WARN "docker 未安装，脚本尝试自动安装..."
        wget -qO- get.docker.com | bash
        if which docker; then
            INFO "docker 安装成功！"
        else
            ERROR "docker 安装失败，请手动安装！"
            exit 1
        fi
    fi

}

install_package() {
    local package=$1
    local install_cmd="$2 $package"

    if ! which $package > /dev/null 2>&1; then
        WARN "$package 未安装，脚本尝试自动安装..."
        if eval "$install_cmd"; then
            INFO "$package 安装成功！"
        else
            ERROR "$package 安装失败，请手动安装！"
            exit 1
        fi
    fi
}

# 用grep -Eqi "QNAP" /etc/issue判断威联通系统
packages_need() {
    local update_cmd
    local install_cmd

    if [ -f /etc/debian_version ]; then
        update_cmd="apt update -y"
        install_cmd="apt install -y"
    elif [ -f /etc/redhat-release ]; then
        install_cmd="yum install -y"
    elif [ -f /etc/SuSE-release ]; then
        update_cmd="zypper refresh"
        install_cmd="zypper install"
    elif [ -f /etc/alpine-release ]; then
        install_cmd="apk add"
    elif [ -f /etc/arch-release ]; then
        update_cmd="pacman -Sy --noconfirm"
        install_cmd="pacman -S --noconfirm"
    else
        ERROR "不支持的操作系统."
        exit 1
    fi

    [ -n "$update_cmd" ] && eval "$update_cmd"
    install_package "curl" "$install_cmd"
    if ! which wget; then
        install_package "wget" "$install_cmd"
    fi
    ___install_docker
}

function check_space() {
    free_size=$(df -P "$1" | tail -n1 | awk '{print $4}')
    free_size_G=$((free_size / 1024 / 1024))
    if [ "$free_size_G" -le "$2" ]; then
        ERROR "空间剩余容量不够：${free_size_G}G 小于最低要求${2}G"
        exit 1
    else
        INFO "磁盘可用空间：${free_size_G}G"
    fi
}

function get_emby_image() {
    cpu_arch=$(uname -m)
    case $cpu_arch in
    "x86_64" | *"amd64"*)
        emby_image="emby/embyserver:4.8.0.56"
        ;;
    "aarch64" | *"arm64"* | *"armv8"* | *"arm/v8"*)
        emby_image="emby/embyserver_arm64v8:4.8.0.56"
        ;;
    "armv7l")
        emby_image="emby/embyserver_arm32v7:4.8.0.56"
        ;;
    *)
        ERROR "不支持你的CPU架构：$cpu_arch"
        exit 1
        ;;
    esac
    for i in {1..3}; do
        if docker_pull $emby_image; then
            INFO "${emby_image}镜像拉取成功！"
            break
        fi
    done
    docker images --format '{{.Repository}}:{{.Tag}}' | grep -q ${emby_image} || (ERROR "${emby_image}镜像拉取失败，请手动安装emby，无需重新运行本脚本，小雅媒体库在${media_dir}！" && exit 1)
}

function get_jellyfin_image() {
    cpu_arch=$(uname -m)
    case $cpu_arch in
    "x86_64" | *"amd64"*)
        linux_version=$(uname -r | cut -d"." -f1)
        if [ "${linux_version}" -lt 5 ];then
            [[ "${f4_select}" == [56] ]] && emby_image="jellyfin/jellyfin:10.9.6" || emby_image="nyanmisaka/jellyfin:240220-amd64-legacy"
        else
            [[ "${f4_select}" == [56] ]] && emby_image="jellyfin/jellyfin:10.9.6" || emby_image="nyanmisaka/jellyfin:latest"
        fi
        ;;
    *)
        ERROR "不支持你的CPU架构：$cpu_arch"
        exit 1
        ;;
    esac
    for i in {1..3}; do
        if docker_pull $emby_image; then
            INFO "${emby_image}镜像拉取成功！"
            break
        fi
    done
    docker images --format '{{.Repository}}:{{.Tag}}' | grep -q ${emby_image} || (ERROR "${emby_image}镜像拉取失败，请手动安装emby，无需重新运行本脚本，小雅媒体库在${media_dir}！" && exit 1)
}

function get_emby_happy_image() {
    cpu_arch=$(uname -m)
    case $cpu_arch in
    "x86_64" | *"amd64"*)
        emby_image="amilys/embyserver:4.8.0.56"
        ;;
    "aarch64" | *"arm64"* | *"armv8"* | *"arm/v8"*)
        emby_image="amilys/embyserver_arm64v8:4.8.6.0"
        ;;
    *)
        ERROR "不支持你的CPU架构：$cpu_arch"
        exit 1
        ;;
    esac
    for i in {1..3}; do
        if docker_pull $emby_image; then
            INFO "${emby_image}镜像拉取成功！"
            break
        fi
    done
    docker images --format '{{.Repository}}:{{.Tag}}' | grep -q ${emby_image} || (ERROR "${emby_image}镜像拉取失败，请手动安装emby，无需重新运行本脚本，小雅媒体库在${img_mount}！" && exit 1)
}

#获取小雅alist配置目录路径
# function get_config_path() {
#     docker_name=$(docker ps -a | grep ailg/alist | awk '{print $NF}')
#     docker_name=${docker_name:-"xiaoya_jf"}
#     if command -v jq > /dev/null 2>&1; then
#         config_dir=$(docker inspect $docker_name | jq -r '.[].Mounts[] | select(.Destination=="/data") | .Source')
#     else
#         #config_dir=$(docker inspect xiaoya | awk '/"Destination": "\/data"/{print a} {a=$0}'|awk -F\" '{print $4}')
#         config_dir=$(docker inspect --format '{{ (index .Mounts 0).Source }}' "$docker_name")
#     fi
#     echo -e "\033[1;37m找到您的小雅ALIST配置文件路径是: \033[1;35m\n$config_dir\033[0m"
#     echo -e "\n"
#     f12_select_0=""
#     t=10
#     while [[ -z "$f12_select_0" && $t -gt 0 ]]; do
#         printf "\r确认请按任意键，或者按N/n手动输入路径（注：上方显示多个路径也请选择手动输入）：（%2d 秒后将默认确认）：" $t
#         read -r -t 1 -n 1 f12_select_0
#         [ $? -eq 0 ] && break
#         t=$((t - 1))
#     done
#     #read -erp "确认请按任意键，或者按N/n手动输入路径（注：上方显示多个路径也请选择手动输入）：" f12_select_0
#     if [[ $f12_select_0 == [Nn] ]]; then
#         echo -e "\033[1;35m请输入您的小雅ALIST配置文件路径:\033[0m"
#         read -r config_dir
#         if [ -z $1 ];then
#             if ! [[ -d "$config_dir" && -f "$config_dir/mytoken.txt" ]]; then
#                 ERROR "该路径不存在或该路径下没有mytoken.txt配置文件"
#                 ERROR "如果你是选择全新目录重装小雅alist，请先删除原来的容器，再重新运行本脚本！"
#                 ERROR -e "\033[1;31m您选择的目录不正确，程序退出。\033[0m"
#                 exit 1
#             fi
#         fi
#     fi
#     config_dir=${config_dir:-"/etc/xiaoya"}
# }

function get_config_path() {
    images=("ailg/alist" "xiaoyaliu/alist" "ailg/g-box")
    results=()
    for image in "${images[@]}"; do
        while IFS= read -r line; do
            container_name=$(echo $line | awk '{print $NF}')
            if command -v jq > /dev/null 2>&1; then
                config_dir=$(docker inspect $container_name | jq -r '.[].Mounts[] | select(.Destination=="/data") | .Source')
            else
                config_dir=$(docker inspect --format '{{ (index .Mounts 0).Source }}' "$container_name")
            fi
            results+=("$container_name $config_dir")
        done < <(docker ps -a | grep "$image")
    done
    if [ ${#results[@]} -eq 0 ]; then
        #read -p "没有找到任何符合条件的容器，请输入docker_name： " docker_name
        read -p "请输入alist/g-box的配置目录路径：(直接回车将使用/etc/xiaoya目录) " config_dir
        config_dir=${config_dir:-"/etc/xiaoya"}
        check_path $config_dir
    elif [ ${#results[@]} -eq 1 ]; then
        docker_name=$(echo "${results[0]}" | awk '{print $1}')
        config_dir=$(echo "${results[0]}" | awk '{print $2}')
    else
        for i in "${!results[@]}"; do
            printf "[ %-1d ] 容器名: \033[1;33m%-20s\033[0m 配置路径: \033[1;33m%s\033[0m\n" $((i+1)) $(echo "${results[$i]}" | awk '{print $1}') $(echo "${results[$i]}" | awk '{print $2}')
        done
        t=15
        while [[ -z "$choice" && $t -gt 0 ]]; do
            printf "\r找到多个alist相关容器，请选择配置目录所在的正确容器（默认选择第一个正在运行的容器）：（%2d 秒后将默认确认）：" $t
            read -r -t 1 -n 1 choice
            [ $? -eq 0 ] && break
            t=$((t - 1))
        done
        choice=${choice:-1}
        docker_name=$(echo "${results[$((choice-1))]}" | awk '{print $1}')
        config_dir=$(echo "${results[$((choice-1))]}" | awk '{print $2}')
    fi
    echo -e "\033[1;37m你选择的alist容器是：\033[1;35m$docker_name\033[0m"
    echo -e "\033[1;37m你选择的配置目录是：\033[1;35m$config_dir\033[0m"
}

function get_jf_media_path() {
    jf_name=${1}
    if command -v jq; then
        media_dir=$(docker inspect $jf_name | jq -r '.[].Mounts[] | select(.Destination=="/media_jf") | .Source')
    else
        media_dir=$(docker inspect $jf_name | awk '/"Destination": "\/media_jf"/{print a} {a=$0}' | awk -F\" '{print $4}')
    fi
    if [[ -n $media_dir ]]; then
        media_dir=$(dirname "$media_dir")
        echo -e "\033[1;37m找到您的小雅姐夫媒体库路径是: \033[1;35m\n$media_dir\033[0m"
        echo -e "\n"
        read -erp "确认请按任意键，或者按N/n手动输入路径：" f12_select_2
        if [[ $f12_select_2 == [Nn] ]]; then
            echo -e "\033[1;35m请输入您的小雅姐夫媒体库路径:\033[0m"
            read -r media_dir
            check_path $media_dir
        fi
        echo -e "\n"
    else
        echo -e "\033[1;35m请输入您的小雅姐夫媒体库路径:\033[0m"
        read -r media_dir
        check_path $media_dir
    fi
}

function get_emby_media_path() {
    emby_name=${1:-emby}
    if command -v jq; then
        media_dir=$(docker inspect $emby_name | jq -r '.[].Mounts[] | select(.Destination=="/media") | .Source')
    else
        media_dir=$(docker inspect $emby_name | awk '/"Destination": "\/media"/{print a} {a=$0}' | awk -F\" '{print $4}')
    fi
    if [[ -n $media_dir ]]; then
        media_dir=$(dirname "$media_dir")
        echo -e "\033[1;37m找到您原来的小雅emby媒体库路径是: \033[1;35m\n$media_dir\033[0m"
        echo -e "\n"
        read -erp "确认请按任意键，或者按N/n手动输入路径：" f12_select_1
        if [[ $f12_select_1 == [Nn] ]]; then
            echo -e "\033[1;35m请输入您的小雅emby媒体库路径:\033[0m"
            read -r media_dir
            check_path $media_dir
        fi
        echo -e "\n"
    else
        echo -e "\033[1;35m请输入您的小雅emby媒体库路径:\033[0m"
        read -r media_dir
        check_path $media_dir
    fi
}

meta_select() {
    echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
    echo -e "\n"
    echo -e "\033[1;32m1、config.mp4 —— 小雅姐夫的配置目录数据\033[0m"
    echo -e "\n"
    echo -e "\033[1;35m2、all.mp4 —— 除pikpak之外的所有小雅元数据\033[0m"
    echo -e "\n"
    echo -e "\033[1;32m3、pikpak.mp4 —— pikpak元数据（需魔法才能观看）\033[0m"
    echo -e "\n"
    echo -e "\033[1;32m4、全部安装\033[0m"
    echo -e "\n"
    echo -e "——————————————————————————————————————————————————————————————————————————————————"
    echo -e "请选择您\033[1;31m需要安装\033[0m的元数据(输入序号，多项用逗号分隔）："
    read -r f8_select
    if ! [[ $f8_select =~ ^[1-4]([\,\，][1-4])*$ ]]; then
        echo "输入的序号无效，请输入1到3之间的数字。"
        exit 1
    fi

    if ! [[ $f8_select == "4" ]]; then
        files=("config_jf.mp4" "all_jf.mp4" "pikpak_jf.mp4")
        for i in {1..3}; do
            file=${files[$i - 1]}
            if ! [[ $f8_select == *$i* ]]; then
                sed -i "/aria2c.*$file/d" /tmp/update_meta_jf.sh
                sed -i "/7z.*$file/d" /tmp/update_meta_jf.sh
            else
                if [[ -f $media_dir/temp/$file ]] && ! [[ -f $media_dir/temp/$file.aria2 ]]; then
                    WARN "${Yellow}${file}文件已在${media_dir}/temp目录存在,是否要重新解压？$NC"
                    read -erp "请选择：（是-按任意键，否-按N/n键）" yn
                    if [[ $yn == [Nn] ]]; then
                        sed -i "/7z.*$file/d" /tmp/update_meta_jf.sh
                        sed -i "/aria2c.*$file/d" /tmp/update_meta_jf.sh
                    else
                        remote_size=$(curl -sL -D - -o /dev/null --max-time 5 "$docker_addr/d/ailg_jf/${file}" | grep "Content-Length" | cut -d' ' -f2)
                        local_size=$(du -b $media_dir/temp/$file | cut -f1)
                        [[ $remote_size == "$local_size" ]] && sed -i "/aria2c.*$file/d" /tmp/update_meta_jf.sh
                    fi
                fi
            fi
        done
    fi
}

get_emby_status() {
    declare -gA emby_list
    declare -ga emby_order

    while read -r container_id; do
        if docker inspect --format '{{ range .Mounts }}{{ println .Source .Destination }}{{ end }}' $container_id | grep -qE "/xiaoya$ /media|\.img /media\.img"; then
            container_name=$(docker ps -a --format '{{.Names}}' --filter "id=$container_id")
            host_path=$(docker inspect --format '{{ range .Mounts }}{{ println .Source }}{{ end }}' $container_id | grep -E "/xiaoya$|\.img\b")
            emby_list[$container_name]=$host_path
            emby_order+=("$container_name")
        fi
    done < <(docker ps -a | grep -E "${search_img}" | awk '{print $1}')

    if [ ${#emby_list[@]} -ne 0 ]; then
        echo -e "\033[1;37m默认会关闭以下您已安装的小雅emby/jellyfin容器，并删除名为emby/jellyfin_xy的容器！\033[0m"
        for index in "${!emby_order[@]}"; do
            name=${emby_order[$index]}
            printf "[ %-1d ] 容器名: \033[1;33m%-20s\033[0m 媒体库路径: \033[1;33m%s\033[0m\n" $((index + 1)) $name ${emby_list[$name]}
        done
    fi
}

#镜像代理的内容抄的DDSRem大佬的，适当修改了一下
function docker_pull() {
    mirrors=()
    INFO "正在从${config_dir}/docker_mirrors.txt文件获取代理点配置……"
    while IFS= read -r line; do
        mirrors+=("$line")
    done < "${config_dir}/docker_mirrors.txt"

    if command -v timeout > /dev/null 2>&1;then
        for mirror in "${mirrors[@]}"; do
            INFO "正在从${mirror}代理点为您下载镜像……"
            #local_sha=$(timeout 300 docker pull "${mirror}/${1}" 2>&1 | grep 'Digest: sha256' | awk -F':' '{print $3}')
            if command -v mktemp > /dev/null; then
                tempfile=$(mktemp)
            else
                tempfile="/tmp/tmp_sha"
            fi
            timeout 300 docker pull "${mirror}/${1}" | tee "$tempfile"
            local_sha=$(grep 'Digest: sha256' "$tempfile" | awk -F':' '{print $3}')
            echo -e "local_sha:${local_sha}"
            rm "$tempfile"

            if [ -n "${local_sha}" ]; then
                sed -i "\#${1}#d" "${config_dir}/ailg_sha.txt"
                echo "${1} ${local_sha}" >> "${config_dir}/ailg_sha.txt"
                [[ "${mirror}" == "docker.io" ]] && return 0
                break
            else
                WARN "${1} 镜像拉取失败，正在进行重试..."
            fi
        done
    else
        for mirror in "${mirrors[@]}"; do
            INFO "正在从${mirror}代理点为您下载镜像……"
            timeout=200
            (docker pull "${mirror}/${1}" 2>&1 | tee /dev/stderr | grep 'Digest: sha256' | awk -F':' '{print $3}' > "/tmp/tmp_sha") &
            pid=$!
            count=0
            while kill -0 $pid 2>/dev/null; do
                sleep 5
                count=$((count+5))
                if [ $count -ge $timeout ]; then
                    echo "Command timed out"
                    kill $pid
                    break
                fi
            done
            local_sha=$(cat "/tmp/tmp_sha")
            rm "/tmp/tmp_sha"
            if [ -n "${local_sha}" ]; then
                INFO "${1} 镜像拉取成功！"
                sed -i "\#${1}#d" "${config_dir}/ailg_sha.txt"
                echo "${1} ${local_sha}" >> "${config_dir}/ailg_sha.txt"
                echo -e "local_sha:${local_sha}"
                [[ "${mirror}" == "docker.io" ]] && return 0
                break
            else
                WARN "${1} 镜像拉取失败，正在进行重试..."
            fi
        done
    fi

    if [ -n "$(docker images -q "${mirror}/${1}")" ]; then
        docker tag "${mirror}/${1}" "${1}"
        docker rmi "${mirror}/${1}"
        return 0
    else
        ERROR "已尝试docker_mirrors.txt中所有镜像代理拉取失败，程序将退出，请检查网络后再试！"
        WARN "如需重测速选择代理，请手动删除${config_dir}/docker_mirrors.txt文件后重新运行脚本！"
        exit 1       
    fi
}

update_ailg() {
    [ -z "${config_dir}" ] && get_config_path
    if [[ -n "$1" ]];then
        update_img="$1"
    fi
    #local name_img
    #name_img=$(echo "${update_img}" | awk -F'[/:]' '{print $2}')
    #local tag_img
    #tag_img=$(echo "${update_img}" | awk -F'[/:]' '{print $3}')
    if [ -f $config_dir/ailg_sha.txt ]; then
        local_sha=$(grep -E "${update_img}" "$config_dir/ailg_sha.txt" | awk '{print $2}')
    else
        local_sha=$(docker inspect -f'{{index .RepoDigests 0}}' "${update_img}" | cut -f2 -d:)
    fi
    for i in {1..3}; do
        remote_sha=$(curl -sSLf https://xy.ggbond.org/xy/ailg_sha_remote.txt | grep -E "${update_img}" | awk '{print $2}')
        [ -n "${remote_sha}" ] && break
    done
    #remote_sha=$(curl -s -m 20 "https://hub.docker.com/v2/repositories/ailg/${name_img}/tags/${tag_img}" | grep -oE '[0-9a-f]{64}' | tail -1)
    #[ -z "${remote_sha}" ] && remote_sha=$(docker exec $docker_name cat "/${name_img}_${tag_img}_sha.txt")
    if [ ! "$local_sha" == "$remote_sha" ]; then
        docker rmi "${update_img}"
        retries=0
        max_retries=3
        while [ $retries -lt $max_retries ]; do
            if docker_pull "${update_img}"; then
                INFO "${update_img} 镜像拉取成功！"
                break
            else
                WARN "${update_img} 镜像拉取失败，正在进行第 $((retries + 1)) 次重试..."
                retries=$((retries + 1))
            fi
        done
        if [ $retries -eq $max_retries ]; then
            ERROR "镜像拉取失败，已达到最大重试次数！"
            exit 1
        fi
    elif [ -z "$local_sha" ] &&  [ -z "$remote_sha" ]; then
        docker_pull "${update_img}"
    fi
}

function user_select1() {
    echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
    echo -e "\n"
    echo -e "\033[1;32m1、host版 - 无🍉十全大补瓜🍉第三方播放器$NC"
    echo -e "\n"
    echo -e "\033[1;35m2、latest版 - 也是host网络模式！适配小雅emby/jellyfin速装版 有🍉十全大补瓜🍉第三方播放器，推荐安装！$NC"
    echo -e "\n"
    echo -e "——————————————————————————————————————————————————————————————————————————————————"
    while :;do
        read -erp "请选择您要安装的版本（输入1-2，按b返回上级或按q退出）：" ver_alist
        case "$ver_alist" in
            1)
                host="host"
                _update_img="ailg/alist:hostmode"
                break
                ;;
            2)
                host=""
                _update_img="ailg/alist:latest"
                break
                ;;
            [Bb])
                clear
                main
                break
                ;;
            [Qq])
                exit
                ;;
            *)
                ERROR "输入错误，按任意键重新输入！"
                read -rn 1
                continue
                ;;
        esac
    done
    if [[ $st_alist =~ "已安装" ]]; then
        WARN "您的小雅ALIST老G版已安装，是否需要重装？"
        read -erp "请选择：（确认重装按Y/y，否则按任意键返回！）" re_setup
        if [[ $re_setup == [Yy] ]]; then
            check_env
            [ -z "${config_dir}" ] && get_config_path
            INFO "小雅ALIST老G版配置路径为：$config_dir"
            INFO "正在停止和删除旧的小雅alist容器"
            docker stop $docker_name
            docker rm $docker_name
            INFO "$docker_name 容器已删除"
            update_ailg "${_update_img}"
        else
            main
            return
        fi
    else
        check_env
        INFO "正在检查和删除已安装的小雅alist"
        rm_alist
        INFO "原有小雅alist容器已删除"
        if [[ -n "$config_dir" ]]; then
            INFO "你原来小雅alist的配置路径是：${Blue}${config_dir}${NC}，可使用原有配置继续安装！"
            read -erp "确认请按任意键，或者按N/n手动输入路径：" user_select_0
            if [[ $user_select_0 == [Nn] ]]; then
                echo -e "\033[1;35m请输入您的小雅ALIST配置文件路径:\033[0m"
                read -r config_dir
                check_path $config_dir
                INFO "小雅ALIST老G版配置路径为：$config_dir"
                update_ailg "${_update_img}"
            fi
        else
            read -erp "请输入小雅alist的安装路径，使用默认的/etc/xiaoya可直接回车：" config_dir
            [[ -z $config_dir ]] && config_dir="/etc/xiaoya"
            check_path $config_dir
            INFO "小雅ALIST老G版配置路径为：$config_dir"
            INFO "正在更新${_update_img}镜像……"
            update_ailg "${_update_img}"
        fi
    fi
    curl -o /tmp/update_new_jf.sh https://xy.ggbond.org/xy/update_new_jf.sh
    for i in {1..5}; do
        grep -q "长度不对" /tmp/update_new_jf.sh && break
        echo -e "文件获取失败，正在进行第${i}次重试……"
        rm -f /tmp/update_new_jf.sh >/dev/null 2>&1
        curl -o /tmp/update_new_jf.sh https://xy.ggbond.org/xy/update_new_jf.sh
    done
    grep -q "长度不对" /tmp/update_new_jf.sh || {
        echo -e "文件获取失败，检查网络后重新运行脚本！"
        rm -f /tmp/update_new_jf.sh
        exit 1
    }
    echo "http://127.0.0.1:6908" > $config_dir/emby_server.txt
    echo "http://127.0.0.1:6909" > $config_dir/jellyfin_server.txt
    bash -c "$(cat /tmp/update_new_jf.sh)" -s $config_dir $host
    [ $? -eq 0 ] && INFO "${Blue}哇塞！你的小雅ALIST老G版安装完成了！$NC" || ERROR "哎呀！翻车失败了！"
}

function user_select2() {
    if [[ $st_alist =~ "未安装" ]] && [[ $st_gbox =~ "未安装" ]]; then
        ERROR "请先安装小雅ALIST老G版或G-Box，再执行本安装！"
        main
        return
    fi
    if [[ $st_jf =~ "已安装" ]]; then
        WARN "您的小雅姐夫已安装，是否需要重装？"
        read -erp "请选择：（确认重装按Y/y，否则按任意键返回！）" re_setup
        if [[ $re_setup == [Yy] ]]; then
            check_env
            [ -z "${config_dir}" ] && get_config_path
            get_jf_media_path "jellyfin_xy"
            docker stop $jf_name
            docker rm $jf_name
        else
            main
            return
        fi
    else
        [ -z "${config_dir}" ] && get_config_path
        echo -e "\033[1;35m请输入您的小雅姐夫媒体库路径:\033[0m"
        read -r media_dir
        check_path $media_dir
    fi
    if [ -s $config_dir/docker_address.txt ]; then
        docker_addr=$(head -n1 $config_dir/docker_address.txt)
    else
        echo "请先配置 $config_dir/docker_address.txt，以便获取docker 地址"
        exit
    fi
    mkdir -p $media_dir/xiaoya
    mkdir -p $media_dir/temp
    curl -o /tmp/update_meta_jf.sh https://xy.ggbond.org/xy/update_meta_jf.sh
    meta_select
    chmod 777 /tmp/update_meta_jf.sh
    docker run -i --security-opt seccomp=unconfined --rm --net=host -v /tmp:/tmp -v $media_dir:/media -v $config_dir:/etc/xiaoya -e LANG=C.UTF-8 ailg/ggbond:latest /tmp/update_meta_jf.sh
    #dir=$(find $media_dir -type d -name "*config*" -print -quit)
    mv "$media_dir/jf_config" "$media_dir/confg"
    chmod -R 777 $media_dir/confg
    chmod -R 777 $media_dir/xiaoya
    host=$(echo $docker_addr | cut -f1,2 -d:)
    host_ip=$(grep -oP '\d+\.\d+\.\d+\.\d+' $config_dir/docker_address.txt)
    if ! [[ -f /etc/nsswitch.conf ]]; then
        echo -e "hosts:\tfiles dns\nnetworks:\tfiles" > /etc/nsswitch.conf
    fi
    docker run -d --name jellyfin_xy -v /etc/nsswitch.conf:/etc/nsswitch.conf \
        -v $media_dir/config_jf:/config \
        -v $media_dir/xiaoya:/media_jf \
        --user 0:0 \
        -p 6909:8096 \
        -p 6920:8920 \
        -p 1909:1900/udp \
        -p 7369:7359/udp \
        --privileged --add-host="xiaoya.host:${host_ip}" --restart always nyanmisaka/jellyfin:240220-amd64-legacy
    INFO "${Blue}小雅姐夫安装完成，正在为您重启小雅alist！$NC"
    echo "${host}:6909" > $config_dir/jellyfin_server.txt
    docker restart xiaoya_jf
    start_time=$(date +%s)
    TARGET_LOG_LINE_SUCCESS="success load storage: [/©️"
    while true; do
        line=$(docker logs "xiaoya_jf" 2>&1 | tail -n 10)
        echo $line
        if [[ "$line" == *"$TARGET_LOG_LINE_SUCCESS"* ]]; then
            break
        fi
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if [ "$elapsed_time" -gt 300 ]; then
            echo "小雅alist未正常启动超时 5分钟，请检查小雅alist的安装！"
            break
        fi
        sleep 3
    done
    INFO "请登陆${Blue} $host:2346 ${NC}访问小雅姐夫，用户名：${Blue} ailg ${NC}，密码：${Blue} 5678 ${NC}"
}

function user_select3() {
    user_select1
    start_time=$(date +%s)
    TARGET_LOG_LINE_SUCCESS="success load storage: [/©️"
    while true; do
        line=$(docker logs "xiaoya_jf" 2>&1 | tail -n 10)
        echo $line
        if [[ "$line" == *"$TARGET_LOG_LINE_SUCCESS"* ]]; then
            break
        fi
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if [ "$elapsed_time" -gt 300 ]; then
            echo "小雅alist未正常启动超时 5分钟，程序将退出，请检查小雅alist的安装，或重启小雅alist后重新运行脚本！"
            exit
        fi
        sleep 3
    done
    user_select2
}

function user_select4() {
    down_img() {
        if [[ ! -f $image_dir/$emby_ailg ]] || [[ -f $image_dir/$emby_ailg.aria2 ]]; then
            docker_pull ailg/ggbond:latest
            docker exec $docker_name ali_clear -1 > /dev/null 2>&1
            docker run --rm --net=host -v $image_dir:/image ailg/ggbond:latest \
                aria2c -o /image/$emby_ailg --auto-file-renaming=false --allow-overwrite=true -c -x6 "$docker_addr/d/ailg_jf/${down_path}/$emby_ailg"
        fi
        local_size=$(du -b $image_dir/$emby_ailg | cut -f1)
        for i in {1..3}; do
            if [[ -f $image_dir/$emby_ailg.aria2 ]] || [[ $remote_size -gt "$local_size" ]]; then
                docker exec $docker_name ali_clear -1 > /dev/null 2>&1
                docker run --rm --net=host -v $image_dir:/image ailg/ggbond:latest \
                    aria2c -o /image/$emby_ailg --auto-file-renaming=false --allow-overwrite=true -c -x6 "$docker_addr/d/ailg_jf/${down_path}/$emby_ailg"
                local_size=$(du -b $image_dir/$emby_ailg | cut -f1)
            else
                break
            fi
        done
        [[ -f $image_dir/$emby_ailg.aria2 ]] || [[ $remote_size != "$local_size" ]] && ERROR "文件下载失败，请检查网络后重新运行脚本！" && WARN "未下完的文件存放在${image_dir}目录，以便您续传下载，如不再需要请手动清除！" && exit 1
    }
    while :; do
        clear
        echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
        echo -e "\n"
        echo -e "A、安装小雅EMBY老G速装版会$Red删除原小雅emby/jellyfin容器，如需保留请退出脚本停止原容器进行更名！$NC"
        echo -e "\n"
        echo -e "B、完整版与小雅emby原版一样，Lite版无PikPak数据（适合无梯子用户），请按需选择！"
        echo -e "\n"
        echo -e "C、${Yellow}老G速装版会随emby/jellyfin启动自动挂载镜像，感谢DDSRem大佬提供的解决思路！${NC}"
        echo -e "\n"
        echo -e "D、${Yellow}老G速装版新增jellyfin最新版10.9.6，建议16G以上内存安装！${NC}"
        echo -e "\n"
        echo -e "——————————————————————————————————————————————————————————————————————————————————"
        echo -e "\n"
        echo -e "\033[1;32m1、小雅EMBY老G速装 - 完整版\033[0m"
        echo -e "\n"
        echo -e "\033[1;35m2、小雅EMBY老G速装 - Lite版\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m3、小雅JELLYFIN老G速装 - 10.8.13 - 完整版\033[0m"
        echo -e "\n"
        echo -e "\033[1;35m4、小雅JELLYFIN老G速装 - 10.8.13 - Lite版\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m5、小雅JELLYFIN老G速装 - 10.9.6 - 完整版\033[0m"
        echo -e "\n"
        echo -e "\033[1;35m6、小雅JELLYFIN老G速装 - 10.9.6 - Lite版\033[0m"
        echo -e "\n"
        echo -e "——————————————————————————————————————————————————————————————————————————————————"

        read -erp "请输入您的选择（1-4，按b返回上级菜单或按q退出）；" f4_select
        case "$f4_select" in
        1)
            emby_ailg="emby-ailg.mp4"
            emby_img="emby-ailg.img"
            space_need=110
            break
            ;;
        2)
            emby_ailg="emby-ailg-lite.mp4"
            emby_img="emby-ailg-lite.img"
            space_need=95
            break
            ;;
        3)
            emby_ailg="jellyfin-ailg.mp4"
            emby_img="jellyfin-ailg.img"
            space_need=130
            break
            ;;
        4)
            emby_ailg="jellyfin-ailg-lite.mp4"
            emby_img="jellyfin-ailg-lite.img"
            space_need=100
            break
            ;;
        5)
            emby_ailg="jellyfin-10.9.6-ailg.mp4"
            emby_img="jellyfin-10.9.6-ailg.img"
            space_need=130
            break
            ;;
        6)
            emby_ailg="jellyfin-10.9.6-ailg-lite.mp4"
            emby_img="jellyfin-10.9.6-ailg-lite.img"
            space_need=100
            break
            ;;
        [Bb])
            clear
            main
            break
            ;;
        [Qq])
            exit
            ;;
        *)
            ERROR "输入错误，按任意键重新输入！"
            read -rn 1
            continue
            ;;
        esac
    done

    if [[ $st_alist =~ "未安装" ]] && [[ $st_gbox =~ "未安装" ]]; then
        ERROR "请先安装G-Box/小雅ALIST老G版，再执行本安装！"
        read -p '按任意键返回主菜单'
        main
        return
    fi
    umask 000
    check_env
    [ -z "${config_dir}" ] && get_config_path
    INFO "正在为您清理阿里云盘空间……"
    docker exec $docker_name ali_clear -1 > /dev/null 2>&1
    echo -e "\033[1;35m请输入您的小雅emby/jellyfin镜像存放路径（请确保大于${space_need}G剩余空间！）:\033[0m"
    read -r image_dir
    check_path $image_dir
    check_path $image_dir
    if [ -f "${image_dir}/${emby_ailg}" ] || [ -f "${image_dir}/${emby_img}" ]; then
        echo "镜像文件已存在，跳过空间检查"
    else
        check_space $image_dir $space_need
    fi

    if [[ "${f4_select}" == [12] ]]; then
        search_img="emby/embyserver|amilys/embyserver"
        del_name="emby"
        loop_order="/dev/loop7"
        down_path="emby"
        get_emby_image
        init="run"
        emd_name="xiaoya-emd"
        entrypoint_mount="entrypoint_emd"
    elif [[ "${f4_select}" == [3456] ]]; then
        search_img="nyanmisaka/jellyfin|jellyfin/jellyfin"
        del_name="jellyfin_xy"
        loop_order="/dev/loop6"
        down_path="jellyfin"
        get_jellyfin_image
        init="run_jf"
        emd_name="xiaoya-emd-jf"
        entrypoint_mount="entrypoint_emd_jf"
    fi
    get_emby_status

    # for name in "${!emby_list[@]}"; do
    #     if [[ "${name}" == "${del_name}" ]]; then
    #         read -erp "$(echo -e "\033[1;36m是否保留名为${del_name}的容器！按Y/y保留，按其他任意键将删除！\033[0m\n请输入：") " del_emby
    #         [[ "${del_emby}" == [Yy] ]] && del_emby=false || del_emby=true
    #     fi
    # done
    docker ps -a | grep 'ddsderek/xiaoya-emd' | awk '{print $1}' | xargs docker stop
    if [ ${#emby_list[@]} -ne 0 ]; then
        for op_emby in "${!emby_list[@]}"; do
            docker stop "${op_emby}"
            INFO "${op_emby}容器已关闭！"
            if [[ "${emby_list[$op_emby]}" =~ .*\.img ]]; then
                mount | grep "${emby_list[$op_emby]%/*}/emby-xy" && umount "${emby_list[$op_emby]%/*}/emby-xy" && losetup -d "${loop_order}"
            else
                mount | grep "${emby_list[$op_emby]%/*}" && umount "${emby_list[$op_emby]%/*}"
            fi
            [[ "${op_emby}" == "${del_name}" ]] && docker rm "${op_emby}" && INFO "${op_emby}容器已删除！"
        done
    fi
    #$del_emby && emby_name=${del_name} || emby_name="${del_name}-ailg"
    emby_name=${del_name}
    mkdir -p "$image_dir/emby-xy" && media_dir="$image_dir/emby-xy"
    losetup | grep -q "${loop_order#/dev/}" && losetup -d "${loop_order}"

    if [ -s $config_dir/docker_address.txt ]; then
        docker_addr=$(head -n1 $config_dir/docker_address.txt)
    else
        echo "请先配置 $config_dir/docker_address.txt，以便获取docker 地址"
        exit
    fi

    start_time=$(date +%s)
    for i in {1..5}; do
        remote_size=$(curl -sL -D - -o /dev/null --max-time 5 "$docker_addr/d/ailg_jf/${down_path}/$emby_ailg" | grep "Content-Length" | cut -d' ' -f2 | tail -n 1 | tr -d '\r')
        [[ -n $remote_size ]] && echo -e "remotesize is：${remote_size}" && break
    done
    if [[ $remote_size -lt 100000 ]]; then
        ERROR "获取文件大小失败，请检查网络后重新运行脚本！"
        echo -e "${Yellow}排障步骤：\n1、检查5678打开alist能否正常播放（排除token失效和风控！）"
        echo -e "${Yellow}2、检查alist配置目录的docker_address.txt是否正确指向你的alist访问地址，\n   应为宿主机+5678端口，示例：http://192.168.2.3:5678"
        echo -e "${Yellow}3、检查阿里云盘空间，确保剩余空间大于${space_need}G${NC}"
        exit 1
    fi
    INFO "远程文件大小获取成功！"
    INFO "即将下载${emby_ailg}文件……"
    if [ ! -f $image_dir/$emby_img ]; then
        down_img
    else
        local_size=$(du -b $image_dir/$emby_img | cut -f1)
        [ "$local_size" -lt "$remote_size" ] && down_img
    fi

    update_ailg ailg/ggbond:latest

    echo "$local_size $remote_size $image_dir/$emby_ailg $media_dir"
    mount | grep $media_dir && umount $media_dir
    if [ "$local_size" -eq "$remote_size" ]; then
        if [ -f "$image_dir/$emby_img" ]; then
            docker run -i --privileged --rm --net=host -v ${image_dir}:/ailg -v $media_dir:/mount_emby ailg/ggbond:latest \
                exp_ailg "/ailg/$emby_img" "/mount_emby" 30
        else
            docker run -i --privileged --rm --net=host -v ${image_dir}:/ailg -v $media_dir:/mount_emby ailg/ggbond:latest \
                exp_ailg "/ailg/$emby_ailg" "/mount_emby" 30
        fi
    else
        INFO "本地已有镜像，无需重新下载！"
    fi

    #清除原来可能存在的任务计划
    sed -i '/mount_ailg/d' /etc/rc.local > /dev/null
    sed -i '/mount_ailg/d' /boot/config/go > /dev/null
    crontab -l | grep -v mount_ailg > /tmp/cronjob.tmp
    crontab /tmp/cronjob.tmp

    if [ ! -f /usr/bin/mount_ailg ]; then
        docker cp "${docker_name}":/var/lib/mount_ailg "/usr/bin/mount_ailg"
        chmod 777 /usr/bin/mount_ailg
    fi

    INFO "开始安装小雅emby/jellyfin……"
    host=$(echo $docker_addr | cut -f1,2 -d:)
    host_ip=$(echo $docker_addr | cut -d':' -f2 | tr -d '/')
    if ! [[ -f /etc/nsswitch.conf ]]; then
        echo -e "hosts:\tfiles dns\nnetworks:\tfiles" > /etc/nsswitch.conf
    fi
    #get_emby_image
    #if [ ! -f "$image_dir/${init}" ]; then
        rm -f "$image_dir/${init}"
        docker cp "${docker_name}":/var/lib/${init} "$image_dir/"
        chmod 777 "$image_dir/${init}"
    #fi
    #if ${del_emby}; then
        if [[ "${emby_image}" =~ emby ]]; then
            docker run -d --name $emby_name -v /etc/nsswitch.conf:/etc/nsswitch.conf \
                -v $image_dir/$emby_img:/media.img \
                -v "$image_dir/run":/etc/cont-init.d/run \
                --user 0:0 \
                --net=host \
                --privileged --add-host="xiaoya.host:127.0.0.1" --restart always $emby_image
            echo "http://127.0.0.1:6908" > $config_dir/emby_server.txt   
        elif [[ "${emby_image}" =~ jellyfin/jellyfin ]]; then
            docker run -d --name $emby_name -v /etc/nsswitch.conf:/etc/nsswitch.conf \
                -v $image_dir/$emby_img:/media.img \
                -v "$image_dir/run_jf":/etc/run_jf \
                --entrypoint "/etc/run_jf" \
                --user 0:0 \
                --net=host \
                --privileged --add-host="xiaoya.host:127.0.0.1" --restart always $emby_image   
            echo "http://127.0.0.1:6910" > $config_dir/jellyfin_server.txt   
        else
            docker run -d --name $emby_name -v /etc/nsswitch.conf:/etc/nsswitch.conf \
                -v $image_dir/$emby_img:/media.img \
                -v "$image_dir/run_jf":/etc/run_jf \
                --entrypoint "/etc/run_jf" \
                --user 0:0 \
                -p 6909:6909 \
                -p 6920:6920 \
                -p 1909:1900/udp \
                -p 6359:7359/udp \
                --privileged --add-host="xiaoya.host:${host_ip}" --restart always $emby_image
            echo "${host}:6909" > $config_dir/jellyfin_server.txt
        fi
    # else
    #     if [[ "${emby_image}" =~ emby ]]; then
    #         docker run -d --name $emby_name -v /etc/nsswitch.conf:/etc/nsswitch.conf \
    #             -v $image_dir/$emby_img:/media.img \
    #             -v "$image_dir/run":/etc/cont-init.d/run \
    #             --user 0:0 \
    #             -p 5908:6908 \
    #             -p 5920:8920 \
    #             -p 5900:1900/udp \
    #             -p 5359:7359/udp \
    #             --privileged --add-host="xiaoya.host:127.0.0.1" --restart always $emby_image
    #             echo -e "http://${host_ip}:5908" > $config_dir/emby_server.txt
    #     else
    #         docker run -d --name $emby_name -v /etc/nsswitch.conf:/etc/nsswitch.conf \
    #             -v $image_dir/$emby_img:/media.img \
    #             -v "$image_dir/run_jf":/etc/run_jf \
    #             --entrypoint "/etc/run_jf" \
    #             --user 0:0 \
    #             -p 5909:8096 \
    #             -p 5920:8920 \
    #             -p 1919:1900/udp \
    #             -p 5359:7359/udp \
    #             --privileged --add-host="xiaoya.host:${host_ip}" --restart always $emby_image
    #             echo -e "http://${host_ip}:5909" > $config_dir/jellyfin_server.txt
    #     fi
    # fi
    [[ ! "${emby_image}" =~ emby ]] && echo "aec47bd0434940b480c348f91e4b8c2b" > $config_dir/infuse_api_key_jf.txt
    #UPDATE ApiKeys SET AccessToken='aec47bd0434940b480c348f91e4b8c2b' WHERE Name='ailg';

    current_time=$(date +%s)
    elapsed_time=$(awk -v start=$start_time -v end=$current_time 'BEGIN {printf "%.2f\n", (end-start)/60}')
    INFO "${Blue}恭喜您！小雅emby/jellyfin安装完成，安装时间为 ${elapsed_time} 分钟！$NC"
    INFO "请登陆${Blue} $host:2345/2346 ${NC}访问小雅emby/jellyfin，用户名：${Blue} xiaoya/ailg ${NC}，密码：${Blue} 1234/5678 ${NC}"
    INFO "注：如果$host:6908/6909/5908/5909可访问，$host:2345/2346访问失败（502/500等错误），按如下步骤排障：\n\t1、检查$config_dir/emby/jellyfin_server.txt文件中的地址是否正确指向emby的访问地址，即：$host:6908/6909/5908/5909或http://127.0.0.1:6908/6909/5908/5909\n\t2、地址正确重启你的小雅alist容器即可。"
    echo -e "\n"
    echo -e "\033[1;33m是否继续安装小雅元数据爬虫同步？${NC}"
    answer=""
    t=30
    while [[ -z "$answer" && $t -gt 0 ]]; do
        printf "\r按Y/y键安装，按N/n退出（%2d 秒后将默认安装）：" $t
        read -r -t 1 -n 1 answer
        t=$((t - 1))
    done

    if [[ ! $answer =~ ^[Nn]$ || -z "$answer" ]]; then
        INFO "正在为您安装小雅元数据爬虫同步……"

        for i in {1..3}; do
            if docker_pull ddsderek/xiaoya-emd:latest; then
                INFO "ddsderek/xiaoya-emd:latest镜像拉取成功！"
                break
            fi
        done
        docker images --format '{{.Repository}}:{{.Tag}}' | grep -q ddsderek/xiaoya-emd:latest || (ERROR "ddsderek/xiaoya-emd:latest镜像拉取失败，请检查网络后手动安装！" && exit 1)

        if ! docker cp "${docker_name}":/var/lib/"${entrypoint_mount}" "$image_dir/entrypoint.sh"; then
            if ! curl -o "$image_dir/entrypoint.sh" https://xy.ggbond.org/xy/${entrypoint_mount}; then
                ERROR "获取文件失败，请将老G的alist更新到最新版或检查网络后重试。更新方法：重新运行一键脚本，选1重装alist，使用原来的目录！" && exit 1
            fi
        fi
        chmod 777 "$image_dir/entrypoint.sh"
        if docker ps -a | grep -qE " ${emd_name}\b" && docker stop "${emd_name}" && docker rm "${emd_name}"; then
            INFO "${Yellow}已删除您原来的${emd_name}容器！${NC}"
        fi
        docker_pull ddsderek/xiaoya-emd:latest
        if docker run -d \
            --name="${emd_name}" \
            --privileged \
            --restart=always \
            --net=host \
            -e IMG_VOLUME=true \
            -v "$image_dir/entrypoint.sh":/entrypoint.sh \
            ddsderek/xiaoya-emd:latest; then
            INFO "小雅元数据同步爬虫安装成功！"
        else
            INFO "小雅元数据同步爬虫安装失败，请手动安装！"
        fi
    fi
}

ailg_uninstall() {
    INFO "是否${Red}删除老G速装版镜像文件${NC} [Y/n]（保留请按N/n键，按其他任意键默认删除）"
    read -erp "请输入：" clear_img
    [[ ! "${clear_img}" =~ ^[Nn]$ ]] && clear_img="y"

    declare -ga img_order
    get_emby_status > /dev/null
    if [ ${#emby_list[@]} -ne 0 ]; then
        for op_emby in "${!emby_list[@]}"; do
            if docker inspect --format '{{ range .Mounts }}{{ println .Source .Destination }}{{ end }}' "${op_emby}" | grep -qE "\.img /media\.img"; then
                img_order+=("${op_emby}")
            fi
        done
        if [ ${#img_order[@]} -ne 0 ]; then
            echo -e "\033[1;37m请选择你要卸载的老G速装版emby：\033[0m"
            for index in "${!img_order[@]}"; do
                name=${img_order[$index]}
                printf "[ %-1d ] 容器名: \033[1;33m%-20s\033[0m 媒体库路径: \033[1;33m%s\033[0m\n" $((index + 1)) $name ${emby_list[$name]}
            done
            while :; do
                read -erp "输入序号：" img_select
                if [ "${img_select}" -gt 0 ] && [ "${img_select}" -le ${#img_order[@]} ]; then
                    img_path=${emby_list[${img_order[$((img_select - 1))]}]}
                    emby_name=${img_order[$((img_select - 1))]}
                    for op_emby in "${img_order[@]}"; do
                        docker stop "${op_emby}"
                        INFO "${op_emby}容器已关闭！"
                    done
                    docker ps -a | grep 'ddsderek/xiaoya-emd' | awk '{print $1}' | xargs docker stop
                    INFO "小雅爬虫容器已关闭！"
                    if [[ $(basename "${img_path}") == emby*.img ]]; then
                        loop_order=/dev/loop7
                        docker rm xiaoya-emd
                    else
                        loop_order=/dev/loop6
                        docker rm xiaoya-emd-jf
                    fi
                    umount "${loop_order}" > /dev/null 2>&1
                    losetup -d "${loop_order}" > /dev/null 2>&1
                    mount | grep -qF "${img_mount}" && umount "${img_mount}"
                    docker rm ${emby_name}
                    if [[ "${clear_img}" =~ ^[Yy]$ ]]; then
                        rm -f "${img_path}"
                        if [ -n "${img_path%/*}" ]; then
                            rm -rf "${img_path%/*}"/*
                        fi
                        INFO "已卸载${Yellow}${emby_name}${NC}容器，并删除${Yellow}${img_path}${NC}镜像！"
                    else
                        INFO "已卸载${Yellow}${emby_name}${NC}容器，未删除${Yellow}${img_path}${NC}镜像！"
                    fi
                    break
                else
                    ERROR "您输入的序号无效，请输入一个在 1 到 ${#img_order[@]} 的数字。"
                fi
            done
        else
            INFO "您未安装任何老G速装版emby，程序退出！" && exit 1
        fi
    else
        INFO "您未安装任何老G速装版emby，程序退出！" && exit 1
    fi
}

happy_emby() {
    declare -ga img_order
    get_emby_happy_image
    get_emby_status > /dev/null
    if [ ${#emby_list[@]} -ne 0 ]; then
        for op_emby in "${!emby_list[@]}"; do
            if docker inspect --format '{{ range .Mounts }}{{ println .Source .Destination }}{{ end }}' "${op_emby}" | grep -qE "\.img /media\.img"; then
                img_order+=("${op_emby}")
            fi
        done
        if [ ${#img_order[@]} -ne 0 ]; then
            echo -e "\033[1;37m请选择你要换装/重装开心版的emby！\033[0m"
            for index in "${!img_order[@]}"; do
                name=${img_order[$index]}
                printf "[ %-1d ] 容器名: \033[1;33m%-20s\033[0m 媒体库路径: \033[1;33m%s\033[0m\n" $((index + 1)) $name ${emby_list[$name]}
            done
            while :; do
                read -erp "输入序号：" img_select
                if [ "${img_select}" -gt 0 ] && [ "${img_select}" -le ${#img_order[@]} ]; then
                    happy_name=${img_order[$((img_select - 1))]}
                    happy_path=${emby_list[${happy_name}]}
                    docker stop "${happy_name}" && docker rm "${happy_name}"
                    INFO "旧的${happy_name}容器已删除！"
                    INFO "开始安装小雅emby……"
                    xiaoya_host="127.0.0.1"
                    if ! [[ -f /etc/nsswitch.conf ]]; then
                        echo -e "hosts:\tfiles dns\nnetworks:\tfiles" > /etc/nsswitch.conf
                    fi
                    docker run -d --name "${happy_name}" -v /etc/nsswitch.conf:/etc/nsswitch.conf \
                        -v "${happy_path}":/media.img \
                        -v "${happy_path%/*.img}/run":/etc/cont-init.d/run \
                        --device /dev/dri:/dev/dri \
                        --user 0:0 \
                        --net=host \
                        --privileged --add-host="xiaoya.host:$xiaoya_host" --restart always ${emby_image}
                    break
                else
                    ERROR "您输入的序号无效，请输入一个在 1 到 ${#img_order[@]} 之间的数字。"
                fi
            done
        fi
    else
        ERROR "您当前未安装小雅emby，程序退出！" && exit 1
    fi
}

get_img_path() {
    read -erp "请输入您要挂载的镜像的完整路径：" img_path
    img_name=$(basename "${img_path}")
    case "${img_name}" in
    "emby-ailg.img" | "emby-ailg-lite.img" | "jellyfin-ailg.img" | "jellyfin-ailg-lite.img" | "jellyfin-10.9.6-ailg-lite.img" | "jellyfin-10.9.6-ailg.img") ;;

    *)
        ERROR "您输入的不是老G的镜像，或已改名，确保文件名正确后重新运行脚本！"
        exit 1
        ;;
    esac
    img_mount=${img_path%/*.img}/emby-xy
    read -p "$(echo img_mount is: $img_mount)"
    check_path ${img_mount}
}

mount_img() {
    declare -ga img_order
    search_img="emby/embyserver|amilys/embyserver|nyanmisaka/jellyfin"
    get_emby_status > /dev/null
    update_ailg ailg/ggbond:latest
    if [ ! -f /usr/bin/mount_ailg ]; then
        docker cp xiaoya_jf:/var/lib/mount_ailg "/usr/bin/mount_ailg"
        chmod 777 /usr/bin/mount_ailg
    fi
    if [ ${#emby_list[@]} -ne 0 ]; then
        for op_emby in "${!emby_list[@]}"; do
            if docker inspect --format '{{ range .Mounts }}{{ println .Source .Destination }}{{ end }}' "${op_emby}" | grep -qE "\.img /media\.img"; then
                img_order+=("${op_emby}")
            fi
        done
        if [ ${#img_order[@]} -ne 0 ]; then
            echo -e "\033[1;37m请选择你要挂载的镜像：\033[0m"
            for index in "${!img_order[@]}"; do
                name=${img_order[$index]}
                printf "[ %-1d ] 容器名: \033[1;33m%-20s\033[0m 媒体库路径: \033[1;33m%s\033[0m\n" $((index + 1)) $name ${emby_list[$name]}
            done
            printf "[ 0 ] \033[1;33m手动输入需要挂载的老G速装版镜像的完整路径\n\033[0m"
            while :; do
                read -erp "输入序号：" img_select
                if [ "${img_select}" -gt 0 ] && [ "${img_select}" -le ${#img_order[@]} ]; then
                    img_path=${emby_list[${img_order[$((img_select - 1))]}]}
                    img_mount=${img_path%/*.img}/emby-xy
                    emby_name=${img_order[$((img_select - 1))]}
                    for op_emby in "${img_order[@]}"; do
                        docker stop "${op_emby}"
                        INFO "${op_emby}容器已关闭！"
                    done
                    docker ps -a | grep 'ddsderek/xiaoya-emd' | awk '{print $1}' | xargs docker stop
                    INFO "小雅爬虫容器已关闭！"
                    [[ $(basename "${img_path}") == emby*.img ]] && loop_order=/dev/loop7 || loop_order=/dev/loop6
                    umount "${loop_order}" > /dev/null 2>&1
                    losetup -d "${loop_order}" > /dev/null 2>&1
                    mount | grep -qF "${img_mount}" && umount "${img_mount}"
                    #sleep 3
                    docker start ${emby_name}
                    sleep 5
                    if ! docker ps --format '{{.Names}}' | grep -q "^${emby_name}$"; then
                        if mount_ailg "${img_path}" "${img_mount}"; then
                            INFO "已将${img_path}挂载到${img_mount}目录！"
                            return 0
                        else
                            ERROR "挂载失败，请重启设备后重试！"
                            exit 1
                        fi
                    fi
                    if mount "${loop_order}" ${img_mount}; then
                        INFO "已将${Yellow}${img_path}${NC}挂载到${Yellow}${img_mount}${NC}目录！" && WARN "如您想操作小雅config数据的同步或更新，请先手动关闭${Yellow}${emby_name}${NC}容器！"
                    else
                        ERROR "挂载失败，${Yellow}${img_mount}${NC}挂载目录非空或已经挂载，请重启设备后重试！" && exit 1
                    fi
                    break
                elif [ "${img_select}" -eq 0 ]; then
                    get_img_path
                    if mount_ailg "${img_path}" "${img_mount}"; then
                        INFO "已将${img_path}挂载到${img_mount}目录！"
                    else
                        ERROR "挂载失败，请重启设备后重试！"
                        exit 1
                    fi
                    break
                else
                    ERROR "您输入的序号无效，请输入一个在 0 到 ${#img_order[@]} 的数字。"
                fi
            done
        else
            get_img_path
            if mount_ailg "${img_path}" "${img_mount}"; then
                INFO "已将${img_path}挂载到${img_mount}目录！"
            else
                ERROR "挂载失败，请重启设备后重试！"
                exit 1
            fi
        fi
    else
        get_img_path
        if mount_ailg "${img_path}" "${img_mount}"; then
            INFO "已将${img_path}挂载到${img_mount}目录！"
        else
            ERROR "挂载失败，请重启设备后重试！"
            exit 1
        fi
    fi
}

sync_config() {
    if [[ $st_alist =~ "未安装" ]]; then
        ERROR "请先安装小雅ALIST老G版，再执行本安装！"
        main
        return
    fi
    umask 000
    check_env
    [ -z "${config_dir}" ] && get_config_path
    mount_img || exit 1
    #docker stop ${emby_name}
    if [ "${img_select}" -eq 0 ]; then
        get_emby_image
    else
        emby_name=${img_order[$((img_select - 1))]}
        emby_image=$(docker inspect -f '{{.Config.Image}}' "${emby_name}")
    fi
    if command -v ifconfig > /dev/null 2>&1; then
        docker0=$(ifconfig docker0 | awk '/inet / {print $2}' | sed 's/addr://')
    else
        docker0=$(ip addr show docker0 | awk '/inet / {print $2}' | cut -d '/' -f 1)
    fi
    if [ -n "$docker0" ]; then
        INFO "docker0 的 IP 地址是：$docker0"
    else
        WARN "无法获取 docker0 的 IP 地址！"
        docker0=$(ip address | grep inet | grep -v 172.17 | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | sed 's/addr://' | head -n1 | cut -f1 -d"/")
        INFO "尝试使用本地IP：${docker0}"
    fi
    echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
    echo -e "\n"
    echo -e "\033[1;32m1、小雅config干净重装/更新（config数据已损坏请选此项！）\033[0m"
    echo -e "\n"
    echo -e "\033[1;35m2、小雅config保留重装/更新（config数据未损坏想保留用户数据及自己媒体库可选此项！）\033[0m"
    echo -e "\n"
    echo -e "——————————————————————————————————————————————————————————————————————————————————"

    read -erp "请输入您的选择（1-2）；" sync_select
    if [[ "$sync_select" == "1" ]]; then
        echo -e "测试xiaoya的联通性..."
        if curl -siL http://127.0.0.1:5678/d/README.md | grep -v 302 | grep -q "x-oss-"; then
            xiaoya_addr="http://127.0.0.1:5678"
        elif curl -siL http://${docker0}:5678/d/README.md | grep -v 302 | grep -q "x-oss-"; then
            xiaoya_addr="http://${docker0}:5678"
        else
            if [ -s $config_dir/docker_address.txt ]; then
                docker_address=$(head -n1 $config_dir/docker_address.txt)
                if curl -siL http://${docker_address}:5678/d/README.md | grep -v 302 | grep "x-oss-"; then
                    xiaoya_addr=${docker_address}
                else
                    ERROR "请检查xiaoya是否正常运行后再试"
                    exit 1
                fi
            else
                ERROR "请先配置 $config_dir/docker_address.txt 后重试"
                exit 1
            fi
        fi
        for i in {1..5}; do
            remote_cfg_size=$(curl -sL -D - -o /dev/null --max-time 5 "$xiaoya_addr/d/元数据/config.mp4" | grep "Content-Length" | cut -d' ' -f2)
            [[ -n $remote_cfg_size ]] && break
        done
        local_cfg_size=$(du -b "${img_mount}/temp/config.mp4" | cut -f1)
        echo -e "\033[1;33mremote_cfg_size=${remote_cfg_size}\nlocal_cfg_size=${local_cfg_size}\033[0m"
        for i in {1..5}; do
            if [[ -z "${local_cfg_size}" ]] || [[ ! $remote_size == "$local_size" ]] || [[ -f ${img_mount}/temp/config.mp4.aria2 ]]; then
                echo -e "\033[1;33m正在下载config.mp4……\033[0m"
                rm -f ${img_mount}/temp/config.mp4
                docker run -i \
                    --security-opt seccomp=unconfined \
                    --rm \
                    --net=host \
                    -v ${img_mount}:/media \
                    -v $config_dir:/etc/xiaoya \
                    --workdir=/media/temp \
                    -e LANG=C.UTF-8 \
                    ailg/ggbond:latest \
                    aria2c -o config.mp4 --continue=true -x6 --conditional-get=true --allow-overwrite=true "${xiaoya_addr}/d/元数据/config.mp4"
                local_cfg_size=$(du -b "${img_mount}/temp/config.mp4" | cut -f1)
                run_7z=true
            else
                echo -e "\033[1;33m本地config.mp4与远程文件一样，无需重新下载！\033[0m"
                run_7z=false
                break
            fi
        done
        if [[ -z "${local_cfg_size}" ]] || [[ ! $remote_size == "$local_size" ]] || [[ -f ${img_mount}/temp/config.mp4.aria2 ]]; then
            ERROR "config.mp4下载失败，请检查网络，如果token失效或触发阿里风控将小雅alist停止1小时后再打开重试！"
            exit 1
        fi

        #rm -rf ${img_mount}/config/cache/* ${img_mount}/config/metadata/* ${img_mount}/config/data/library.db*
        #7z x -aoa -bb1 -mmt=16 /media/temp/config.mp4 -o/media/config/data/ config/data/library.db*
        #7z x -aoa -bb1 -mmt=16 /media/temp/config.mp4 -o/media/config/cache/ config/cache/*
        #7z x -aoa -bb1 -mmt=16 /media/temp/config.mp4 -o/media/config/metadata/ config/metadata/*
        if ! "${run_7z}"; then
            echo -e "\033[1;33m远程小雅config未更新，与本地数据一样，是否重新解压本地config.mp4？${NC}"
            answer=""
            t=30
            while [[ -z "$answer" && $t -gt 0 ]]; do
                printf "\r按Y/y键解压，按N/n退出（%2d 秒后将默认不解压退出）：" $t
                read -r -t 1 -n 1 answer
                t=$((t - 1))
            done
            [[ "${answer}" == [Yy] ]] && run_7z=true
        fi
        if "${run_7z}"; then
            rm -rf ${img_mount}/config
            docker run -i \
                --security-opt seccomp=unconfined \
                --rm \
                --net=host \
                -v ${img_mount}:/media \
                -v $config_dir:/etc/xiaoya \
                --workdir=/media \
                -e LANG=C.UTF-8 \
                ailg/ggbond:latest \
                7z x -aoa -bb1 -mmt=16 /media/temp/config.mp4
            echo -e "下载解压元数据完成"
            INFO "小雅config安装完成！"
            docker start "${emby_name}"
        else
            INFO "远程config与本地一样，未执行解压/更新！"
            exit 0
        fi

    elif [[ "$sync_select" == "2" ]]; then
        ! docker ps | grep -q "${emby_name}" && ERROR "${emby_name}未正常启动，如果数据库已损坏请重新运行脚本，选择干净安装！" && exit 1
        xiaoya_host="127.0.0.1"
        # docker run -d --name emby-sync -v /etc/nsswitch.conf:/etc/nsswitch.conf \
        # -v ${img_mount}/xiaoya:/media \
        # -v ${img_mount}/config:/config \
        # --user 0:0 \
        # --net=host \
        # --privileged --add-host="xiaoya.host:$xiaoya_host" --restart always $emby_image
        echo -e "\n"
        echo -e "\033[1;31m同步进行中，需要较长时间，请耐心等待，直到出命令行提示符才算结束！\033[0m"
        [ -f "/tmp/sync_emby_config_ailg.sh" ] && rm -f /tmp/sync_emby_config_ailg.sh
        for i in {1..3}; do
            curl -sSfL -o /tmp/sync_emby_config_ailg.sh https://xy.ggbond.org/xy/sync_emby_config_img_ailg.sh
            grep -q "返回错误" /tmp/sync_emby_config_ailg.sh && break
        done
        grep -q "返回错误" /tmp/sync_emby_config_ailg.sh || {
            echo -e "文件获取失败，检查网络或重新运行脚本！"
            rm -f /tmp/sync_emby_config_ailg.sh
            exit 1
        }
        chmod 777 /tmp/sync_emby_config_ailg.sh
        bash -c "$(cat /tmp/sync_emby_config_ailg.sh)" -s ${img_mount} $config_dir "${emby_name}" | tee /tmp/cron.log
        echo -e "\n"
        echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
        INFO "安装完成"
        WARN "已在原目录（config/data）为您创建library.db的备份文件library.org.db"
        echo -e "\n"
        WARN "只有emby启动报错，或启动后媒体库丢失才需执行以下操作："
        echo -e "\033[1;35m1、先停止容器，检查emby媒体库目录的config/data目录中是否有library.org.db备份文件！"
        echo -e "2、如果没有，说明备份文件已自动恢复，原数据启动不了需要排查其他问题，或重装config目录！"
        echo -e "3、如果有，继续执行3-5步，先删除library.db/library.db-shm/library.db-wal三个文件！"
        echo -e "4、将library.org.db改名为library.db，library.db-wal.bak改名为library.db-wal（没有此文件则略过）！"
        echo -e "5、将library.db-shm.bak改名为library.db-shm（没有此文件则略过），重启emby容器即可恢复原数据！\033[0m"
        echo -e "——————————————————————————————————————————————————————————————————————————————————"
    else
        ERROR "您的输入有误，程序退出" && exit 1
    fi
}

user_selecto() {
    while :; do
        clear
        echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
        echo -e "\n"
        echo -e "\033[1;32m1、卸载小雅emby/jellyfin老G速装版\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m2、更换开心版小雅EMBY\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m3、挂载老G速装版镜像\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m4、老G速装版镜像重装/同步config\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m5、老G的alist/G-box自动更新\033[0m"
        echo -e "\n"
        echo -e "——————————————————————————————————————————————————————————————————————————————————"
        read -erp "请输入您的选择（1-2，按b返回上级菜单或按q退出）；" fo_select
        case "$fo_select" in
        1)
            ailg_uninstall emby
            break
            ;;
        2)
            happy_emby
            break
            ;;
        3)
            mount_img
            break
            ;;
        4)
            sync_config
            break
            ;;
        5)
            sync_plan
            break
            ;;
        [Bb])
            clear
            main
            break
            ;;
        [Qq])
            exit
            ;;
        *)
            ERROR "输入错误，按任意键重新输入！"
            read -r -n 1
            continue
            ;;
        esac
    done
}

function sync_plan() {
    while :; do
        clear
        echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
        echo -e "\n"
        echo -e "\033[1;32m请输入您要设置自动更新的容器：\033[0m"
        echo -e "\033[1;32m1、g-box\033[0m"
        echo -e "\033[1;32m2、xiaoya_jf\033[0m"
        echo -e "\n"
        echo -e "——————————————————————————————————————————————————————————————————————————————————"
        read -erp "输入序号：（1/2）" user_select_sync_ailg
        case "$user_select_sync_ailg" in
        1) 
            docker_name="g-box"
            image_name="ailg/g-box:hostmode"
            break
            ;;
        2)
            docker_name="xiaoya_jf"
            image_name="ailg/alist:hostmode"
            break
            ;;
        *)
            ERROR "输入错误，按任意键重新输入！"
            read -r -n 1
            continue
            ;;
        esac
    done

    while :; do
        echo -e "\033[1;37m请设置您希望${docker_name}每次检查更新的时间：\033[0m"
        read -ep "注意：24小时制，格式：\"hh:mm\"，小时分钟之间用英文冒号分隔，示例：23:45）：" sync_time
        read -ep "您希望几天检查一次？（单位：天）" sync_day
        [[ -f /etc/synoinfo.conf ]] && is_syno="syno"
        time_value=${sync_time//：/:}
        hour=${time_value%%:*}
        minu=${time_value#*:}

        
        if ! [[ "$hour" =~ ^([01]?[0-9]|2[0-3])$ ]] || ! [[ "$minu" =~ ^([0-5]?[0-9])$ ]]; then
            echo "输入错误，请重新输入。小时必须为0-23的正整数，分钟必须为0-59的正整数。"
        else
            break
        fi
    done


    config_dir=$(docker inspect --format '{{ range .Mounts }}{{ if eq .Destination "/data" }}{{ .Source }}{{ end }}{{ end }}' "${docker_name}")
    [ -z "${config_dir}" ] && ERROR "未找到${docker_name}的挂载目录，请检查！" && exit 1
    if command -v crontab >/dev/null 2>&1; then
        crontab -l | grep -v xy_install > /tmp/cronjob.tmp
        echo "$minu $hour */${sync_day} * * /bin/bash -c \"\$(curl -sSLf https://xy.ggbond.org/xy/xy_install.sh)\" -s "${docker_name}" | tee ${config_dir}/cron.log" >> /tmp/cronjob.tmp
        crontab /tmp/cronjob.tmp
        chmod 777 ${config_dir}/cron.log
        echo -e "\n"
        echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
        echo -e "\n"	
        INFO "已经添加下面的记录到crontab定时任务，每${sync_day}天更新一次${docker_name}镜像"
        echo -e "\033[1;35m"
        echo "$(cat /tmp/cronjob.tmp| grep xy_install )"
        echo -e "\033[0m"
        INFO "您可以在 > ${config_dir}/cron.log < 中查看同步执行日志！"
        echo -e "\n"
        echo -e "——————————————————————————————————————————————————————————————————————————————————"
    elif [[ "${is_syno}" == syno ]];then
        cp /etc/crontab /etc/crontab.bak
        echo -e "\033[1;35m已创建/etc/crontab.bak备份文件！\033[0m"
        
        sed -i '/xy_install/d' /etc/crontab
        echo "$minu $hour */${sync_day} * * root /bin/bash -c \"\$(curl -sSLf https://xy.ggbond.org/xy/xy_install.sh)\" -s "${docker_name}" | tee ${config_dir}/cron.log" >> /etc/crontab
        chmod 777 ${config_dir}/cron.log
        echo -e "\n"
        echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
        echo -e "\n"	
        INFO "已经添加下面的记录到crontab定时任务，每$4天更新一次config"
        echo -e "\033[1;35m"
        echo "$(cat /etc/crontab | grep xy_install )"
        echo -e "\033[0m"
        INFO "您可以在 > ${config_dir}/cron.log < 中查看同步执行日志！"
        echo -e "\n"
        echo -e "——————————————————————————————————————————————————————————————————————————————————"
    fi
}

function sync_ailg() {
    if [ "$1" == "g-box" ]; then
        image_name="ailg/g-box:hostmode"
        docker_name="g-box"
    elif [ "$1" == "xiaoya_jf" ]; then
        image_name="ailg/alist:hostmode"
        docker_name="xiaoya_jf"
    else
        ERROR "无效的参数" && exit 1
    fi

    if docker container inspect "${docker_name}" > /dev/null 2>&1; then
        config_dir=$(docker inspect --format '{{ range .Mounts }}{{ if eq .Destination "/data" }}{{ .Source }}{{ end }}{{ end }}' "${docker_name}")
        [ -z "${config_dir}" ] && ERROR "未找到${docker_name}的配置目录，程序退出！" && exit 1
        mounts=$(docker inspect --format '{{ range .Mounts }}{{ if not .Name }}-v {{ .Source }}:{{ .Destination }} {{ end }}{{ end }}' "${docker_name}")
        docker rm -f "${docker_name}"
        current_sha=$(grep "${image_name}" "${config_dir}/ailg_sha.txt" | awk '{print $2}')
        update_ailg "${image_name}"
        update_status=$?
        if [ ${update_status} -eq 0 ]; then
            new_sha=$(grep "${image_name}" "${config_dir}/ailg_sha.txt" | awk '{print $2}')
            if [ "${current_sha}" = "${new_sha}" ]; then
                echo "$(date): ${image_name} 镜像未更新" >> "${config_dir}/ailg_update.txt"
            else
                echo "$(date): ${image_name} 镜像已升级" >> "${config_dir}/ailg_update.txt"
            fi
        else
            ERROR "更新 ${image_name} 镜像失败"
            exit 1
        fi

        docker run -d --name "${docker_name}" --net=host --restart=always ${mounts} "${image_name}"
    else
        ERROR "${docker_name} 容器未安装，程序退出！${NC}" && exit 1
    fi
}

function user_gbox() {
    WARN "安装g-box会卸载已安装的小雅alist和小雅tv-box以避免端口冲突！"
    read -erp "请选择：（确认按Y/y，否则按任意键返回！）" re_setup
    _update_img="ailg/g-box:hostmode"
    #清理旧容器并更新镜像
    if [[ $re_setup == [Yy] ]]; then
        image_keywords=("ailg/alist" "xiaoyaliu/alist" "ailg/g-box")
        for keyword in "${image_keywords[@]}"; do
            for container_id in $(docker ps -a | grep "$keyword" | awk '{print $1}'); do
                config_dir=$(docker inspect "$container_id" | jq -r '.[].Mounts[] | select(.Destination=="/data") | .Source')
                if docker rm -f "$container_id"; then
                    echo -e "${container_id}容器已删除！"
                fi
            done
        done

        update_ailg "${_update_img}"
    else
        main
        return
    fi
    
    #获取安装路径
    if [[ -n "$config_dir" ]]; then
        INFO "你原来小雅alist/tvbox的配置路径是：${Blue}${config_dir}${NC}，可使用原有配置继续安装！"
        read -erp "确认请按任意键，或者按N/n手动输入路径：" user_select_0
        if [[ $user_select_0 == [Nn] ]]; then
            echo -e "\033[1;35m请输入您的小雅g-box配置文件路径:\033[0m"
            read -r config_dir
            check_path $config_dir
            INFO "小雅g-box老G版配置路径为：$config_dir"
        fi
    else
        read -erp "请输入小雅g-box的安装路径，使用默认的/etc/xiaoya可直接回车：" config_dir
        [[ -z $config_dir ]] && config_dir="/etc/xiaoya"
        check_path $config_dir
        INFO "小雅g-box老G版配置路径为：$config_dir"
    fi

    docker run -d --name=g-box --net=host \
        -v "$config_dir":/data \
        --restart=always \
        ailg/g-box:hostmode

    if command -v ifconfig &> /dev/null; then
        localip=$(ifconfig -a|grep inet|grep -v 172. | grep -v 127.0.0.1|grep -v 169. |grep -v inet6|awk '{print $2}'|tr -d "addr:"|head -n1)
    else
        localip=$(ip address|grep inet|grep -v 172. | grep -v 127.0.0.1|grep -v 169. |grep -v inet6|awk '{print $2}'|tr -d "addr:"|head -n1|cut -f1 -d"/")
    fi

    echo "http://$localip:5678" > $config_dir/docker_address.txt
    [ ! -s $config_dir/infuse_api_key.txt ] && echo "e825ed6f7f8f44ffa0563cddaddce14d" > "$config_dir/infuse_api_key.txt"
    [ ! -s $config_dir/infuse_api_key_jf.txt ] && echo "aec47bd0434940b480c348f91e4b8c2b" > "$config_dir/infuse_api_key_jf.txt"
    [ ! -s $config_dir/emby_server.txt ] && echo "http://127.0.0.1:6908" > $config_dir/emby_server.txt
    [ ! -s $config_dir/jellyfin_server.txt ] && echo "http://127.0.0.1:6909" > $config_dir/jellyfin_server.txt

    INFO "${Blue}哇塞！你的小雅g-box老G版安装完成了！$NC"
    INFO "${Blue}如果你没有配置mytoken.txt和myopentoken.txt文件，请登陆\033[1;35mhttp://${localip}:4567\033[0m网页在'账号-详情'中配置！$NC"
}

function main() {
    clear
    st_alist=$(setup_status "$(docker ps -a | grep -E 'ailg/alist' | awk '{print $NF}' | head -n1)")
    st_gbox=$(setup_status "$(docker ps -a | grep -E 'ailg/g-box' | awk '{print $NF}' | head -n1)")
    st_jf=$(setup_status "$(docker ps -a --format '{{.Names}}' | grep 'jellyfin_xy')")
    st_emby=$(setup_status "$(docker inspect --format '{{ range .Mounts }}{{ println .Source .Destination }}{{ end }}' emby |
        grep -qE "/xiaoya$ /media\b|\.img /media\.img" && echo 'emby')")
    echo -e "\e[33m"
    echo -e "————————————————————————————————————使  用  说  明————————————————————————————————"
    echo -e "1、本脚本为G-Box/小雅Jellyfin/Emby全家桶的安装脚本，使用于群晖系统环境，不保证其他系统通用；"
    echo -e "2、本脚本为个人自用，不维护，不更新，不保证适用每个人的环境，请勿用于商业用途；"
    echo -e "3、作者不对使用本脚本造成的任何后果负责，有任何顾虑，请勿运行，按CTRL+C立即退出；"
    echo -e "4、如果您喜欢这个脚本，可以请我喝咖啡：https://xy.ggbond.org/xy/3q.jpg\033[0m"
    echo -e "————————————————————————————————————\033[1;33m安  装  状  态\033[0m————————————————————————————————"
    echo -e "\e[0m"
    echo -e "G-Box：${st_gbox}      小雅ALIST老G版：${st_alist}     小雅姐夫（jellyfin）：${st_jf}      小雅emby：${st_emby}"
    echo -e "\e[0m"
    echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
    echo -e "\n"
    echo -e "\033[1;35m1、安装/重装小雅ALIST老G版\033[0m"
    echo -e "\n"
    echo -e "\033[1;35m2、安装/重装小雅姐夫（非速装版）\033[0m"
    echo -e "\n"
    echo -e "\033[1;35m3、无脑一键全装/重装小雅姐夫（非速装版）\033[0m"
    echo -e "\n"
    echo -e "\033[1;35m4、安装/重装小雅emby/jellyfin（老G速装版）\033[0m"
    echo -e "\n"
    echo -e "\033[1;35m5、安装/重装G-Box（实验功能：支持小雅alist+tvbox+emby/jf的融合怪）\033[0m"
    echo -e "\n"
    echo -e "\033[1;35mo、有问题？选我看看\033[0m"
    echo -e "\n"
    echo -e "——————————————————————————————————————————————————————————————————————————————————"
    read -erp "请输入您的选择（1-4或q退出）；" user_select
    case $user_select in
    1)
        clear
        user_select1
        ;;
    2)
        clear
        user_select2
        ;;
    3)
        clear
        user_select3
        ;;
    4)
        clear
        user_select4
        ;;
    5)
        clear
        user_gbox
        ;;
    [Oo])
        clear
        user_selecto
        ;;
    [Qq])
        exit 0
        ;;
    *)
        ERROR "输入错误，按任意键重新输入！"
        read -r -n 1
        main
        ;;
    esac
}

setup_status() {
    if docker container inspect "${1}" > /dev/null 2>&1; then
        echo -e "${Green}已安装${NC}"
    else
        echo -e "${Red}未安装${NC}"
    fi
}

#检查用户路径输入
check_path() {
    dir_path=$1
    if [[ ! -d "$dir_path" ]]; then
        read -erp "您输入的目录不存在，按Y/y创建，或按其他键退出！" yn
        case $yn in
        [Yy]*)
            mkdir -p $dir_path
            if [[ ! -d $dir_path ]]; then
                echo "您的输入有误，目录创建失败，程序退出！"
                exit 1
            else
                chmod 777 $dir_path
                INFO "${dir_path}目录创建成功！"
            fi
            ;;
        *) exit 0 ;;
        esac
    fi
}

#安装环境检查
check_env() {
    if ! which curl; then
        packages_need
        if ! which curl; then
            ERROR "curl 未安装，请手动安装！"
            exit 1
        fi
        if ! which wget; then
            ERROR "wget 未安装，请手动安装！"
            exit 1
        fi
        if ! which docker; then
            ERROR "docker 未安装，请手动安装！"
            exit 1
        fi
    fi
}

#删除原来的小雅容器
rm_alist() {
    for container in $(docker ps -aq); do
        image=$(docker inspect --format '{{.Config.Image}}' "$container")
        if [[ "$image" == "xiaoyaliu/alist:latest" ]] || [[ "$image" == "xiaoyaliu/alist:hostmode" ]]; then
            WARN "本安装会删除原有的小雅alist容器，按任意键继续，或按CTRL+C退出！"
            read -r -n 1
            echo "Deleting container $container using image $image ..."
            config_dir=$(docker inspect --format '{{ (index .Mounts 0).Source }}' "$container")
            docker stop "$container"
            docker rm "$container"
            echo "Container $container has been deleted."
        fi
    done
}

choose_mirrors() {
    [ -z "${config_dir}" ] && get_config_path check_docker
    mirrors=("docker.io" "docker.fxxk.dedyn.io" "docker.adysec.com" "registry-docker-hub-latest-9vqc.onrender.com" "docker.chenby.cn" "dockerproxy.com" "hub.uuuadc.top" "docker.jsdelivr.fyi" "docker.registry.cyou" "dockerhub.anzu.vip")
    declare -A mirror_total_delays
    if [ ! -f "${config_dir}/docker_mirrors.txt" ]; then
        echo -e "\033[1;32m正在进行代理测速，为您选择最佳代理……\033[0m"
        start_time=$SECONDS
        for i in "${!mirrors[@]}"; do
            total_delay=0
            success=true
            INFO "${mirrors[i]}代理点测速中……"
            for n in {1..3}; do
                output=$(
                    #curl -s -o /dev/null -w '%{time_total}' --head --request GET --connect-timeout 10 "${mirrors[$i]}"
                    curl -s -o /dev/null -w '%{time_total}' --head --request GET -m 10 "${mirrors[$i]}"
                    [ $? -ne 0 ] && success=false && break
                )
                total_delay=$(echo "$total_delay + $output" | awk '{print $1 + $3}')
            done
            if $success && docker pull "${mirrors[$i]}/library/hello-world:latest" &> /dev/null; then
                INFO "${mirrors[i]}代理可用，测试完成！"
                mirror_total_delays["${mirrors[$i]}"]=$total_delay 
                docker rmi "${mirrors[$i]}/library/hello-world:latest" &> /dev/null
            else
                INFO "${mirrors[i]}代理测试失败，将继续测试下一代理点！"
                #break
            fi
        done
        if [ ${#mirror_total_delays[@]} -eq 0 ]; then
            #echo "docker.io" > "${config_dir}/docker_mirrors.txt"
            echo -e "\033[1;31m所有代理测试失败，检查网络或配置可用代理后重新运行脚本，请从主菜单手动退出！\033[0m"
        else
            sorted_mirrors=$(for k in "${!mirror_total_delays[@]}"; do echo $k ${mirror_total_delays["$k"]}; done | sort -n -k2)
            echo "$sorted_mirrors" | head -n 2 | awk '{print $1}' > "${config_dir}/docker_mirrors.txt"
            echo -e "\033[1;32m已为您选取两个最佳代理点并添加到了${config_dir}/docker_mirrors.txt文件中：\033[0m"
            cat ${config_dir}/docker_mirrors.txt
        fi
    end_time=$SECONDS
    execution_time=$((end_time - start_time))
    minutes=$((execution_time / 60))
    seconds=$((execution_time % 60))
    echo "代理测速用时：${minutes} 分 ${seconds} 秒"
    read -n 1 -s -p "$(echo -e "\033[1;32m按任意键继续！\n\033[0m")"
    fi 
}

fuck_docker() {
    clear
    echo -e "\n"
    echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
    echo -e "\033[1;37m1、本脚本首次运行会自动检测docker站点的连接性，并自动为您筛选连接性最好的docker镜像代理！\033[0m"
    echo -e "\033[1;37m2、代理配置文件docker_mirrors.txt默认存放在小雅alist的配置目录，如未自动找到请根据提示完成填写！\033[0m"
    echo -e "\033[1;37m3、如果您找到更好的镜像代理，可手动添加到docker_mirrors.txt中，一行一个，越靠前优化级越高！\033[0m"
    echo -e "\033[1;37m4、如果所有镜像代理测试失败，请勿继续安装并检查您的网络环境，不听劝的将大概率拖取镜像失败！\033[0m"
    echo -e "\033[1;37m5、代理测速正常2-3分钟左右，如某个代理测速卡很久，可按CTRL+C键终止执行，检查网络后重试（如DNS等）！\033[0m"
    echo -e "\033[1;33m6、仅首次运行或docker_mirrors.txt文件不存在或文件中代理失效时需要测速！为了后续顺利安装请耐心等待！\033[0m"
    echo -e "——————————————————————————————————————————————————————————————————————————————————"
    read -n 1 -s -p "$(echo -e "\033[1;32m按任意键继续！\n\033[0m")"
}

if [ "$1" == "g-box" ] || [ "$1" == "xiaoya_jf" ]; then
    sync_ailg "$1"
else
    fuck_docker
    choose_mirrors
    main
fi

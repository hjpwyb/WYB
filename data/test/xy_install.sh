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
    if [ "$free_size_G" -lt "$2" ]; then
        ERROR "空间剩余容量不够：${free_size_G}G 小于最低要求${2}G"
        exit 1
    else
        INFO "磁盘可用空间：${free_size_G}G"
    fi
}

function get_emby_image() {
    # 设置默认版本号
    local version=${1:-"4.9.0.31"}
    
    cpu_arch=$(uname -m)
    case $cpu_arch in
    "x86_64" | *"amd64"*)
        emby_image="emby/embyserver:${version}"
        ;;
    "aarch64" | *"arm64"* | *"armv8"* | *"arm/v8"*)
        emby_image="emby/embyserver_arm64v8:${version}"
        ;;
    "armv7l")
        emby_image="emby/embyserver_arm32v7:${version}"
        ;;
    *)
        ERROR "不支持你的CPU架构：$cpu_arch"
        exit 1
        ;;
    esac

    # 检查镜像是否存在
    if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q ${emby_image}; then
        for i in {1..3}; do
            if docker_pull $emby_image; then
                INFO "${emby_image}镜像拉取成功！"
                break
            fi
        done
    fi

    # 验证镜像是否成功拉取
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
        emby_image="amilys/embyserver:4.9.0.31"
        ;;
    "aarch64" | *"arm64"* | *"armv8"* | *"arm/v8"*)
        emby_image="amilys/embyserver_arm64v8:4.8.9.0"
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

function get_config_path() {
    images=("ailg/alist" "xiaoyaliu/alist" "ailg/g-box")
    results=()
    for image in "${images[@]}"; do
        while IFS= read -r line; do
            container_name=$(echo $line | awk '{print $NF}')
            if command -v jq > /dev/null 2>&1; then
                config_dir=$(docker inspect $container_name | jq -r '.[].Mounts[] | select(.Destination=="/data") | .Source')
            else
                # config_dir=$(docker inspect --format '{{ (index .Mounts 0).Source }}' "$container_name")
                config_dir=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' "$container_name")
            fi
            results+=("$container_name $config_dir")
        done < <(docker ps -a | grep "$image")
    done
    if [ ${#results[@]} -eq 0 ]; then
        #read -p "没有找到任何符合条件的容器，请输入docker_name： " docker_name
        read -erp "请输入alist/g-box的配置目录路径：(直接回车将使用/etc/xiaoya目录) " config_dir
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
    emby_list=()
    emby_order=()

    if command -v mktemp > /dev/null; then
        temp_file=$(mktemp)
    else
        temp_file="/tmp/tmp_img"
    fi
    docker ps -a | grep -E "${search_img}" | awk '{print $1}' > "$temp_file"

    while read -r container_id; do
        if docker inspect --format '{{ range .Mounts }}{{ println .Source .Destination }}{{ end }}' $container_id | grep -qE "/xiaoya$ /media|\.img /media\.img"; then
            container_name=$(docker ps -a --format '{{.Names}}' --filter "id=$container_id")
            host_path=$(docker inspect --format '{{ range .Mounts }}{{ println .Source }}{{ end }}' $container_id | grep -E "/xiaoya$|\.img\b")
            emby_list+=("$container_name:$host_path")
            emby_order+=("$container_name")
        fi
    done < "$temp_file"

    rm "$temp_file"

    if [ ${#emby_list[@]} -ne 0 ]; then
        echo -e "\033[1;37m默认会关闭以下您已安装的小雅emby/jellyfin容器，并删除名为emby/jellyfin_xy的容器！\033[0m"
        for index in "${!emby_order[@]}"; do
            name=${emby_order[$index]}
            for entry in "${emby_list[@]}"; do
                if [[ $entry == $name:* ]]; then
                    host_path=${entry#*:}
                    printf "[ %-1d ] 容器名: \033[1;33m%-20s\033[0m 媒体库路径: \033[1;33m%s\033[0m\n" $((index + 1)) $name $host_path
                fi
            done
        done
    fi
}


#镜像代理的内容抄的DDSRem大佬的，适当修改了一下
function docker_pull() {
    if ! [[ "$skip_choose_mirror" == [Yy] ]]; then
        mirrors=()
        [ -z "${config_dir}" ] && get_config_path
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
            if [[ "${1}" == "ailg/g-box:hostmode" ]]; then
                return 1
            else
                exit 1
            fi     
        fi
    else
        tempfile="/tmp/tmp_sha"
        docker pull "${1}" | tee "$tempfile"
        local_sha=$(grep 'Digest: sha256' "$tempfile" | awk -F':' '{print $3}')
        echo -e "local_sha:${local_sha}"
        rm "$tempfile"

        if [ -n "${local_sha}" ]; then
            sed -i "\#${1}#d" "${config_dir}/ailg_sha.txt"
            echo "${1} ${local_sha}" >> "${config_dir}/ailg_sha.txt"
            return 0
        else
            WARN "${1} 镜像拉取失败，正在进行重试..."
            return 1
        fi
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
        remote_sha=$(curl -sSLf https://gbox.ggbond.org/ailg_sha_remote.txt | grep -E "${update_img}" | awk '{print $2}')
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
            if [[ "$update_img" == "ailg/g-box:hostmode" ]]; then
                return 1
            else
                exit 1
            fi
        fi
    elif [ -z "$local_sha" ] &&  [ -z "$remote_sha" ]; then
        docker_pull "${update_img}"
    fi
}

function user_select1() {
    docker_name="$(docker ps -a | grep -E 'ailg/g-box' | awk '{print $NF}' | head -n1)"
    if [ -n "${docker_name}" ]; then
        WARN "您已安装g-box，包含老G版alist的所有功能，无需再安装老G版的alist！继续安装将自动卸载已安装的g-box容器！"
        read -erp "是否卸载G-Box继续安装老G版alist？（确认按Y/y，否则按任意键返回！）：" ow_install
        if [[ $ow_install == [Yy] ]]; then
            # config_dir=$(docker inspect --format '{{ (index .Mounts 0).Source }}' "${docker_name}")
            config_dir=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' "${docker_name}")
            INFO "正在停止和删除${docker_name}容器……"
            docker rm -f $docker_name
            INFO "$docker_name 容器已删除"
        else
            main
            return
        fi
    fi
    echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
    echo -e "\n"
    echo -e "\033[1;32m1、host版 - 无🍉十全大补瓜🍉第三方播放器（不再更新！）$NC"
    echo -e "\n"
    echo -e "\033[1;35m2、latest版 - 也是host网络模式！适配小雅emby/jellyfin速装版 有🍉十全大补瓜🍉第三方播放器，未装G-Box可装！$NC"
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
    curl -o /tmp/update_new_jf.sh https://gbox.ggbond.org/update_new_jf.sh
    for i in {1..5}; do
        grep -q "长度不对" /tmp/update_new_jf.sh && break
        echo -e "文件获取失败，正在进行第${i}次重试……"
        rm -f /tmp/update_new_jf.sh >/dev/null 2>&1
        curl -o /tmp/update_new_jf.sh https://gbox.ggbond.org/update_new_jf.sh
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
    curl -o /tmp/update_meta_jf.sh https://gbox.ggbond.org/update_meta_jf.sh
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
        -e JELLYFIN_CACHE_DIR=/config/cache \
        -e HEALTHCHECK_URL=http://localhost:6909/health \
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

check_loop_support() {
    if [ ! -e /dev/loop-control ]; then
        if ! lsmod | awk '$1 == "loop"'; then
            if ! command -v modprobe &> /dev/null; then
                echo "modprobe command not found."
                return 1
            else
                if modprobe loop; then
                    if ! mknod -m 660 /dev/loop-control c 10 237; then
                        ERROR "您的系统环境不支持直接挂载loop回循设备，无法安装速装版emby/jellyfin，请手动启用该功能后重新运行脚本安装！或用DDS大佬脚本安装原版小雅emby！" && exit 1
                    fi
                else
                    ERROR "您的系统环境不支持直接挂载loop回循设备，无法安装速装版emby/jellyfin，请手动启用该功能后重新运行脚本安装！或用DDS大佬脚本安装原版小雅emby！" && exit 1
                fi
            fi
        fi
    fi

    if ls -al /dev/loop7 > /dev/null 2>&1; then
        if losetup /dev/loop7; then
            imgs=("emby-ailg.img" "emby-ailg-lite.img" "jellyfin-ailg.img" "jellyfin-ailg-lite.img" "emby-ailg-115.img" "emby-ailg-lite-115.img" "media.img" "/")
            contains=false
            for img in "${imgs[@]}"; do
                if [ "$img" = "/" ]; then
                    if losetup /dev/loop7 | grep -q "^/$"; then
                        contains=true
                        break
                    fi
                else
                    if losetup /dev/loop7 | grep -q "$img"; then
                        contains=true
                        break
                    fi
                fi
            done

            if [ "$contains" = false ]; then
                ERROR "您系统的/dev/loop7设备已被占用，可能是你没有用脚本卸载手动删除了emby的img镜像文件！"
                ERROR "请手动卸载后重装运行脚本安装！不会就删掉爬虫容后重启宿主机设备，再运行脚本安装！" && exit 1
            fi
        else
            for i in {1..3}; do
                curl -o /tmp/loop_test.img https://gbox.ggbond.org/loop_test.img
                if [ -f /tmp/loop_test.img ] && [ $(stat -c%s /tmp/loop_test.img) -gt 1024000 ]; then
                    break
                else
                    rm -f /tmp/loop_test.img
                fi
            done
            if [ ! -f /tmp/loop_test.img ] || [ $(stat -c%s /tmp/loop_test.img) -le 1024000 ]; then
                ERROR "测试文件下载失败，请检查网络后重新运行脚本！" && exit 1
            fi
            if ! losetup -o 35 /dev/loop7 /tmp/loop_test.img > /dev/null 2>&1; then
                ERROR "您的系统环境不支持直接挂载loop回循设备，无法安装速装版emby/jellyfin，建议排查losetup命令后重新运行脚本安装！或用DDS大佬脚本安装原版小雅emby！"
                rm -rf /tmp/loop_test.img
                exit 1
            else
                mkdir -p /tmp/loop_test
                if ! mount /dev/loop7 /tmp/loop_test; then
                    ERROR "您的系统环境不支持直接挂载loop回循设备，无法安装速装版emby/jellyfin，建议排查mount命令后重新运行脚本安装！或用DDS大佬脚本安装原版小雅emby！"
                    rm -rf /tmp/loop_test /tmp/loop_test.img
                    exit 1
                else
                    umount /tmp/loop_test
                    losetup -d /dev/loop7
                    rm -rf /tmp/loop_test /tmp/loop_test.img
                    return 0
                fi
            fi
        fi
    fi
 }

 check_qnap() {
    if grep -Eqi "QNAP" /etc/issue > /dev/null 2>&1; then
        INFO "检测到您是QNAP威联通系统，正在尝试更新安装环境，以便速装emby/jellyfin……"
        
        if ! command -v opkg &> /dev/null; then
            wget -O - http://bin.entware.net/x64-k3.2/installer/generic.sh | sh
            echo 'export PATH=$PATH:/opt/bin:/opt/sbin' >> ~/.profile
            source ~/.profile
        fi

        [ -f /bin/mount ] && mv /bin/mount /bin/mount.bak
        [ -f /bin/umount ] && mv /bin/umount /bin/umount.bak
        [ -f /usr/local/sbin/losetup ] && mv /usr/local/sbin/losetup /usr/local/sbin/losetup.bak

        opkg update

        for pkg in mount-utils losetup; do
            success=false
            for i in {1..3}; do
                if opkg install $pkg; then
                    success=true
                    break
                else
                    INFO "尝试安装 $pkg 失败，重试中 ($i/3)..."
                fi
            done
            if [ "$success" = false ]; then
                INFO "$pkg 安装失败，恢复备份文件并退出脚本。"
                [ -f /bin/mount.bak ] && mv /bin/mount.bak /bin/mount
                [ -f /bin/umount.bak ] && mv /bin/umount.bak /bin/umount
                [ -f /usr/local/sbin/losetup.bak ] && mv /usr/local/sbin/losetup.bak /usr/local/sbin/losetup
                exit 1
            fi
        done

        if [ -f /opt/bin/mount ] && [ -f /opt/bin/umount ] && [ -f /opt/sbin/losetup ]; then
            cp /opt/bin/mount /bin/mount
            cp /opt/bin/umount /bin/umount
            cp /opt/sbin/losetup /usr/local/sbin/losetup
            INFO "已完成安装环境更新！"
        else
            INFO "安装文件缺失，恢复备份文件并退出脚本。"
            [ -f /bin/mount.bak ] && mv /bin/mount.bak /bin/mount
            [ -f /bin/umount.bak ] && mv /bin/umount.bak /bin/umount
            [ -f /usr/local/sbin/losetup.bak ] && mv /usr/local/sbin/losetup.bak /usr/local/sbin/losetup
            exit 1
        fi
    fi
}


function user_select4() {
    down_img() {

        # 先判断是否需要下载，即文件不存在或者存在 aria2 临时文件
        if [[ ! -f $image_dir/$emby_ailg ]] || [[ -f $image_dir/$emby_ailg.aria2 ]]; then
            # 更新 ailg/ggbond:latest 镜像
            update_ailg ailg/ggbond:latest
            # 执行清理操作
            docker exec $docker_name ali_clear -1 > /dev/null 2>&1

            if [[ $ok_115 =~ ^[Yy]$ ]]; then
                # 尝试下载测试文件
                docker run --rm --net=host -v $image_dir:/image ailg/ggbond:latest \
                    aria2c -o /image/test.mp4 --auto-file-renaming=false --allow-overwrite=true -c -x6 "$docker_addr/d/ailg_jf/115/ailg_img/gbox_intro.mp4" > /dev/null 2>&1

                # 判断测试文件是否下载成功
                test_file_size=$(du -b $image_dir/test.mp4 2>/dev/null | cut -f1)
                if [[ ! -f $image_dir/test.mp4.aria2 ]] && [[ $test_file_size -eq 17675105 ]]; then
                    # 测试文件下载成功，删除测试文件
                    rm -f $image_dir/test.mp4
                    use_115_path=true
                else
                    use_115_path=false
                fi
            else
                use_115_path=false
            fi

            if $use_115_path; then
                # 使用 115 路径下载目标文件
                docker run --rm --net=host -v $image_dir:/image ailg/ggbond:latest \
                    aria2c -o /image/$emby_ailg --auto-file-renaming=false --allow-overwrite=true -c -x6 "$docker_addr/d/ailg_jf/115/ailg_img/${down_path}/$emby_ailg"
            else
                # 使用原路径下载目标文件
                docker run --rm --net=host -v $image_dir:/image ailg/ggbond:latest \
                    aria2c -o /image/$emby_ailg --auto-file-renaming=false --allow-overwrite=true -c -x6 "$docker_addr/d/ailg_jf/${down_path}/$emby_ailg"
            fi
        fi

        # 获取本地文件大小
        local_size=$(du -b $image_dir/$emby_ailg | cut -f1)

        # 最多尝试 3 次下载
        for i in {1..3}; do
            if [[ -f $image_dir/$emby_ailg.aria2 ]] || [[ $remote_size -gt "$local_size" ]]; then
                docker exec $docker_name ali_clear -1 > /dev/null 2>&1
                if $use_115_path; then
                    # 使用 115 路径下载目标文件
                    docker run --rm --net=host -v $image_dir:/image ailg/ggbond:latest \
                        aria2c -o /image/$emby_ailg --auto-file-renaming=false --allow-overwrite=true -c -x6 "$docker_addr/d/ailg_jf/115/ailg_img/${down_path}/$emby_ailg"
                else
                    # 使用原路径下载目标文件
                    docker run --rm --net=host -v $image_dir:/image ailg/ggbond:latest \
                        aria2c -o /image/$emby_ailg --auto-file-renaming=false --allow-overwrite=true -c -x6 "$docker_addr/d/ailg_jf/${down_path}/$emby_ailg"
                fi
                local_size=$(du -b $image_dir/$emby_ailg | cut -f1)
            else
                break
            fi
        done

        # 检查文件是否下载完整，若不完整则输出错误信息并退出
        if [[ -f $image_dir/$emby_ailg.aria2 ]] || [[ $remote_size != "$local_size" ]]; then
            ERROR "文件下载失败，请检查网络后重新运行脚本！"
            WARN "未下完的文件存放在${image_dir}目录，以便您续传下载，如不再需要请手动清除！"
            exit 1
        fi
    }

    check_qnap
    check_loop_support
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
        echo -e "\033[1;32m1、小雅EMBY老G速装 - 115完整版\033[0m"
        echo -e "\n"
        echo -e "\033[1;35m2、小雅EMBY老G速装 - 115-Lite版（暂勿安装，待完善）\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m3、小雅JELLYFIN老G速装 - 10.8.13 - 完整版\033[0m"
        echo -e "\n"
        echo -e "\033[1;35m4、小雅JELLYFIN老G速装 - 10.8.13 - Lite版\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m5、小雅JELLYFIN老G速装 - 10.9.6 - 完整版\033[0m"
        echo -e "\n"
        echo -e "\033[1;35m6、小雅JELLYFIN老G速装 - 10.9.6 - Lite版\033[0m"
        echo -e "\n"
        echo -e "\033[1;35m7、小雅EMBY老G速装 - 115-Lite版（4.8.0.56）\033[0m"
        echo -e "\n"
        echo -e "——————————————————————————————————————————————————————————————————————————————————"

        read -erp "请输入您的选择（1-6，按b返回上级菜单或按q退出）：" f4_select
        case "$f4_select" in
        1)
            emby_ailg="emby-ailg-115.mp4"
            emby_img="emby-ailg-115.img"
            space_need=130
            break
            ;;
        2)
            emby_ailg="emby-ailg-lite-115.mp4"
            emby_img="emby-ailg-lite-115.img"
            space_need=120
            break
            ;;
        3)
            emby_ailg="jellyfin-ailg.mp4"
            emby_img="jellyfin-ailg.img"
            space_need=160
            break
            ;;
        4)
            emby_ailg="jellyfin-ailg-lite.mp4"
            emby_img="jellyfin-ailg-lite.img"
            space_need=130
            break
            ;;
        5)
            emby_ailg="jellyfin-10.9.6-ailg.mp4"
            emby_img="jellyfin-10.9.6-ailg.img"
            space_need=160
            break
            ;;
        6)
            emby_ailg="jellyfin-10.9.6-ailg-lite.mp4"
            emby_img="jellyfin-10.9.6-ailg-lite.img"
            space_need=130
            break
            ;;
        7)
            emby_ailg="emby-ailg-lite-115.mp4"
            emby_img="emby-ailg-lite-115.img"
            space_need=125
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
        read -erp '按任意键返回主菜单'
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
    echo -e "\033[1;35m请输入镜像下载后需要扩容的空间（单位：GB，默认60G可直接回车，请确保大于${space_need}G剩余空间！）:\033[0m"
    read -r expand_size
    expand_size=${expand_size:-60}
    # 先询问用户 115 网盘空间是否足够
    read -p "使用115下载镜像请确保cookie正常且网盘剩余空间不低于100G，（按Y/y 确认，按任意键走阿里云盘下载！）: " ok_115
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
    elif [[ "${f4_select}" == [7] ]]; then
        search_img="emby/embyserver|amilys/embyserver"
        del_name="emby"
        loop_order="/dev/loop7"
        down_path="emby/4.8.0.56"
        get_emby_image 4.8.0.56
        init="run"
        emd_name="xiaoya-emd"
        entrypoint_mount="entrypoint_emd"
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
        for entry in "${emby_list[@]}"; do
            op_emby=${entry%%:*} 
            host_path=${entry#*:} 

            docker stop "${op_emby}"
            INFO "${op_emby}容器已关闭！"

            if [[ "${host_path}" =~ .*\.img ]]; then
                mount | grep "${host_path%/*}/emby-xy" && umount "${host_path%/*}/emby-xy" && losetup -d "${loop_order}"
            else
                mount | grep "${host_path%/*}" && umount "${host_path%/*}"
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
        if [[ $ok_115 =~ ^[Yy]$ ]]; then
            remote_size=$(curl -sL -D - -o /dev/null --max-time 10 "$docker_addr/d/ailg_jf/115/ailg_img/${down_path}/$emby_ailg" | grep "Content-Length" | cut -d' ' -f2 | tail -n 1 | tr -d '\r')
        else
            remote_size=$(curl -sL -D - -o /dev/null --max-time 10 "$docker_addr/d/ailg_jf/${down_path}/$emby_ailg" | grep "Content-Length" | cut -d' ' -f2 | tail -n 1 | tr -d '\r')
        fi
        [[ -n $remote_size ]] && echo -e "remotesize is：${remote_size}" && break
    done
    if [[ $remote_size -lt 100000 ]]; then
        ERROR "获取文件大小失败，请检查网络后重新运行脚本！"
        echo -e "${Yellow}排障步骤：\n1、检查5678打开alist能否正常播放（排除token失效和风控！）"
        echo -e "${Yellow}2、检查alist配置目录的docker_address.txt是否正确指向你的alist访问地址，\n   应为宿主机+5678端口，示例：http://192.168.2.3:5678"
        echo -e "${Yellow}3、检查阿里云盘空间，确保剩余空间大于${space_need}G${NC}"
        echo -e "${Yellow}4、如果打开了阿里快传115，确保有115会员且添加了正确的cookie，不是115会员不要打开阿里快传115！${NC}"
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
                exp_ailg "/ailg/$emby_img" "/mount_emby" ${expand_size}
        else
            docker run -i --privileged --rm --net=host -v ${image_dir}:/ailg -v $media_dir:/mount_emby ailg/ggbond:latest \
                exp_ailg "/ailg/$emby_ailg" "/mount_emby" ${expand_size}
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
                -e UID=0 -e GID=0 -e GIDLIST=0 \
                --net=host \
                --privileged --add-host="xiaoya.host:127.0.0.1" --restart always $emby_image
            echo "http://127.0.0.1:6908" > $config_dir/emby_server.txt
            fuck_cors "$emby_name"
        elif [[ "${emby_image}" =~ jellyfin/jellyfin ]]; then
            docker run -d --name $emby_name -v /etc/nsswitch.conf:/etc/nsswitch.conf \
                -v $image_dir/$emby_img:/media.img \
                -v "$image_dir/run_jf":/etc/run_jf \
                --entrypoint "/etc/run_jf" \
                --user 0:0 \
                -e XDG_CACHE_HOME=/config/cache \
                -e LC_ALL=zh_CN.UTF-8 \
                -e LANG=zh_CN.UTF-8 \
                -e LANGUAGE=zh_CN:zh \
                -e JELLYFIN_CACHE_DIR=/config/cache \
                -e HEALTHCHECK_URL=http://localhost:6910/health \
                --net=host \
                --privileged --add-host="xiaoya.host:127.0.0.1" --restart always $emby_image   
            echo "http://127.0.0.1:6910" > $config_dir/jellyfin_server.txt   
        else
            docker run -d --name $emby_name -v /etc/nsswitch.conf:/etc/nsswitch.conf \
                -v $image_dir/$emby_img:/media.img \
                -v "$image_dir/run_jf":/etc/run_jf \
                --entrypoint "/etc/run_jf" \
                --user 0:0 \
                -e XDG_CACHE_HOME=/config/cache \
                -e LC_ALL=zh_CN.UTF-8 \
                -e LANG=zh_CN.UTF-8 \
                -e LANGUAGE=zh_CN:zh \
                -e JELLYFIN_CACHE_DIR=/config/cache \
                -e HEALTHCHECK_URL=http://localhost:6909/health \
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
    INFO "小雅emby请登陆${Blue} $host:2345 ${NC}访问，用户名：${Blue} xiaoya ${NC}，密码：${Blue} 1234 ${NC}"
    INFO "小雅jellyfin请登陆${Blue} $host:2346 ${NC}访问，用户名：${Blue} ailg ${NC}，密码：${Blue} 5678 ${NC}"
    INFO "注：Emby如果$host:6908可访问，而$host:2345访问失败（502/500等错误），按如下步骤排障：\n\t1、检查$config_dir/emby_server.txt文件中的地址是否正确指向emby的访问地址，即：$host:6908或http://127.0.0.1:6908\n\t2、地址正确重启你的小雅alist容器即可。"
    INFO "注：Jellyfin如果$host:6909可访问（10.9.6版本端口为6910），而$host:2346访问失败（502/500等错误），按如下步骤排障：\n\t1、检查$config_dir/jellyfin_server.txt文件中的地址是否正确指向jellyfin的访问地址，即：$host:6909（10.9.6版是6910）或http://127.0.0.1:6909\n\t2、地址正确重启你的小雅alist容器即可。"
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
            remote_sha=$(curl -s -m 20 "https://hub.docker.com/v2/repositories/ddsderek/xiaoya-emd/tags/latest" | grep -oE '[0-9a-f]{64}' | tail -1)
            [ -n "${remote_sha}" ] && break
        done
        local_sha=$(docker inspect -f'{{index .RepoDigests 0}}' "ddsderek/xiaoya-emd:latest" | cut -f2 -d:)
        if [ -z "${local_sha}" ] || [ "${local_sha}" != "${remote_sha}" ];then
            for i in {1..3}; do
                if docker_pull ddsderek/xiaoya-emd:latest; then
                    INFO "ddsderek/xiaoya-emd:latest镜像拉取成功！"
                    break
                fi
            done
            docker images --format '{{.Repository}}:{{.Tag}}' | grep -q ddsderek/xiaoya-emd:latest || (ERROR "ddsderek/xiaoya-emd:latest镜像拉取失败，请检查网络后手动安装！" && exit 1)

            if ! docker cp "${docker_name}":/var/lib/"${entrypoint_mount}" "$image_dir/entrypoint.sh"; then
                if ! curl -o "$image_dir/entrypoint.sh" https://gbox.ggbond.org/${entrypoint_mount}; then
                    ERROR "获取文件失败，请将老G的alist更新到最新版或检查网络后重试。更新方法：重新运行一键脚本，选1重装alist，使用原来的目录！" && exit 1
                fi
            fi
            chmod 777 "$image_dir/entrypoint.sh"
            if docker ps -a | grep -qE " ${emd_name}\b" && docker stop "${emd_name}" && docker rm "${emd_name}"; then
                INFO "${Yellow}已删除您原来的${emd_name}容器！${NC}"
            fi
            #docker_pull ddsderek/xiaoya-emd:latest
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
        else
            if docker ps -a | grep -qE " ${emd_name}\b"; then
                INFO "小雅元数据同步爬虫已安装，无需重复安装！"
                docker start ${emd_name}
            else
                if ! docker cp "${docker_name}":/var/lib/"${entrypoint_mount}" "$image_dir/entrypoint.sh"; then
                    if ! curl -o "$image_dir/entrypoint.sh" https://gbox.ggbond.org/${entrypoint_mount}; then
                        ERROR "获取文件失败，请将老G的alist更新到最新版或检查网络后重试。更新方法：重新运行一键脚本，选1重装alist，使用原来的目录！" && exit 1
                    fi
                fi
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
        fi
    fi
}

fuck_cors() {
    emby_name=${1:-emby}
    docker exec $emby_name sh -c "cp /system/dashboard-ui/modules/htmlvideoplayer/plugin.js /system/dashboard-ui/modules/htmlvideoplayer/plugin.js_backup && sed -i 's/&&(elem\.crossOrigin=initialSubtitleStream)//g' /system/dashboard-ui/modules/htmlvideoplayer/plugin.js"
    docker exec $emby_name sh -c "cp /system/dashboard-ui/modules/htmlvideoplayer/basehtmlplayer.js /system/dashboard-ui/modules/htmlvideoplayer/basehtmlplayer.js_backup && sed -i 's/mediaSource\.IsRemote&&"DirectPlay"===playMethod?null:"anonymous"/null/g' /system/dashboard-ui/modules/htmlvideoplayer/basehtmlplayer.js"
}

general_uninstall() {
    if [ -z "$2" ]; then
        containers=$(docker ps -a --filter "ancestor=${1}" --format "{{.ID}}")
        if [ -n "$containers" ]; then
            INFO "正在卸载${1}镜像的容器..."
            docker rm -f $containers
            INFO "卸载完成。"
        else
            WARN "未安装${1}镜像的容器！"
        fi
    else
        if docker ps -a | grep -qE " ${2}\b"; then
            docker rm -f $2
            INFO "${2}容器卸载完成！"
        else
            WARN "未安装${2}容器！"
        fi
    fi
}

ailg_uninstall() {
    clear
    while true; do
        echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
        echo -e "\n"
        echo -e "\033[1;32m1、卸载老G版alist\033[0m"
        echo -e "\n"
        echo -e "\033[1;35m2、卸载G-Box\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m3、卸载小雅老G速装版EMBY/JELLYFIN\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m4、卸载G-Box内置的Sun-Panel导航\033[0m"
        echo -e "\n"
        echo -e "\033[1;35m5、卸载小雅EMBY老G速装版爬虫\033[0m"
        echo -e "\n"
        echo -e "\033[1;35m6、卸载小雅JELLYFIN老G速装版爬虫\033[0m"
        echo -e "\n"
        echo -e "——————————————————————————————————————————————————————————————————————————————————"

        read -erp "请输入您的选择（1-6，按b返回上级菜单或按q退出）：" uninstall_select
        case "$uninstall_select" in
        1)
            general_uninstall "ailg/alist:latest"
            general_uninstall "ailg/alist:hostmode"
            break
            ;;
        2)
            general_uninstall "ailg/g-box:hostmode"
            break
            ;;
        3)
            img_uninstall
            break
            ;;
        4)
            sp_uninstall
            break
            ;;
        5)
            general_uninstall "ddsderek/xiaoya-emd:latest" "xiaoya-emd"
            break
            ;;
        6)
            general_uninstall "ddsderek/xiaoya-emd:latest" "xiaoya-emd-jf"
            break
            ;;
        [Bb])
            clear
            user_selecto
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
}

sp_uninstall() {
    container=$(docker ps -a --filter "ancestor=ailg/g-box:hostmode" --format "{{.ID}}")
    if [ -n "$container" ]; then
        host_dir=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' $container)       
        if [ -n "$host_dir" ]; then
            echo "uninstall" > "$host_dir/sun-panel.txt"
            if docker exec "$container" test -f /app/sun-panel; then
                INFO "已为您卸载Sun-Panel导航，正在重启g-box容器……"
                docker restart $container
            else
                echo "Sun-Panel导航已经卸载。"
            fi
        else
            ERROR "未能定位到g-box容器的配置文件目录，请确认g-box是否正确安装，程序退出！"
            return 1
        fi
    else
        ERROR "老铁！你还没安装g-box怎么来卸载sun-panel呢？"
        return 1
    fi
}

img_uninstall() {   
    INFO "是否${Red}删除老G速装版镜像文件${NC} [Y/n]（保留请按N/n键，按其他任意键默认删除）"
    read -erp "请输入：" clear_img
    [[ ! "${clear_img}" =~ ^[Nn]$ ]] && clear_img="y"

    # declare -ga img_order
    img_order=()
    search_img="emby/embyserver|amilys/embyserver|nyanmisaka/jellyfin|jellyfin/jellyfin"
    check_qnap
    # check_loop_support
    get_emby_status > /dev/null
    if [ ${#emby_list[@]} -ne 0 ]; then
        for entry in "${emby_list[@]}"; do
            op_emby=${entry%%:*}
            host_path=${entry#*:}

            if docker inspect --format '{{ range .Mounts }}{{ println .Source .Destination }}{{ end }}' "${op_emby}" | grep -qE "\.img /media\.img"; then
                img_order+=("${op_emby}")
            fi
        done

        if [ ${#img_order[@]} -ne 0 ]; then
            echo -e "\033[1;37m请选择你要卸载的老G速装版emby：\033[0m"
            for index in "${!img_order[@]}"; do
                name=${img_order[$index]}
                host_path=""
                for entry in "${emby_list[@]}"; do
                    if [[ $entry == $name:* ]]; then
                        host_path=${entry#*:}
                        break
                    fi
                done
                printf "[ %-1d ] 容器名: \033[1;33m%-20s\033[0m 媒体库路径: \033[1;33m%s\033[0m\n" $((index + 1)) $name $host_path
            done

            while :; do
                read -erp "输入序号：" img_select
                if [ "${img_select}" -gt 0 ] && [ "${img_select}" -le ${#img_order[@]} ]; then
                    emby_name=${img_order[$((img_select - 1))]}
                    img_path=""
                    for entry in "${emby_list[@]}"; do
                        if [[ $entry == $emby_name:* ]]; then
                            img_path=${entry#*:}
                            break
                        fi
                    done

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
    # declare -ga img_order
    img_order=()
    get_emby_happy_image
    check_qnap
    # check_loop_support
    get_emby_status > /dev/null
    if [ ${#emby_list[@]} -ne 0 ]; then
        for entry in "${emby_list[@]}"; do
            op_emby=${entry%%:*}
            host_path=${entry#*:}

            if docker inspect --format '{{ range .Mounts }}{{ println .Source .Destination }}{{ end }}' "${op_emby}" | grep -qE "\.img /media\.img"; then
                img_order+=("${op_emby}")
            fi
        done

        if [ ${#img_order[@]} -ne 0 ]; then
            echo -e "\033[1;37m请选择你要换装/重装开心版的emby！\033[0m"
            for index in "${!img_order[@]}"; do
                name=${img_order[$index]}
                host_path=""
                for entry in "${emby_list[@]}"; do
                    if [[ $entry == $name:* ]]; then
                        host_path=${entry#*:}
                        break
                    fi
                done
                printf "[ %-1d ] 容器名: \033[1;33m%-20s\033[0m 媒体库路径: \033[1;33m%s\033[0m\n" $((index + 1)) $name $host_path
            done

            while :; do
                read -erp "输入序号：" img_select
                if [ "${img_select}" -gt 0 ] && [ "${img_select}" -le ${#img_order[@]} ]; then
                    happy_name=${img_order[$((img_select - 1))]}
                    happy_path=""
                    for entry in "${emby_list[@]}"; do
                        if [[ $entry == $happy_name:* ]]; then
                            happy_path=${entry#*:}
                            break
                        fi
                    done

                    docker rm -f "${happy_name}"
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
                        fuck_cors "${happy_name}"
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
    read -erp "请输入您要挂载的镜像的完整路径：（示例：/volume3/emby/emby-ailg-lite-115.img）" img_path
    img_name=$(basename "${img_path}")
    case "${img_name}" in
    "emby-ailg-115.img" | "emby-ailg-lite-115.img" | "jellyfin-ailg.img" | "jellyfin-ailg-lite.img" | "jellyfin-10.9.6-ailg-lite.img" | "jellyfin-10.9.6-ailg.img") ;;
    *)
        ERROR "您输入的不是老G的镜像，或已改名，确保文件名正确后重新运行脚本！"
        exit 1
        ;;
    esac
    img_mount=${img_path%/*.img}/emby-xy
    # read -p "$(echo img_mount is: $img_mount)"
    check_path ${img_mount}
}

mount_img() {
    # declare -ga img_order
    img_order=()
    search_img="emby/embyserver|amilys/embyserver|nyanmisaka/jellyfin|jellyfin/jellyfin"
    check_qnap
    # check_loop_support
    get_emby_status > /dev/null
    update_ailg ailg/ggbond:latest
    if [ ! -f /usr/bin/mount_ailg ]; then
        docker cp xiaoya_jf:/var/lib/mount_ailg "/usr/bin/mount_ailg"
        chmod 777 /usr/bin/mount_ailg
    fi
    if [ ${#emby_list[@]} -ne 0 ]; then
        for entry in "${emby_list[@]}"; do
            op_emby=${entry%%:*}
            host_path=${entry#*:}

            if docker inspect --format '{{ range .Mounts }}{{ println .Source .Destination }}{{ end }}' "${op_emby}" | grep -qE "\.img /media\.img"; then
                img_order+=("${op_emby}")
            fi
        done

        if [ ${#img_order[@]} -ne 0 ]; then
            echo -e "\033[1;37m请选择你要挂载的镜像：\033[0m"
            for index in "${!img_order[@]}"; do
                name=${img_order[$index]}
                host_path=""
                for entry in "${emby_list[@]}"; do
                    if [[ $entry == $name:* ]]; then
                        host_path=${entry#*:}
                        break
                    fi
                done
                printf "[ %-1d ] 容器名: \033[1;33m%-20s\033[0m 媒体库路径: \033[1;33m%s\033[0m\n" $((index + 1)) $name $host_path
            done
            printf "[ 0 ] \033[1;33m手动输入需要挂载的老G速装版镜像的完整路径\n\033[0m"

            while :; do
                read -erp "输入序号：" img_select
                if [ "${img_select}" -gt 0 ] && [ "${img_select}" -le ${#img_order[@]} ]; then
                    emby_name=${img_order[$((img_select - 1))]}
                    img_path=""
                    for entry in "${emby_list[@]}"; do
                        if [[ $entry == $emby_name:* ]]; then
                            img_path=${entry#*:}
                            break
                        fi
                    done
                    img_mount=${img_path%/*.img}/emby-xy

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

expand_img() {
    # declare -ga img_order
    img_order=()
    search_img="emby/embyserver|amilys/embyserver|nyanmisaka/jellyfin|jellyfin/jellyfin"
    check_qnap
    # check_loop_support
    get_emby_status > /dev/null
    update_ailg ailg/ggbond:latest
    if [ ! -f /usr/bin/mount_ailg ]; then
        docker cp xiaoya_jf:/var/lib/mount_ailg "/usr/bin/mount_ailg"
        chmod 777 /usr/bin/mount_ailg
    fi
    if [ ${#emby_list[@]} -ne 0 ]; then
        for entry in "${emby_list[@]}"; do
            op_emby=${entry%%:*}
            host_path=${entry#*:}

            if docker inspect --format '{{ range .Mounts }}{{ println .Source .Destination }}{{ end }}' "${op_emby}" | grep -qE "\.img /media\.img"; then
                img_order+=("${op_emby}")
            fi
        done

        if [ ${#img_order[@]} -ne 0 ]; then
            echo -e "\033[1;37m请选择你要扩容的镜像：\033[0m"
            for index in "${!img_order[@]}"; do
                name=${img_order[$index]}
                host_path=""
                for entry in "${emby_list[@]}"; do
                    if [[ $entry == $name:* ]]; then
                        host_path=${entry#*:}
                        break
                    fi
                done
                printf "[ %-1d ] 容器名: \033[1;33m%-20s\033[0m 镜像路径: \033[1;33m%s\033[0m\n" $((index + 1)) $name $host_path
            done
            printf "[ 0 ] \033[1;33m手动输入需要扩容的老G速装版镜像的完整路径\n\033[0m"

            while :; do
                read -erp "输入序号：" img_select
                WARN "注：扩容后的镜像体积不能超过物理磁盘空间的70%！当前安装完整小雅emby扩容后镜像不低于160G！建议扩容至200G及以上！"
                read -erp "输入您要扩容的大小（单位：GB）：" expand_size
                if [ "${img_select}" -gt 0 ] && [ "${img_select}" -le ${#img_order[@]} ]; then
                    emby_name=${img_order[$((img_select - 1))]}
                    img_path=""
                    for entry in "${emby_list[@]}"; do
                        if [[ $entry == $emby_name:* ]]; then
                            img_path=${entry#*:}
                            break
                        fi
                    done
                    img_mount=${img_path%/*.img}/emby-xy

                    expand_diy_img_path
                    break
                elif [ "${img_select}" -eq 0 ]; then
                    get_img_path
                    expand_diy_img_path
                    losetup -d "${loop_order}" > /dev/null 2>&1
                    break
                else
                    ERROR "您输入的序号无效，请输入一个在 0 到 ${#img_order[@]} 的数字。"
                fi
            done
        else
            get_img_path
            expand_diy_img_path
            losetup -d "${loop_order}" > /dev/null 2>&1
        fi
    else
        get_img_path
        expand_diy_img_path
        losetup -d "${loop_order}" > /dev/null 2>&1
    fi
}

expand_diy_img_path() { 
    image_dir="$(dirname "${img_path}")"
    emby_img="$(basename "${img_path}")"
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
    docker run -i --privileged --rm --net=host -v ${image_dir}:/ailg -v ${img_mount}:/mount_emby ailg/ggbond:latest \
        exp_ailg "/ailg/$emby_img" "/mount_emby" ${expand_size}
    [ $? -eq 0 ] && docker start ${emby_name} || WARN "如扩容失败，请重启设备手动关闭emby/jellyfin和小雅爬虫容器后重试！"
}

sync_config() {
    if [[ $st_alist =~ "未安装" ]] && [[ $st_gbox =~ "未安装" ]]; then
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
            curl -sSfL -o /tmp/sync_emby_config_ailg.sh https://gbox.ggbond.org/sync_emby_config_img_ailg.sh
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
        echo -e "\033[1;32m1、卸载全在这\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m2、更换开心版小雅EMBY\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m3、挂载老G速装版镜像\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m4、老G速装版镜像重装/同步config\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m5、G-box自动更新/取消自动更新\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m6、速装emby/jellyfin镜像扩容\033[0m"
        echo -e "\n"
        echo -e "\033[1;32m7、修复docker镜像无法拉取（可手动配置镜像代理）\033[0m\033[0m"
        echo -e "\n"
        echo -e "——————————————————————————————————————————————————————————————————————————————————"
        read -erp "请输入您的选择（1-7，按b返回上级菜单或按q退出）：" fo_select
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
        6)
            expand_img
            break
            ;;
        7)
            fix_docker
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

keys="awk jq grep cp mv kill 7z dirname"
values="gawk jq grep coreutils coreutils procps p7zip coreutils"

get_value() {
    key=$1
    keys_array=$(echo $keys)
    values_array=$(echo $values)
    i=1
    for k in $keys_array; do
        if [ "$k" = "$key" ]; then
            set -- $values_array
            eval echo \$$i
            return
        fi
        i=$((i + 1))
    done
    echo "Key not found"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_command() {
    cmd=$1
    # local pkg=${PACKAGE_MAP[$cmd]:-$cmd}
    pkg=$(get_value $cmd)

    if command_exists apt-get; then
        apt-get update && apt-get install -y "$pkg"
    elif command_exists yum; then
        yum install -y "$pkg"
    elif command_exists dnf; then
        dnf install -y "$pkg"
    elif command_exists zypper; then
        zypper install -y "$pkg"
    elif command_exists pacman; then
        pacman -Sy --noconfirm "$pkg"
    elif command_exists brew; then
        brew install "$pkg"
    elif command_exists apk; then
        apk add --no-cache "$pkg"
    else
        echo "无法自动安装 $pkg，请手动安装。"
        return 1
    fi
}

fix_docker() {
    docker_pid() {
        if [ -f /var/run/docker.pid ]; then
            kill -SIGHUP $(cat /var/run/docker.pid)
        elif [ -f /var/run/dockerd.pid ]; then
            kill -SIGHUP $(cat /var/run/dockerd.pid)
        else
            echo "Docker进程不存在，脚本中止执行。"
            if [ "$FILE_CREATED" == false ]; then
                cp $BACKUP_FILE $DOCKER_CONFIG_FILE
                echo -e "\033[1;33m原配置文件：${DOCKER_CONFIG_FILE} 已恢复，请检查是否正确！\033[0m"
            else
                rm -f $DOCKER_CONFIG_FILE
                echo -e "\033[1;31m已删除新建的配置文件：${DOCKER_CONFIG_FILE}\033[0m"
            fi
            return 1
        fi 
    }

    jq_exec() {
        jq --argjson urls "$REGISTRY_URLS_JSON" '
            if has("registry-mirrors") then
                .["registry-mirrors"] = $urls
            else
                . + {"registry-mirrors": $urls}
            end
        ' "$DOCKER_CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$DOCKER_CONFIG_FILE"
    }

    clear
    if ! command_exists "docker"; then
        echo -e $'\033[1;33m你还没有安装docker，请先安装docker，安装后无法拖取镜像再运行脚本！\033[0m'
        echo -e "docker一键安装脚本参考："
        echo -e $'\033[1;32m\tcurl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh\033[0m'
        echo -e "或者："
        echo -e $'\033[1;32m\twget -qO- https://get.docker.com | sh\033[0m'
        exit 1
    fi

    REGISTRY_URLS=('https://hub.rat.dev' 'https://nas.dockerimages.us.kg' 'https://dockerhub.ggbox.us.kg')

    DOCKER_CONFIG_FILE=''
    BACKUP_FILE=''

    REQUIRED_COMMANDS=('awk' 'jq' 'grep' 'cp' 'mv' 'kill')
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command_exists "$cmd"; then
            echo "缺少命令: $cmd，尝试安装..."
            if ! install_command "$cmd"; then
                echo "安装 $cmd 失败，请手动安装后再运行脚本。"
                exit 1
            fi
        fi
    done

    read -p $'\033[1;33m是否使用自定义镜像代理？（y/n）: \033[0m' use_custom_registry
    if [[ "$use_custom_registry" == [Yy] ]]; then
        read -p "请输入自定义镜像代理（示例：https://docker.ggbox.us.kg，多个请用空格分开。直接回车将重置为空）: " -a custom_registry_urls
        if [ ${#custom_registry_urls[@]} -eq 0 ]; then
            echo "未输入任何自定义镜像代理，镜像代理将重置为空。"
            REGISTRY_URLS=()
        else
            REGISTRY_URLS=("${custom_registry_urls[@]}")
        fi
    fi

    echo -e "\033[1;33m正在执行修复，请稍候……\033[0m"

    if [ ${#REGISTRY_URLS[@]} -eq 0 ]; then
        REGISTRY_URLS_JSON='[]'
    else
        REGISTRY_URLS_JSON=$(printf '%s\n' "${REGISTRY_URLS[@]}" | jq -R . | jq -s .)
    fi

    if [ -f /etc/synoinfo.conf ]; then
        DOCKER_ROOT_DIR=$(docker info 2>/dev/null | grep 'Docker Root Dir' | awk -F': ' '{print $2}')
        DOCKER_CONFIG_FILE="${DOCKER_ROOT_DIR%/@docker}/@appconf/ContainerManager/dockerd.json"
    elif command_exists busybox; then
        DOCKER_CONFIG_FILE=$(ps | grep dockerd | awk '{for(i=1;i<=NF;i++) if ($i ~ /^--config-file(=|$)/) {if ($i ~ /^--config-file=/) print substr($i, index($i, "=") + 1); else print $(i+1)}}')
    else
        DOCKER_CONFIG_FILE=$(ps -ef | grep dockerd | awk '{for(i=1;i<=NF;i++) if ($i ~ /^--config-file(=|$)/) {if ($i ~ /^--config-file=/) print substr($i, index($i, "=") + 1); else print $(i+1)}}')
    fi

    DOCKER_CONFIG_FILE=${DOCKER_CONFIG_FILE:-/etc/docker/daemon.json}

    if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
        echo "配置文件 $DOCKER_CONFIG_FILE 不存在，创建新文件。"
        mkdir -p "$(dirname "$DOCKER_CONFIG_FILE")" && echo "{}" > $DOCKER_CONFIG_FILE
        FILE_CREATED=true
    else
        FILE_CREATED=false
    fi

    if [ "$FILE_CREATED" == false ]; then
        BACKUP_FILE="${DOCKER_CONFIG_FILE}.bak"
        cp -f $DOCKER_CONFIG_FILE $BACKUP_FILE
    fi

    jq_exec

    if ! docker_pid; then
        exit 1
    fi

    if [ "$REGISTRY_URLS_JSON" == '[]' ]; then
        echo -e "\033[1;33m已清空镜像代理，不再检测docker连接性，直接退出！\033[0m"
        exit 0
    fi

    docker rmi hello-world:latest >/dev/null 2>&1
    if docker pull hello-world; then
        echo -e "\033[1;32mNice！Docker下载测试成功，配置更新完成！\033[0m"
    else
        echo -e "\033[1;31m哎哟！Docker测试下载失败，恢复原配置文件...\033[0m"
        if [ "$FILE_CREATED" == false ]; then
            cp -f $BACKUP_FILE $DOCKER_CONFIG_FILE
            echo -e "\033[1;33m原配置文件：${DOCKER_CONFIG_FILE} 已恢复，请检查是否正确！\033[0m"
            docker_pid
        else
            REGISTRY_URLS_JSON='[]'
            jq_exec
            docker_pid
            rm -f $DOCKER_CONFIG_FILE
            echo -e "\033[1;31m已删除新建的配置文件：${DOCKER_CONFIG_FILE}\033[0m"
        fi  
    fi
}

function sync_plan() {
    while :; do
        clear
        echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
        echo -e "\n"
        echo -e "\033[1;32m请输入您的选择：\033[0m"
        echo -e "\033[1;32m1、设置G-Box自动更新\033[0m"
        echo -e "\033[1;32m2、取消G-Box自动更新\033[0m"
        echo -e "\033[1;32m3、立即更新G-Box\033[0m"
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
            if [[ -f /etc/synoinfo.conf ]]; then
                sed -i '/xy_install/d' /etc/crontab
                INFO "已取消G-Box自动更新"
            else
                crontab -l | grep -v xy_install > /tmp/cronjob.tmp
                crontab /tmp/cronjob.tmp
                rm -f /tmp/cronjob.tmp
                INFO "已取消G-Box自动更新"
            fi
            exit 0
            ;;
        3)
            docker_name="$(docker ps -a | grep -E 'ailg/g-box' | awk '{print $NF}' | head -n1)"
            if [ -n "${docker_name}" ]; then
                /bin/bash -c "$(curl -sSLf https://gbox.ggbond.org/xy_install.sh)" -s "${docker_name}"
            else
                ERROR "未找到G-Box容器，请先安装G-Box！"
            fi
            exit 0
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
        read -erp "注意：24小时制，格式：\"hh:mm\"，小时分钟之间用英文冒号分隔，示例：23:45）：" sync_time
        read -erp "您希望几天检查一次？（单位：天）" sync_day
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
        echo "$minu $hour */${sync_day} * * /bin/bash -c \"\$(curl -sSLf https://gbox.ggbond.org/xy_install.sh)\" -s "${docker_name}" | tee ${config_dir}/cron.log" >> /tmp/cronjob.tmp
        crontab /tmp/cronjob.tmp
        chmod 777 ${config_dir}/cron.log
        echo -e "\n"
        echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
        echo -e "\n"	
        INFO "已经添加下面的记录到crontab定时任务，每${sync_day}天更新一次${docker_name}镜像"
        echo -e "\033[1;35m"
        grep xy_install /tmp/cronjob.tmp
        echo -e "\033[0m"
        INFO "您可以在 > ${config_dir}/cron.log < 中查看同步执行日志！"
        echo -e "\n"
        echo -e "——————————————————————————————————————————————————————————————————————————————————"
    elif [[ "${is_syno}" == syno ]];then
        cp /etc/crontab /etc/crontab.bak
        echo -e "\033[1;35m已创建/etc/crontab.bak备份文件！\033[0m"
        
        sed -i '/xy_install/d' /etc/crontab
        echo "$minu $hour */${sync_day} * * root /bin/bash -c \"\$(curl -sSLf https://gbox.ggbond.org/xy_install.sh)\" -s "${docker_name}" | tee ${config_dir}/cron.log" >> /etc/crontab
        chmod 777 ${config_dir}/cron.log
        echo -e "\n"
        echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
        echo -e "\n"	
        INFO "已经添加下面的记录到crontab定时任务，每$4天更新一次config"
        echo -e "\033[1;35m"
        grep xy_install /tmp/cronjob.tmp
        echo -e "\033[0m"
        INFO "您可以在 > ${config_dir}/cron.log < 中查看同步执行日志！"
        echo -e "\n"
        echo -e "——————————————————————————————————————————————————————————————————————————————————"
    fi
}

function sync_ailg() {
    if [ "$1" == "g-box" ]; then
        image_name="ailg/g-box:hostmode"
        docker_name="$(docker ps -a | grep -E 'ailg/g-box' | awk '{print $NF}' | head -n1)"
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
        docker rmi "${image_name%:hostmode}:old" > /dev/null 2>&1
        docker tag "${image_name}" "${image_name%:hostmode}:old"
        update_ailg "${image_name}"
        update_status=$?
        if [ ${update_status} -eq 0 ]; then
            new_sha=$(grep "${image_name}" "${config_dir}/ailg_sha.txt" | awk '{print $2}')
            if [ "${current_sha}" = "${new_sha}" ]; then
                echo "$(date): ${image_name} 镜像未更新" >> "${config_dir}/ailg_update.txt"
            else
                echo "$(date): ${image_name} 镜像已升级" >> "${config_dir}/ailg_update.txt"
            fi
            updated="true"
            docker rmi "${image_name%:hostmode}:old"
        else
            ERROR "更新 ${image_name} 镜像失败，将为您恢复旧镜像和容器……"
            docker tag  "${image_name%:hostmode}:old" "${image_name}"
            updated="false"
        fi

        if docker run -d --name "${docker_name}" --net=host --restart=always ${mounts} "${image_name}"; then
            if [ "${updated}" = "true" ]; then
                INFO "Nice!更新成功了哦！"
            else
                WARN "${image_name} 镜像更新失败！已为您恢复旧镜像和容器！请检查网络或配置${config_dir}/docker_mirrors.txt代理文件后再次尝试更新！"
            fi
        else
            WARN "竟然更新失败了！您可能需要重新安装G-Box！"
        fi
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

    read -erp "$(INFO "是否打开docker容器管理功能？（y/n）")" open_warn
    if [[ $open_warn == [Yy] ]]; then
        echo -e "${Yellow}风险警示："
        echo -e "打开docker容器管理功能会挂载/var/run/docker.sock！"
        echo -e "想在G-Box首页Sun-Panel中管理docker容器必须打开此功能！！"
        echo -e "想实现G-Box重启自动更新或添加G-Box自定义挂载必须打开此功能！！"
        echo -e "${Red}打开此功能会获取所有容器操作权限，有一定安全风险，确保您有良好的风险防范意识和妥当操作能力，否则不要打开此功能！！！"
        echo -e "如您已打开此功能想要关闭，请重新安装G-Box，重新进行此项选择！${NC}"
        read -erp "$(WARN "是否继续开启docker容器管理功能？（y/n）")" open_sock
    fi

    # if [[ $open_sock == [Yy] ]]; then
    #     if [ -S /var/run/docker.sock ]; then
    #         docker run -d --name=g-box --net=host \
    #             -v "$config_dir":/data \
    #             -v /var/run/docker.sock:/var/run/docker.sock \
    #             --restart=always \
    #             ailg/g-box:hostmode
    #     else
    #         WARN "您系统不存在/var/run/docker.sock，可能它在其他位置，请定位文件位置后自行挂载，此脚本不处理特殊情况！"
    #         docker run -d --name=g-box --net=host \
    #             -v "$config_dir":/data \
    #             --restart=always \
    #             ailg/g-box:hostmode
    #     fi
    # else
    #     docker run -d --name=g-box --net=host \
    #             -v "$config_dir":/data \
    #             --restart=always \
    #             ailg/g-box:hostmode
    # fi

    local extra_volumes=""
    if [ -s "$config_dir/diy_mount.txt" ]; then
        while IFS=' ' read -r host_path container_path; do
            if [[ -z "$host_path" || -z "$container_path" ]]; then
                continue
            fi

            if [ ! -d "$host_path" ]; then
                WARN "宿主机路径 $host_path 不存在，中止处理 diy_mount.txt 文件"
                extra_volumes=""
                break
            fi

            local reserved_paths=("/app" "/etc" "/sys" "/home" "/mnt" "/bin" "/data" "/dev" "/index" "/jre" "/lib" "/opt" "/proc" "/root" "/run" "/sbin" "/tmp" "/usr" "/var" "/www")
            if [[ " ${reserved_paths[@]} " =~ " $container_path " ]]; then
                WARN "容器路径 $container_path 是内部保留路径，中止处理 diy_mount.txt 文件"
                extra_volumes=""
                break
            fi

            extra_volumes+="-v $host_path:$container_path "
        done < "$config_dir/diy_mount.txt"
    fi

    if [[ $open_sock == [Yy] ]]; then
        if [ -S /var/run/docker.sock ]; then
            extra_volumes+="-v /var/run/docker.sock:/var/run/docker.sock"
        else
            WARN "您系统不存在/var/run/docker.sock，可能它在其他位置，请定位文件位置后自行挂载，此脚本不处理特殊情况！"
        fi
    fi

    mkdir -p "$config_dir/data"
    docker run -d --name=g-box --net=host \
        -v "$config_dir":/data \
        -v "$config_dir/data":/www/data \
        --restart=always \
        $extra_volumes \
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
    INFO "G-Box初始登陆${Green}用户名：admin\t密码：admin ${NC}"
    INFO "内置sun-panel导航初始登陆${Green}用户名：ailg666\t\t密码：12345678 ${NC}"
    if ! grep -q 'alias gbox' /etc/profile; then
        echo -e "alias gbox='bash -c \"\$(curl -sSLf https://gbox.ggbond.org/xy_install.sh)\"'" >> /etc/profile
    fi
    source /etc/profile
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
    echo -e "4、如果您喜欢这个脚本，可以请我喝咖啡：https://gbox.ggbond.org/3q.jpg\033[0m"
    echo -e "————————————————————————————————————\033[1;33m安  装  状  态\033[0m————————————————————————————————"
    echo -e "\e[0m"
    echo -e "G-Box：${st_gbox}      小雅ALIST老G版：${st_alist}     小雅姐夫（jellyfin）：${st_jf}      小雅emby：${st_emby}"
    echo -e "\e[0m"
    echo -e "———————————————————————————————————— \033[1;33mA  I  老  G\033[0m —————————————————————————————————"
    echo -e "\n"
    echo -e "\033[1;35m1、安装/重装小雅ALIST老G版（不再更新，建议安装G-Box替代）\033[0m"
    echo -e "\n"
    echo -e "\033[1;35m2、安装/重装小雅姐夫（非速装版）\033[0m"
    echo -e "\n"
    echo -e "\033[1;35m3、无脑一键全装/重装小雅姐夫（非速装版）\033[0m"
    echo -e "\n"
    echo -e "\033[1;35m4、安装/重装小雅emby/jellyfin（老G速装版）\033[0m"
    echo -e "\n"
    echo -e "\033[1;35m5、安装/重装G-Box（融合小雅alist+tvbox+emby/jellyfin）\033[0m"
    echo -e "\n"
    echo -e "\033[1;35mo、有问题？选我看看\033[0m"
    echo -e "\n"
    echo -e "——————————————————————————————————————————————————————————————————————————————————"
    read -erp "请输入您的选择（1-5或q退出）；" user_select
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
        return 0
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
            # config_dir=$(docker inspect --format '{{ (index .Mounts 0).Source }}' "$container")
            config_dir=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' "$container")
            docker stop "$container"
            docker rm "$container"
            echo "Container $container has been deleted."
        fi
    done
}

choose_mirrors() {
    [ -z "${config_dir}" ] && get_config_path check_docker
    mirrors=(
        docker.io
        hub.rat.dev
        nas.dockerimages.us.kg
        dockerhub.ggbox.us.kg
        docker.aidenxin.xyz
        dockerhub.anzu.vip
        docker.1panel.live
        docker.nastool.de
        docker.adysec.com
    )
    mirror_total_delays=()

    if [ ! -f "${config_dir}/docker_mirrors.txt" ]; then
        echo -e "\033[1;32m正在进行代理测速，为您选择最佳代理……\033[0m"
        start_time=$SECONDS
        for i in "${!mirrors[@]}"; do
            total_delay=0
            success=true
            INFO "${mirrors[i]}代理点测速中……"
            for n in {1..3}; do
                output=$(
                    curl -s -o /dev/null -w '%{time_total}' --head --request GET -m 10 "${mirrors[$i]}"
                    [ $? -ne 0 ] && success=false && break
                )
                total_delay=$(echo "$total_delay + $output" | awk '{print $1 + $3}')
            done
            if $success && docker pull "${mirrors[$i]}/library/hello-world:latest" &> /dev/null; then
                INFO "${mirrors[i]}代理可用，测试完成！"
                mirror_total_delays+=("${mirrors[$i]}:$total_delay")
                docker rmi "${mirrors[$i]}/library/hello-world:latest" &> /dev/null
            else
                INFO "${mirrors[i]}代理测试失败，将继续测试下一代理点！"
            fi
        done

        if [ ${#mirror_total_delays[@]} -eq 0 ]; then
            echo -e "\033[1;31m所有代理测试失败，检查网络或配置可用代理后重新运行脚本，请从主菜单手动退出！\033[0m"
        else
            sorted_mirrors=$(for entry in "${mirror_total_delays[@]}"; do echo $entry; done | sort -t: -k2 -n)
            echo "$sorted_mirrors" | head -n 2 | awk -F: '{print $1}' > "${config_dir}/docker_mirrors.txt"
            echo -e "\033[1;32m已为您选取两个最佳代理点并添加到了${config_dir}/docker_mirrors.txt文件中：\033[0m"
            cat "${config_dir}/docker_mirrors.txt"
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
    read -erp "$(echo -e "\033[1;32m跳过测速将使用您当前网络和环境设置直接拉取镜像，是否跳过？（Y/N）\n\033[0m")" skip_choose_mirror
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${ERROR} 此脚本必须以 root 身份运行！"
        echo -e "${INFO} 请在ssh终端输入命令 'sudo -i' 回车，再输入一次当前用户密码，切换到 root 用户后重新运行脚本。"
        exit 1
    fi
}

emby_list=()
emby_order=()
img_order=()

if [ "$1" == "g-box" ] || [ "$1" == "xiaoya_jf" ]; then
    # config_dir=$(docker inspect --format '{{ (index .Mounts 0).Source }}' "${1}")
    config_dir=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' "${1}")
    [ $? -eq 1 ] && ERROR "您未安装${1}容器" && exit 1
    if [ ! -f "${config_dir}/docker_mirrors.txt" ]; then
        skip_choose_mirror="y"
    fi
    sync_ailg "$1"
elif [ "$1" == "update_data" ]; then
    INFO "正在为你更新小雅的data文件……"
    docker_name="$(docker ps -a | grep -E 'ailg/g-box' | awk '{print $NF}' | head -n1)"
    if [ -n "${docker_name}" ]; then
        files=("version.txt" "index.zip" "update.zip" "tvbox.zip")
        url_base="https://ailg.ggbond.org/"
        download_dir="/www/data"
        docker_container="${docker_name}"

        mkdir -p /tmp/data
        cd /tmp/data
        rm -rf /tmp/data/*

        download_file() {
            local file=$1
            local retries=3
            local success=1

            for ((i=1; i<=retries; i++)); do
                if curl -s -O ${url_base}${file}; then
                    INFO "${file}下载成功"
                    if [[ ${file} == *.zip ]]; then
                        if [[ $(stat -c%s "${file}") -gt 500000 ]]; then
                            success=0
                            break
                        else
                            WARN "${file}文件大小不足，重试..."
                        fi
                    else
                        success=0
                        break
                    fi
                else
                    ERROR "${file}下载失败，重试..."
                fi
            done

            return ${success}
        }

        all_success=1
        for file in "${files[@]}"; do
            if download_file ${file}; then
                docker exec ${docker_container} mkdir -p ${download_dir}
                docker cp ${file} ${docker_container}:${download_dir}
            else
                all_success=0
                ERROR "${file}下载失败，程序退出！"
                exit 1
            fi
        done

        if [[ ${all_success} -eq 1 ]]; then
            INFO "所有文件更新成功，正在为您重启G-Box容器……"
            docker restart ${docker_container}
            INFO "G-Box容器已成功重启，请检查！"
        else
            ERROR "部分文件下载失败，程序退出！"
            exit 1
        fi
    else
        ERROR "未找到G-Box容器，程序退出！"
        exit 1
    fi
else
    fuck_docker
    if ! [[ "$skip_choose_mirror" == [Yy] ]]; then
        choose_mirrors
    fi
    main
fi

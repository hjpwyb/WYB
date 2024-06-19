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

function docker_pull() {
    #[ -z "${config_dir}" ] && get_config_path
    local config_dir=${2:-"/etc/xiaoya"}
    mkdir -p "${config_dir}"
    local mirrors=(“docker.fxxk.dedyn.io”“dockerproxy.com”“docker.chenby.cn”“hub.uuuadc.top”“docker.jsdelivr.fyi“docker.jsdelivr.fyi"“dockertest.jsdelivr.fyi”“docker.registry.cyou"“dockerhub.anzu.vip”“docker.linyubo211.filegear-sg.me”“docker.mirrors.ustc.edu.cn	“docker.nju.edu.cn”“docker.registry.cyou”“docker-cf.registry.cyou”
)
    if [ -s "${config_dir}/docker_mirrors.txt" ]; then
        mirrors=()
        while IFS= read -r line; do
            mirrors+=("$line")
        done < "${config_dir}/docker_mirrors.txt"
    else
        for mirror in "${mirrors[@]}"; do
            printf "%s\n" "$mirror" >> "${config_dir}/docker_mirrors.txt"
        done
    fi

    for mirror in "${mirrors[@]}"; do
        INFO "正在测试${mirror}代理点的连接性……"
        if timeout 30 docker pull "${mirror}/haroldli/xiaoya-tvbox:native"; then
            INFO "${mirror}代理点连通性测试正常！正在为您下载镜像……"
            for i in {1..2}; do
                if timeout 120 docker pull "${mirror}/${1}"; then
                    INFO "${1} 镜像拉取成功！"
                    sed -i "/${mirror}/d" "${config_dir}/docker_mirrors.txt"
                    sed -i "1i ${mirror}" "${config_dir}/docker_mirrors.txt"
                    break;
                else
                    WARN "${1} 镜像拉取失败，正在进行重试..."
                fi
            done
            if [[ "${mirror}" == "docker.io" ]];then
                docker rmi "library/hello-world:latest"
                [ -n "$(docker images -q "${1}")" ] && return 0
            else
                docker rmi "${mirror}/haroldli/xiaoya-tvbox:native"
                [ -n "$(docker images -q "${mirror}/${1}")" ] && break
            fi
        fi
    done

    if [ -n "$(docker images -q "${mirror}/${1}")" ]; then
        docker tag "${mirror}/${1}" "${1}"
        docker rmi "${mirror}/${1}"
        return 0
    else
        ERROR "已尝试所有镜像代理拉取失败，程序退出，请检查网络后再试！"
        exit 1       
    fi
}

if [ -n "$1" ];then
    docker_pull $1 $2
else
    while :; do
        read -erp "请输入您要拉取镜像的完整名字（示例：ailg/alist:latest）：" pull_img
        [ -n "${pull_img}" ] && break
    done
    docker_pull "${pull_img}"
fi

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

# 函数：拉取镜像并统计时间
function docker_pull() {
    local config_dir=${2:-"/etc/xiaoya"}
    local image=$1
    local mirrors=("docker.registry.cyou" "docker-cf.registry.cyou" "docker.jsdelivr.fyi" "dockercf.jsdelivr.fyi" "dockertest.jsdelivr.fyi" "dockerpull.com" "dockerproxy.cn" "hub.uuuadc.top" "docker.1panel.live" "hub.rat.dev" "docker.anyhub.us.kg" "docker.chenby.cn" "dockerhub.jobcher.com" "dockerhub.icu" "docker.ckyl.me" "docker.awsl9527.cn" "docker.hpcloud.cloud" "docker.m.daocloud.io" "docker.linyubo211.filegear-sg.me" "docker.fxxk.dedyn.io" "dockerhub.anzu.vip" "dockerproxy.com" "docker.mirrors.ustc.edu.cn" "docker.nju.edu.cn" "docker.io" "docker.adysec.com")
    
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

    # 存放能下载和不能下载的代理
    local successful_mirrors=()
    local failed_mirrors=()

    # 统计响应时间
    for mirror in "${mirrors[@]}"; do
        start_time=$(date +%s)
        INFO "正在测试${mirror}代理点的连接性……"

        # 测试代理点的连接性
        if timeout 30 docker pull "${mirror}/library/hello-world:latest" > /dev/null 2>&1; then
            end_time=$(date +%s)
            response_time=$((end_time - start_time))
            INFO "${mirror}代理点连通性测试正常！响应时间：${response_time}秒"

            # 记录可用代理，拉取镜像并计算下载时间
            start_time=$(date +%s)
            INFO "正在从${mirror}拉取镜像 ${image}……"
            if timeout 300 docker pull "${mirror}/${image}" > /dev/null 2>&1; then
                end_time=$(date +%s)
                download_time=$((end_time - start_time))
                INFO "镜像 ${image} 成功拉取！下载时间：${download_time}秒"
                successful_mirrors+=("${mirror}")
            else
                WARN "${mirror} 拉取镜像失败"
                failed_mirrors+=("${mirror}")
            fi
        else
            end_time=$(date +%s)
            response_time=$((end_time - start_time))
            ERROR "${mirror} 代理点连通性测试失败！"
            failed_mirrors+=("${mirror}")
        fi
    done

    # 输出测试结果
    INFO "=== 拉取成功的代理 ==="
    for success in "${successful_mirrors[@]}"; do
        echo -e "${Green}${success}${NC}"
    done

    INFO "=== 拉取失败的代理 ==="
    for fail in "${failed_mirrors[@]}"; do
        echo -e "${Red}${fail}${NC}"
    done

    # 返回拉取成功的镜像
    if [ -n "$(docker images -q "${image}")" ]; then
        INFO "${image} 镜像拉取成功!"
        return 0
    else
        ERROR "所有代理均无法拉取镜像 ${image}，程序退出！"
        exit 1
    fi
}

# 主脚本部分
if [ -n "$1" ]; then
    docker_pull $1 $2
else
    while :; do
        read -erp "请输入您要拉取镜像的完整名字（示例：ailg/alist:latest）：" pull_img
        [ -n "${pull_img}" ] && break
    done
    docker_pull "${pull_img}"
fi

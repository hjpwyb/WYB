#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2086

PATH=${PATH}:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/opt/homebrew/bin
export PATH

# 定义颜色变量用于输出
Blue="\033[1;34m"
Green="\033[1;32m"
Red="\033[1;31m"
Yellow="\033[1;33m"
NC="\033[0m"
INFO="[${Green}INFO${NC}]"
ERROR="[${Red}ERROR${NC}]"
WARN="[${Yellow}WARN${NC}]"

# 定义日志输出函数
function INFO() {
    echo -e "${INFO} ${1}"
}

function ERROR() {
    echo -e "${ERROR} ${1}"
}

function WARN() {
    echo -e "${WARN} ${1}"
}

# 定义镜像拉取函数
function docker_pull() {
    local config_dir=${2:-"/etc/xiaoya"}  # 默认配置目录
    mkdir -p "${config_dir}"  # 确保配置目录存在

    # 定义默认的镜像源列表
    local mirrors=(
        "docker.1panel.live"
        "hub.rat.dev"
        "nas.dockerimages.us.kg"
        "dockerhub.ggbox.us.kg"
        "docker.aidenxin.xyz"
        "dockerhub.anzu.vip"
        "docker.nastool.de"
        "docker.adysec.com"
        "hub.uuuadc.top"
        "docker.jsdelivr.fyi"
        "docker.registry.cyou"
        "dockerhub.anzu.vip"
        "docker.luyao.dynv6.net"
        "freeno.xyz"
        "docker.1panel.live"
    )

    # 如果配置文件中存在镜像源列表，则优先使用配置文件中的镜像源
    if [ -s "${config_dir}/docker_mirrors.txt" ]; then
        mirrors=()
        while IFS= read -r line; do
            mirrors+=("$line")
        done < "${config_dir}/docker_mirrors.txt"
    else
        # 将默认镜像源写入配置文件
        for mirror in "${mirrors[@]}"; do
            printf "%s\n" "$mirror" >> "${config_dir}/docker_mirrors.txt"
        done
    fi

    # 检查是否支持 timeout 命令
    if command -v timeout > /dev/null 2>&1; then
        for mirror in "${mirrors[@]}"; do
            INFO "正在测试 ${mirror} 代理点的连接性……"
            if timeout 30 docker pull "${mirror}/library/hello-world:latest"; then
                INFO "${mirror} 代理点连通性测试正常！正在为您下载镜像……"
                for i in {1..2}; do  # 最多重试2次
                    if timeout 300 docker pull "${mirror}/${1}"; then
                        INFO "${1} 镜像拉取成功！"
                        # 更新镜像源列表，将成功的镜像源移至顶部
                        sed -i "/${mirror}/d" "${config_dir}/docker_mirrors.txt"
                        sed -i "1i ${mirror}" "${config_dir}/docker_mirrors.txt"
                        # 标记镜像拉取成功并退出
                        docker tag "${mirror}/${1}" "${1}"  # 重新标记为官方镜像名
                        docker rmi "${mirror}/library/hello-world:latest"  # 清理测试镜像
                        return 0
                    else
                        WARN "${1} 镜像拉取失败，正在进行重试..."
                    fi
                done
            fi
            docker rmi "${mirror}/library/hello-world:latest" > /dev/null 2>&1  # 清理测试镜像
        done
    else
        # 如果系统不支持 timeout 命令，使用后台进程方式实现超时检测
        INFO "系统不支持 timeout 命令，将使用替代方案进行测试。"
        for mirror in "${mirrors[@]}"; do
            INFO "正在测试 ${mirror} 代理点的连接性……"
            docker pull "${mirror}/library/hello-world:latest" &
            pid=$!
            count=0
            while kill -0 $pid 2>/dev/null; do
                sleep 5
                count=$((count + 5))
                if [ $count -ge 30 ]; then
                    echo "Command timed out"
                    kill $pid
                    break
                fi
            done

            if [ $? -eq 0 ]; then
                INFO "${mirror} 代理点连通性测试正常！正在为您下载镜像……"
                docker pull "${mirror}/${1}" &
                pid=$!
                count=0
                while kill -0 $pid 2>/dev/null; do
                    sleep 5
                    count=$((count + 5))
                    if [ $count -ge 300 ]; then
                        echo "Command timed out"
                        kill $pid
                        break
                    fi
                done

                if [ -n "$(docker images -q "${mirror}/${1}")" ]; then
                    INFO "${1} 镜像拉取成功！"
                    docker tag "${mirror}/${1}" "${1}"  # 重新标记为官方镜像名
                    docker rmi "${mirror}/library/hello-world:latest"  # 清理测试镜像
                    return 0
                else
                    WARN "${1} 镜像拉取失败，正在进行重试..."
                fi
            fi
            docker rmi "${mirror}/library/hello-world:latest" > /dev/null 2>&1  # 清理测试镜像
        done
    fi

    # 如果所有镜像源都失败，输出错误信息并退出
    ERROR "已尝试所有镜像代理，但拉取失败，请检查网络后再试！"
    exit 1
}

# 主程序入口
if [ -n "$1" ]; then
    docker_pull "$1" "$2"
else
    while :; do
        read -erp "请输入您要拉取镜像的完整名字（示例：alpine:latest）：" pull_img
        [ -n "${pull_img}" ] && break
    done
    docker_pull "${pull_img}"
fi

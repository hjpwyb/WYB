#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2068
PATH=${PATH}:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/opt/homebrew/bin
export PATH
#
# 鈥斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€�
# __   ___                                    _ _     _
# \ \ / (_)                             /\   | (_)   | |
#  \ V / _  __ _  ___  _   _  __ _     /  \  | |_ ___| |_
#   > < | |/ _` |/ _ \| | | |/ _` |   / /\ \ | | / __| __|
#  / . \| | (_| | (_) | |_| | (_| |  / ____ \| | \__ \ |_
# /_/ \_\_|\__,_|\___/ \__, |\__,_| /_/    \_\_|_|___/\__|
#                       __/ |
#                      |___/
#
# Copyright (c) 2024 DDSRem <https://blog.ddsrem.com>
#
# This is free software, licensed under the Mit License.
#
# 鈥斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€斺€�

Green="\033[32m"
Red="\033[31m"
Yellow='\033[33m'
Font="\033[0m"
INFO="[${Green}INFO${Font}]"
ERROR="[${Red}ERROR${Font}]"
WARN="[${Yellow}WARN${Font}]"
function INFO() {
    echo -e "${INFO} ${1}"
}
function ERROR() {
    echo -e "${ERROR} ${1}"
}
function WARN() {
    echo -e "${WARN} ${1}"
}
if [[ $EUID -ne 0 ]]; then
    ERROR '姝よ剼鏈繀椤讳互 root 韬唤杩愯锛�'
    exit 1
fi
if [ -f /tmp/xiaoya_install.sh ]; then
    rm -rf /tmp/xiaoya_install.sh
fi
if [ -n "${XIAOYA_BRANCH}" ]; then
    if ! curl -sL "https://fastly.jsdelivr.net/gh/DDS-Derek/xiaoya-alist@${XIAOYA_BRANCH}/all_in_one.sh" -o /tmp/xiaoya_install.sh; then
        if ! curl -sL "https://raw.githubusercontent.com/DDS-Derek/xiaoya-alist/${XIAOYA_BRANCH}/all_in_one.sh" -o /tmp/xiaoya_install.sh; then
            ERROR "鑴氭湰鑾峰彇澶辫触锛�"
            exit 1
        else
            bash /tmp/xiaoya_install.sh $@
        fi
    else
        bash /tmp/xiaoya_install.sh $@
    fi
else
    if ! curl -sL https://ddsrem.com/xiaoya/all_in_one.sh -o /tmp/xiaoya_install.sh; then
        if ! curl -sL https://fastly.jsdelivr.net/gh/DDS-Derek/xiaoya-alist@latest/all_in_one.sh -o /tmp/xiaoya_install.sh; then
            if ! curl -sL https://raw.githubusercontent.com/DDS-Derek/xiaoya-alist/master/all_in_one.sh -o /tmp/xiaoya_install.sh; then
                ERROR "鑴氭湰鑾峰彇澶辫触锛�"
                exit 1
            else
                bash /tmp/xiaoya_install.sh $@
            fi
        else
            bash /tmp/xiaoya_install.sh $@
        fi
    else
        bash /tmp/xiaoya_install.sh $@
    fi
fi
if [ -f /tmp/xiaoya_install.sh ]; then
    rm -rf /tmp/xiaoya_install.sh
fi

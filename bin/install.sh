#!/usr/bin/env bash


# usage:
# curl -L https://gitee.com/rainytooo/dotfiles/raw/master/bin/install.sh | bash
# or
# /bin/bash -c "$(curl -fsSL https://gitee.com/rainytooo/dotfiles/raw/master/bin/install.sh)"
# local DEBUG
# 

set -Eeu -o pipefail

REPO_URL="git@gitee.com:rainytooo/dotfiles.git"


# init some variable
LOG_LEVEL="INFO"                  # INFO DEBUG ERROR


# get the real path of this script
WORKPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
echo "your workspace path is $WORKPATH"

# ==================================
# useful variables
# ==================================

# github mirror
# usage:
#   [clone]
#   git clone https://ghproxy.com/https://github.com/stilleshan/ServerStatus
#   [file]
#   wget https://ghproxy.com/https://github.com/stilleshan/ServerStatus/archive/master.zip
#   curl -O https://ghproxy.com/https://github.com/stilleshan/ServerStatus/archive/master.zip
#   [raw content]
#   wget https://ghproxy.com/https://raw.githubusercontent.com/stilleshan/ServerStatus/master/Dockerfile
#   curl -O https://ghproxy.com/https://raw.githubusercontent.com/stilleshan/ServerStatus/master/Dockerfile
GITHUB_PROXY="https://ghproxy.com"


# ==================================
# Detect OS
# ==================================

OS=`uname -s`
OS_MACH=`uname -m`

detect_os(){
    if [ "${OS}" = "Linux" ] ; then
        OS_KERNEL=$(uname -r)
        if [ -f /etc/redhat-release ] ; then
            OS_DIST='RedHat'
            OS_PSEUDONAME=$(sed s/.*\(// < /etc/redhat-release | sed s/\)//)
            OS_REV=$(sed s/.*release\ // < /etc/redhat-release | sed s/\ .*//)
        elif [ -f /etc/SuSE-release ] ; then
            OS_DIST='SuSe'
            # OS_DIST=$(tr "\n" ' ' < /etc/SuSE-release | sed s/VERSION.*//)
            OS_PSEUDONAME=`cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//`
            OS_REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
        elif [ -f /etc/mandrake-release ] ; then
            OS_DIST='Mandrake'
            OS_PSEUDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
            OS_REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
            # OS_PSEUDONAME=$(sed s/.*\(// < /etc/mandrake-release | sed s/\)//)
            # OS_REV=$(sed s/.*release\ // < /etc/mandrake-release | sed s/\ .*//)
        elif [ -f /etc/debian_version ] ; then	
            # if [ "$(awk -F= '/DISTRIB_ID/ {print $2}' /etc/lsb-release)" = "Ubuntu" ]; then
            if [ -f /etc/lsb-release ] ; then
                OS_DIST=`cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }'`
                OS_PSEUDONAME=`cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }'`
                OS_REV=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }'`
            fi
        elif [ -f /etc/arch-release ] ; then
            OS_DIST="Arch"
            OS_PSEUDONAME=""
            OS_REV=""
        fi
        if [ -f /etc/UnitedLinux-release ] ; then
            OS_DIST="${DIST}[$(tr "\n" ' ' < /etc/UnitedLinux-release | sed s/VERSION.*//)]"
            OS_PSEUDONAME=""
            OS_REV=""
        fi
        OS_INFO="${OS} ${OS_DIST} ${OS_REV}(${OS_PSEUDONAME} ${OS_KERNEL} ${OS_MACH})"
        echo ${OS_INFO}
    elif [ "${OS}" == "Darwin" ]; then
        OS_DIST="OSX"
        type -p sw_vers &>/dev/null
        [ $? -eq 0 ] && {
            OS=`sw_vers | grep 'ProductName' | cut -f 2`
            OS_VER=`sw_vers | grep 'ProductVersion' | cut -f 2`
            OS_BUILD=`sw_vers | grep 'BuildVersion' | cut -f 2`
            OS_INFO="Darwin ${OS} ${VER} ${BUILD}"
        } || {
            OS_INFO="MacOSX"
        }
        echo ${OS_INFO}
    else
        echo "Your Operation System not supported!!"
        exit 1
    fi
    lowcase_os_dist="${OS_DIST,,}"
}

# ==================================
# utility functions
# ==================================
# abort and exit
abort() {
  printf "%s\n" "$@"
  exit 1
}
# output formatting
# check if it is standard output
if [[ -t 1 ]]; then
    print_escape() { printf "\033[%sm" "$1"; }
else
    print_escape() { :; }
fi

print_bold()
{
    print_escape "1;$1" ;
}

print_underline()
{
    print_escape "4;$1" ;
}
print_f_red="$(print_bold 31)"
print_f_yellow="$(print_bold 33)"
print_f_blue="$(print_bold 34)"
print_f_green="$(print_bold "38;5;82")" # use the default forceground color
print_f_bold="$(print_bold 39)" # use the default forceground color
print_f_reset="$(print_escape 0)"

# information
log_blue()
{
    printf "${print_f_blue}%s${print_f_reset} \n" "$1"
}
# error
log_red()
{
    printf "${print_f_red}%s${print_f_reset} \n" "$1"
}
# warning
log_yellow()
{
    printf "${print_f_yellow}%s${print_f_reset} \n" "$1"
}
# success
log_green()
{
    printf "${print_f_green}%s${print_f_reset} \n" "$1"
}


log_success()
{
    printf "${print_f_green}[ ok ] ${print_f_reset} %s \n" "$1"
}

# show script usage
usage_help()
{
    # Display Help
    echo "Add description of the script functions here."
    echo
    echo "Syntax: install.sh [-p|h|v|V]"
    echo "options:"
    echo " -p        set the git proxy. eg: http://192.168.0.114:9081"
    echo " -h        Print this Help."
    echo " -v        Verbose mode."
    echo " -V        Print software version and exit."
    echo
}


# ==================================
# setup some environments
# ==================================

check_base_requirement()
{
    # check if user can sudo
    if ! sudo -v &> /dev/null ; then
        log_red "you can not use sudo command, please make sure you can use sudo"
        exit 1
    fi

}

# install package on different OS
install_pkg()
{
    case $lowcase_os_dist in
        'ubuntu')
            sudo apt install git
            ;;
        'arch')
            sudo pacman -Sy git
            ;;
        *)
            echo "i can not help you, you must install $1 manually"
            exit 1
            ;;
    esac
}

# check git installed
init_git()
{
    if ! command -v git 1>/dev/null 2>&1; then
        echo "Git is not installed, now install git " >&2
        install_pkg git
    else
        echo "git already installed"
    fi
    echo "now configure git"
    read -p "enter your name[coco]: > " input_text
    if [ ! -z $input_text -a $input_text != " " ]; then
        git config --global user.name "$input_text"
    else
        log_yellow "you should setup your git config [user.name] later!"
    fi
    read -p "enter your email[ohergal@gmail.com]: > " input_text
    if [ ! -z $input_text -a $input_text != " " ]; then
        git config --global user.email "$input_text"
    else
        log_yellow "you should setup your git config [user.email] later!"
    fi
    # git config --global user.name
    # git config --global user.email
    # git config --global http.proxy

    # common git settings
    git config --global core.autocrlf false
    git config --global core.eol lf
    git config --global pull.rebase true
    git config --global core.editor vim

    # git alias settings
    # git push
    git config --global alias.p 'push'

    # git status
    git config --global alias.st 'status -sb'

    # git log
    git config --global alias.ll 'log --oneline'
    git config --global alias.lla 'log --oneline --decorate --graph --all'

    # last commit
    git config --global alias.last 'log -1 HEAD --stat'

    # git commit
    git config --global alias.cm 'commit'
    git config --global alias.cmm 'commit -m'

    # git checkout
    git config --global alias.co 'checkout'

    # git remote
    git config --global alias.rv 'remote -v'

    # git diff 
    git config --global alias.d 'diff'
    git config --global alias.dv 'difftool -t vimdiff -y'

    # list git global config
    git config --global alias.gl 'config --global -l'

    # git branch
    git config --global alias.br "branch --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(contents:subject) %(color:green)(%(committerdate:relative)) [%(authorname)]' --sort=-committerdate"

    # reset last 
    git config --global alias.undo 'reset HEAD~1 --mixed'
    
    # if necessary set you LANG to en_US.UTF-8 or add : alias git='LANG=en_US.UTF-8 git'
}


run_as_root()
{
    sudo -u root -H bash -c $1
}

# init the package manager
init_pkgm()
{
    case $lowcase_os_dist in
        'ubuntu')
            echo "setup ubuntu apt"
            sudo -u root /bin/bash -c "cat $WORKPATH/../settings/ubuntu/sources.list > /etc/apt/sources.list"
            sudo apt update && sudo apt upgrade -y
            ;;
        'arch')
            echo "setup archlinux pacman, use tsinghua mirror"
            # sudo grep -q 'tsinghua' /etc/pacman.d/mirrorlist
            if grep -q tsinghua /etc/pacman.d/mirrorlist ; then
                echo "tsinghua mirror already existed!"
            else
                echo "tsinghua mirror server not existed, now add it."
                arch_source_tsinghua='Server = https://mirror.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch'
                insert_ln=$(grep -Fn Server /etc/pacman.d/mirrorlist | sed -n  '1p' | cut --delimiter=":" --fields=1)
                sudo sed -i "$insert_ln i $arch_source_tsinghua" /etc/pacman.d/mirrorlist
                unset insert_ln
                unset arch_source_tsinghua
            fi
            echo "now update pacman"
            sudo pacman -Syy
            ;;
        *)
            log_red "You must sync your package manager manually"
            exit 1
            ;;
    esac
}



setup_proxy()
{
    read -p "Do you want to setup proxy:[y(yes)|n(no)] >" input_text
    if [ ! -z $input_text -a $input_text != " " ]; then
        if [[ $input_text == "y" || $input_text == "Y" ]]; then
            echo "Install v2ray for proxy!"
        elif [[ $input_text == "n" || $input_text == "N" ]]; then
            echo "Do not setup proxy right now!"
        else
            :;
        fi
    fi
}

setup_timezone()
{
    log_title "setup timezone!"
    timezone="Asia/shanghai"
    sudo apt install -y tzdata
    sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    run_as_root "echo \"${timezone}\" > /etc/timezone"
    sudo dpkg-reconfigure -f noninteractive tzdata
    # or 
    # sudo timedatectl set-timezone Asia/Shanghai
    timedatectl

}

setup_locale()
{
    log_title "setup locale"
    sudo apt install -y locales \
    && sudo locale-gen en_US.UTF-8 \
    && sudo locale
}

# install basic development kits
install_dev_kits()
{
    log_title "install basic development kits"
    # color_output 1 "Install basic develop tools and libraries!"
    sudo apt install -y build-essential \
    libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev llvm \
    libncurses5-dev libncursesw5-dev  \
    xz-utils tk-dev libffi-dev liblzma-dev python-openssl \
    libmysql++-dev libmysqlclient-dev python-dev
}

# 解析参数 
#   v verbose模式
init_para()
{
    while getopts 'vhp:' script_args; do
        case "$script_args" in
            v)
                LOG_LEVEL="DEBUG";
                ;;
            p)
                echo "set the git proxy."
                git config --global http.proxy ${OPTARG}
                ;;
            h)
                usage_help
                exit 1
                ;;
        esac
    done
}

setup()
{
    # clear
    init_para
    
    log_blue "============================================"
    log_blue "Start initialization"
    log_blue "============================================"

    log_blue "=====> Step 1: Detect you OS infomation"
    detect_os
    log_success "Detect OS success"

    log_blue "=====> Step 2: Check Requirement"
    check_base_requirement
    log_success "Check requirements success"

    log_blue "=====> Step 3: Setup system package manager"
    init_pkgm
    log_success "Setup system package manager success"

    log_blue "=====> Step 4: Setup proxy"
    setup_proxy
    log_success "Setup proxy success"

    log_blue "=====> Step 5: Install and init git"
    init_git
    log_success "Setup git success"
    # install_dev_kits
    # setup_timezone
    # setup_locale
}


setup

# vim:set ft=bash et sts=4 ts=4 sw=4 tw=78:

#!/bin/bash
#
# Steps:
#   1. Collect system information
#   2. Install dependences (skip)
#   3. Download & decompress Python source code (skip)
#   4. make && make install (skip)
#   5. Install virtualenv (skip)
#   6. Install Python tools (skip)


#############
# Functions #
#############

# Usage:
# echo_color -n red "hello my friend"
# echo_color red "hello my friend"
function echo_color() {
    local one_line
    local color
    local text
    local _start
    local _end='\e[0m'
    if [ "$1" == "-n" ]; then
        one_line="True"
        color=$2
        text="$3"
    else
        color=$1
        text="$2"
    fi

    case $color in
        red)
            _start='\e[0;31m'
            ;;
        green)
            _start='\e[0;32m'
            ;;
        yellow)
            _start='\e[0;33m'
            ;;
        blue)
            _start='\e[0;34m'
            ;;
        #*)
    esac

    if [ $one_line ]; then
        echo -n -e "${_start}$text${_end}"
    else
        echo -e "${_start}$text${_end}"
    fi
}


# Usage:
# if (confirm -s "Do you agree?"); then
#     echo 'Bingo!'
# else
#     echo 'F*@k off!'
# fi
function confirm() {
    local use_strict
    local hint
    if [ "$1" == "-s" ]; then
        use_strict="True"
        hint="$2"
    else
        hint="$1"
    fi

    if [ $use_strict ]; then
        while [ ! "$_confirm" ]; do
            echo -n "$hint [y/N]"
            read _confirm
            if [[ "$_confirm" != 'y' && "$_confirm" != 'N' ]]; then
                echo "Please type 'y' or 'N'"
                _confirm=
            fi
        done

        # [[ $_confirm =~ ^[Yy]$ || ! $_confirm ]]
        if [ "$_confirm" == "y" ]; then
            return 0
        else
            return 1
        fi
    else
        echo -n "$hint [y/N]"
        read _confirm
        if [[ "$_confirm" =~ ^[yY]$ || ! "$_confirm" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

function is_installed() {
    apt-cache policy $1 | grep "Installed: (none)"
    if [ $? -eq 0 ]; then
        return 1
    else
        # if the program does not exist, the function will also return 0
        return 0
    fi
}

function install_if_not() {
    local packages=$2
    local to_install
    for i in ${packages[@]}; do
        echo_color yellow "Check $i for $1"
        if ! (is_installed $i); then
            to_install="$i $to_install"
        fi
    done;
    if [ "$to_install" ]; then
        if (confirm "Install additional lib-dev packages for $1?"); then
            sudo apt-get install $to_install
        else
            echo "skip install $to_install"
        fi
    fi
}

# Absolute path for both file and directory
function abspath() {
    if [ -d $1 ]; then
        echo "$(cd $1; pwd)"
    else
        echo "$(cd $(dirname $1); pwd)/$(basename $1)"
    fi
}

# Get real path from tilde mark prefixed path
function realpath() {
    eval _path="$1"
    echo $_path
}

function get_deploy_path() {
    echo_color -n blue "Choose installation folder: "
    read DEPLOY
    if [ ! $DEPLOY ]; then
        get_deploy_path
        return 0
    fi
    DEPLOY=$(realpath $DEPLOY)
    if [ $(dirname $DEPLOY) == "." ]; then
        echo_color red 'Please input an absolute path'
        get_deploy_path
        return 0
    fi
    if [[ -d "$DEPLOY" && "$(ls -A $DEPLOY)" ]]; then
        echo_color red 'Not an empty folder'
        get_deploy_path
        return 0
    fi
    if [ ! -d "$DEPLOY" ]; then
        if (confirm -s "Folder not exists, create?"); then
            mkdir -p $DEPLOY
        else
            get_deploy_path
            return 0
        fi
    fi
    echo "Use path: $DEPLOY"
}

function indicate_python() {
    local python_path
    if [ $DEPLOY ]; then
        export PATH=$DEPLOY/bin:$PATH
    else
        echo -n "Input your python bin directory path: "
        read python_path
        export PATH=$python_path:$PATH
        DEPLOY=$(dirname $python_path)
    fi
    echo_color blue "Your python is $(which python)"
}


##################
# Step functions #
##################

function step_sys_info() {
    echo
    echo_color blue "Step 1. Collect system information"

    echo_color -n blue "Choose python version (2.7.3 - 2.7.6):"
    read -p " 2.7." PYVERSION
    if [ "$PYVERSION" ] && ((3 <= "$PYVERSION" && "$PYVERSION" <= 6)); then
        PYVERSION="2.7.$PYVERSION"
        echo "Use version $PYVERSION"
    else
        PYVERSION="2.7.6"
        echo "Use default version $PYVERSION"
    fi

    # declare some global vars
    SRC_FILE="Python-$PYVERSION.tgz"
    SRC_DIR="Python-$PYVERSION"

    # Check system version
    OS=$(lsb_release -si)
    OSVER=$(lsb_release -sr)
    ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

    echo "System info: OS=$OS, OSVER=$OSVER, ARCH=$ARCH"
}


function step_install_dep() {
    echo
    echo_color blue "Step 2. Install dependences"
    if ! (confirm "Do you want to process this step?"); then
        echo_color yellow "Step 2 skiped"
        return 0
    fi

    # basics
    echo_color yellow "Check build-essential"
    if ! (is_installed "build-essential"); then
        sudo apt-get install build-essential
    fi
    echo_color yellow "Check libpython2.7-dev and python2.7-dev"
    if ! (is_installed "libpython2.7-dev") || ! (is_installed "python2.7-dev"); then
        sudo apt-get build-dep python2.7
        sudo apt-get install python2.7-dev
    fi

    # lib-devs
    LIBDEVS=(
    libncurses5-dev
    libsqlite3-dev
    libbz2-dev
    libreadline-dev
    #libdb5.1-dev
    tcl8.5-dev
    tk8.5-dev
    libssl-dev
    libexpat1-dev
    libreadline6-dev
    )

    for i in ${LIBDEVS[@]}; do
        echo_color yellow "Check $i"
        if ! (is_installed $i); then
            if [ "$LIBDEVS_INSTALLS" ]; then
                LIBDEVS_INSTALLS="$LIBDEVS_INSTALLS $i"
            else
                LIBDEVS_INSTALLS=$i
            fi
        fi
    done
    if [ "$LIBDEVS_INSTALLS" ]; then
        echo "Following libraries wiil be installed: $LIBDEVS_INSTALLS"
        sudo apt-get install $LIBDEVS_INSTALLS
    fi


    ## Install additional dependences for commonly used packages like lxml, MySQLdb
    echo
    install_if_not "lxml" "libxml2-dev libxslt1-dev"

    install_if_not "MySQLdb" "libmysqlclient-dev"
}


function step_download() {
    echo
    echo_color blue "Step 3. Download & decompress Python source code"
    if ! (confirm "Do you want to process this step?"); then
        echo_color yellow "Step 3 skiped"
        return 0
    fi

    local download_path="/tmp/$SRC_FILE"
    local confirm_download

    if [ -e "$download_path" ]; then
        if (confirm -s "File $download_path exists, do you still want to download"); then
            confirm_download="True"
        fi
    else
        confirm_download="True"
    fi

    if [ "$confirm_download" ]; then
        echo_color blue "Start downloading Python $PYVERSION"
        wget -P /tmp "http://python.org/ftp/python/$PYVERSION/$SRC_FILE"
    fi

    echo "Decompress $download_path"
    tar xzf /tmp/$SRC_FILE -C /tmp
}

function step_make_install() {
    echo
    echo_color blue "Step 4. make && make install (skip)"
    if ! (confirm "Do you want to process this step?"); then
        echo_color yellow "Step 4 skiped"
        return 0
    fi

    # Choose installation folder
    get_deploy_path

    #}}} working in /tmp/$SRC_DIR
    echo_color -n blue "pushd: "
    pushd "/tmp/$SRC_DIR"

    local show_output
    if (confirm "Would you like to show outputs of configure, make, make install?"); then
        show_output="True"
    fi

    echo_color green "./configure --prefix=$DEPLOY"
    if [ $show_output ]; then
        ./configure --prefix=$DEPLOY
    else
        echo_color yellow 'NOTE: Outputs of configure are stored at _CONFIGURE.log'
        ./configure --prefix=$DEPLOY 2>&1 > _CONFIGURE.log
    fi

    echo_color green "make $make_extra"
    if [ $show_output ]; then
        make
    else
        echo_color yellow 'NOTE: Outputs of make are stored at _CONFIGURE.log'
        make 2>&1 > _MAKE.log
    fi

    # Check make result, make sure essential packages are able to be installed
    if [ $show_output ]; then
        local hint="Please take a look at the last output of make, to decide whether to going on or stop to install necessary packages?"
        if ! (confirm "$hint"); then
            echo_color yellow "Stop installation, exit"
            exit 0
        fi
    fi

    echo_color green "make install $make_extra"
    if [ $show_output ]; then
        make install
    else
        echo_color yellow 'NOTE: Outputs of make install are stored at _CONFIGURE.log'
        make install 2>&1 > _MAKE.log
    fi

    popd
    #{{{ end working in /tmp/$SRC_DIR

    indicate_python
}


function step_virtualenv() {
    echo
    echo_color blue "Step 5. Install virtualenv (skip)"
    if ! (confirm "Do you want to process this step?"); then
        echo_color yellow "Step 5 skiped"
        return 0
    fi

    indicate_python

    # Install setuptools & pip
    wget https://bitbucket.org/pypa/setuptools/raw/0.8/ez_setup.py -O - | python

    echo_color blue "Your easy_install is $(which easy_install)"

    easy_install pip

    echo_color blue "Your pip is $(which pip)"

    if (confirm "Do you want to use alternative pypi mirrors for pip?"); then
        local mirror
        local conf

        echo "Choose pypi mirrors:"
        echo "  1. http://pypi.douban.com/simple/"
        read mirror
        mirror="http://pypi.douban.com/simple/"

        [ ! -d ~/.pip ] && mkdir ~/.pip

        echo "[global]
index-url=$mirror" > ~/.pip/pip.conf
    fi

    # Install virtualenv & virtualenvwrapper

    pip install virtualenv
    echo_color blue "Your virtualenv is $(which virtualenv)"
    pip install virtualenvwrapper


    echo 'Paste the following lines to your .bashrc or .zshrc to make virtualenvwrapper run properly on shell startup'
    echo
    echo "export PYTHONENV=$DEPLOY
    export PYTHONSTARTUP=\$HOME/.pystartup
    # for virtualenvwrapper
    export VIRTUALENVWRAPPER_PYTHON=\$PYTHONENV/bin/python
    export VIRTUALENVWRAPPER_VIRTUALENV=\$PYTHONENV/bin/virtualenv
    export WORKON_HOME=\$PYTHONENV/virtualenvs
    source \$PYTHONENV/bin/virtualenvwrapper.sh"


    # Test virtualenv & virtualenvwrapper
    mkvirtualenv TEST
    rmvirtualenv TEST
}


function step_other_tools() {
    echo
    echo_color blue "Step 6. Install Python tools (skip)"
    if ! (confirm "Do you want to process this step?"); then
        echo_color yellow "Step 6 skiped"
        return 0
    fi

    indicate_python

    # Install other tools

    # - flake8
    pip install flake8

    # - ipython

    # - bpython

    # - pip-tools

    # - autopep8

    # - pylint
}


function process_steps() {
    # Starts from the step number passed

    local step="$1"
    local single="$2"

    # Step 1.
    if (($step < 2)); then
        step_sys_info
        if [ $single ]; then
            return 0
        fi
    fi

    # Step 2.
    if (($step < 3)); then
        step_install_dep
        if [ $single ]; then
            return 0
        fi
    fi

    # Step 3.
    if (($step < 4)); then
        step_download
        if [ $single ]; then
            return 0
        fi
    fi

    # Step 4.
    if (($step < 5)); then
        step_make_install
        if [ $single ]; then
            return 0
        fi
    fi

    # Step 5.
    if (($step < 6)); then
        step_virtualenv
        if [ $single ]; then
            return 0
        fi
    fi

    # Step 6.
    if (($step < 7)); then
        step_other_tools
        if [ $single ]; then
            return 0
        fi
    fi
}


########
# Main #
########

echo -n "You can:
1. Start from the first step to build a clean python environment.
2. Start from certain step to continue building.
3. Run a single step only.

Choose: "
read start_opt

case $start_opt in
    1)
        process_steps 1
        ;;
    2)
        while [ ! $step_number ]; do
            echo -n "Which step do you want to start from? "
            read step_number
            if ! ((( $step_number )) && (( 1 <= $step_number && $step_number <= 3)));then
                echo "Bad step number"
                step_number=
            fi
        done
        process_steps $step_number
        ;;
    3)
        while [ ! $step_number ]; do
            echo -n "Which step do you want to start from? "
            read step_number
            if ! ((( $step_number )) && (( 1 <= $step_number && $step_number <= 3)));then
                echo "Bad step number"
                step_number=
            fi
        done
        process_steps $step_number single
        ;;
    *)
        echo "Wrong choice, exit"
        ;;
esac

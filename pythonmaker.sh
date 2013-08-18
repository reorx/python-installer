#!/bin/bash

# Functions

MARK_NC='\e[0m'  # No Color
MARK_RED='\e[0;31m'
MARK_GREEN='\e[0;32m'
MARK_BLUE='\e[0;34m'

function echo_red() {
    echo -e "${MARK_RED}$1${MARK_NC}"
}

function echo_green() {
    echo -e "${MARK_GREEN}$1${MARK_NC}"
}

function echo_blue() {
    echo -e "${MARK_BLUE}$1${MARK_NC}"
}


# Choose your python version
echo_blue "Choose python version (2.7.3 - 2.7.5):"
read -p "2.7." PYVERSION
PYVERSION="2.7.$PYVERSION"
echo $PYVERSION

# Check system version
OS=$(lsb_release -si)
OSVER=$(lsb_release -sr)
ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

echo $OS, $OSVER, $ARCH

# Install dependences

## basics

echo_blue "Installing basics"
sudo apt-get install build-essential
sudo apt-get build-dep python2.7

## lib-devs

echo_blue "Checking lib-devs"
LIBDEVS=(
python-dev
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

LIBDEVS_INSTALLS=""
for i in ${LIBDEVS[@]}; do
    greped=$( apt-cache policy $i | grep "Installed: (none)")
    if [ -n "$greped" ]; then
        if [ ! -n "$NEEDINSTALL" ]; then
            LIBDEVS_INSTALLS=$i
        else
            LIBDEVS_INSTALLS="$LIBDEVS_INSTALLS $i"
        fi
    fi
done
echo "Following libraries wiil be installed: $LIBDEVS_INSTALLS"

sudo apt-get install $LIBDEVS_INSTALLS

# Install additional dependences for commonly used packages like lxml, MySQLdb
echo -n -e "${MARK_BLUE}Install additional lib-dev packages for lxml?${MARK_NC}"
read CONFIRM
if [[ $CONFIRM =~ ^[Yy]$ || ! $CONFIRM ]]; then
    sudo apt-get install libxml2-dev libxslt1-dev
fi

echo -n -e "${MARK_BLUE}Install additional lib-dev packages for MySQLdb?${MARK_NC}"
read CONFIRM
if [[ $CONFIRM =~ ^[Yy]$ || ! $CONFIRM ]]; then
    sudo apt-get install libmysqlclient-dev
fi

# Choose installation folder
echo_blue "Choose installation folder"

function get_deploy_path() {
    read DEPLOY
    if [[ -d "$DEPLOY" && "$(ls -A $DEPLOY)" ]]; then
        echo_red 'Not an empty folder'
        get_deploy_path
    fi
    if [ ! -d "$DEPLOY" ]; then
        echo -n -e "${MARK_BLUE}Folder not exists, create?[y/n]${MARK_NC}"
        read CONFIRM
        if [[ $CONFIRM =~ ^[Yy]$ || ! $CONFIRM ]]; then
            mkdir -p $DEPLOY
        else
            get_deploy_path
        fi
    fi
}
get_deploy_path

echo $DEPLOY

exit

# Download & decompress
echo_blue "Start downloading Python $PYVERSION"

wget http://python.org/ftp/python/2.7.X/Python-2.7.X.tgz

# Configure

./configure --prefix=$DEPLOY

# Make

make

# Check make result, make sure essential packages are able to be installed


# Make install

make install

# Check install result

export PATH=$DEPLOY/bin:$PATH
which python

# Install setuptools & pip
wget https://bitbucket.org/pypa/setuptools/raw/0.8/ez_setup.py -O - | python

which easy_install

easy_install pip

which pip

# Install virtualenv & virtualenvwrapper

pip install virtualenv
which virtualenv
pip install virtualenvwrapper


# Echo configs for shell rc

export PYTHONENV=$HOME/Envs/Python
export PYTHONSTARTUP=$HOME/.pystartup
# for virtualenvwrapper
export VIRTUALENVWRAPPER_PYTHON=$PYTHONENV/bin/python
export VIRTUALENVWRAPPER_VIRTUALENV=$PYTHONENV/bin/virtualenv
export WORKON_HOME=$PYTHONENV/virtualenvs
export PROJECT_HOME=$HOME/workspace/current
source $PYTHONENV/bin/virtualenvwrapper.sh


# Test virtualenv & virtualenvwrapper
mkvirtualenv TEST
rmvirtualenv TEST


# Install other tools

# - flake8
pip install flake8

# - ipython

# - bpython

# - pip-tools

# - autopep8

# - pylint


# Done!

#!/bin/bash - 
#===============================================================================
#
#          FILE: ansible_build_telefonica_env.sh
# 
#         USAGE: ./ansible_build_telefonica_env.sh <dir to store ansible>
# 
#   DESCRIPTION: Download ansible repository and modules of Telefonica Cloud
# 
#  REQUIREMENTS: git, curl
#        AUTHOR: zengchen, 
#  ORGANIZATION: Huawei
#       CREATED: 08/16/2018 09:47:44 AM
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error
if [ $# -ne 1 ]; then
    echo "usage: $0"
    echo "       <dir to store ansible>"
    exit 0
fi

if [ -z "$(which git)" ]; then
    echo "Install git first"
    exit 1
fi

if [ -z "$(which curl)" ]; then
    echo "Install curl first"
    exit 1
fi

ansible_dir=$1
if [ ! -d $ansible_dir ] || [ -z "$(ls $ansible_dir)" ]; then
    git clone https://github.com/ansible/ansible.git $ansible_dir
    if [ $? -ne 0 ]; then
        echo "Clone ansible repository failed"
        exit 1
    fi
    cd $ansible_dir
else
    cd $ansible_dir
    repo="$(git remote -v | grep ansible.git)"
    if [ $? -ne 0 ] || [ -z "$repo" ]; then
        echo "$ansible_dir is a pre-created directory without configuring git url of ansible"
        exit 1
    fi

    git checkout devel
    if [ $? -ne 0 ]; then
        echo "Checkout to devel branch failed"
        exit 1
    fi

    git pull
    if [ $? -ne 0 ]; then
        echo "Git pull devel branch failed"
        exit 1
    fi
fi

module_list_file='/tmp/modules.list'
curl https://github.com/zengchen1024/terraform_developing_util/blob/master/utils/ansible/telefonica_modules --create-dirs -o $module_list_file
if [ $? -ne 0 ]; then
    echo "Dowload module list file failed"
    exit 1
fi
while read f
do
    test -z "$f" && continue

    o=$(echo $f | awk -F '/lib/' '{print $NF}')
    curl $f --create-dirs -o lib/$o
    if [ $? -ne 0 ]; then
        echo "Download $f failed"
        exit 1
    fi
done < $module_list_file

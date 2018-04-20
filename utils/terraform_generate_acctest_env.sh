#!/bin/bash

if [ $# -ne 1 ]; then
    echo "usage: $0 dest_cloud_name"
    exit 1
fi

get_config="$(dirname $(which $0))/../config/get_config.sh"

dest_cloud_alias=$1
name=$($get_config name $dest_cloud_alias)
test $? -ne 0 && echo "can not find cloud name: $dest_cloud_alias" && exit 1

acctest_env_dir=""
if [ "$name" = "huaweicloud" ]; then
    acctest_env_dir=/mnt/d/work_space_go/bin/huawei/acc_test_env

elif [ "$name" = "telefonicaopencloud" ]; then
    acctest_env_dir=/mnt/d/work_space_go/bin/telef/acc_test_env

elif [ "$name" = "opentelekomcloud" ]; then
    acctest_env_dir=/mnt/d/work_space_go/bin/otc/acc_test_env

elif [ "$name" = "flexibleengine" ]; then
    acctest_env_dir=/mnt/d/work_space_go/bin/orange/acc_test_env

else
    echo "not supported cloud: $name"
    exit 1
fi

echo ""
cat $acctest_env_dir/acc_test_env
echo ""

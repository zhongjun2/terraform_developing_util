#!/bin/bash

get_config="$(dirname $(which $0))/../config/get_config.sh"

cur_dir=$(pwd)

env=$($get_config where_am_i $cur_dir)
test $? -ne 0 && echo "Can not guess where am i. Go to your code dir and try again" && exit 1

cloud_sdk=$(echo $env | awk -F ':' '{print $1}')
#cloud=$(echo $env | awk -F ':' '{print $2}')
provider_dir=$(echo $env | awk -F ':' '{print $3}')
sdk_dir=$(echo $env | awk -F ':' '{print $4}')

if [ "$cloud_sdk" = "cloud" ]; then
	cd $provider_dir
	echo -e "run make test"
	make test || exit 1

	echo -e "\n\nrun make vet"
	make vet || exit 1

	echo -e "\n\nrun make vendor-status"
	make vendor-status || exit 1
	
	echo -e "\n\nrun make build"
	make build
else
	cd $sdk_dir
	echo -e "run ./script/format"
	./script/format

	echo -e "\n\nrun ./script/coverage"
	./script/coverage
	rm testing_*
	rm cover.out
fi
cd $cur_dir

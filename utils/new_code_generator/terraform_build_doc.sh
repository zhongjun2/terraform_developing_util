#!/bin/bash

if [ $# -lt 5 ]; then
	echo "usage: $0"
	echo "      dest_cloud_name:sdk_dir(the value is like github.com/gophercloud/gophercloud/openstack)"
	echo "      api_doc_dir"
	echo "      resource_name(the name's first character should be capital)"
	echo "      resource_go_file_name"
	echo "      doc_file_name"
	exit 1
fi

tool_dir=$(dirname $(which $0))

cloud_py="$tool_dir/../release/terraform_provider_cloud.py"

dest_cloud=$(echo $1 | awk -F ':' '{print $1}')
dest_cloud1=$(python $cloud_py $dest_cloud name)
test $? -ne 0 && echo "can not find cloud name: $dest_cloud" && exit 1
dest_cloud=$dest_cloud1

dest_cloud_u=$(python $cloud_py $dest_cloud name_of_upper)

code_home_dir=$(python $cloud_py $dest_cloud code_dir)

sdk_dir=$(echo $1 | awk -F ':' '{print $2}')
if [ "$(has_prefix $sdk_dir github.com)" = "no" ]; then
    echo "sdk_dir: $sdk_dir should start with github.com"
    exit 1
fi
sdk_dir=$code_home_dir/vendor/$sdk_dir

req_go_file=$sdk_dir/requests.go
if [ ! -f $req_go_file ]; then
    echo $req_go_file "not exist" && exit 1
fi
req_struct_names=$(grep "type [a-zA-Z0-9_]* struct {" $req_go_file | awk '{print $2}')

resp_go_file=$sdk_dir/results.go
if [ -f $resp_go_file ]; then
    resp_struct_names=$(grep "type [a-zA-Z0-9_]* struct {" $resp_go_file | awk '{print $2}')
fi

out_file=${code_home_dir}/website/docs/r/$5

resouce_go_file_name=$(echo $4 | awk -F '.' '{print $1}')
resource=$(echo ${resouce_go_file_name#resource_})
resource1=$(echo ${resource#${dest_cloud}_})
resource1=$(echo ${resource1//_/-})
resource2=$(echo ${resource//_/\\_})
(
cat << EOF
'head_start
layout: "$dest_cloud"
page_title: "$dest_cloud_u: $resource"
sidebar_current: "docs-${dest_cloud}-resource-$resource1"
description: |-
  Manages resource within
---

# $resource2

Manages resource within

## Example Usage

'head_end
EOF
) > $out_file

echo -e '```hcl\n' >> $out_file
echo '```' >> $out_file

(
cat << EOF
'head_start

## Argument Reference

The following arguments are supported:

'head_end
EOF
) >> $out_file


sed -i '/head_start$/d' $out_file
sed -i '/head_end$/d' $out_file

python ${tool_dir}/convert_document.py $3 $out_file $sdk_dir $2 "$req_struct_names" "$resp_struct_names"
test $? -ne 0 && echo "generate $out_file failed: $err" && exit 1
test ${#err} -gt 0 && echo $err

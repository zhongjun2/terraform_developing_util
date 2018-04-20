#!/bin/bash

if [ $# -lt 3 ]; then
	echo "usage: $0"
	echo "      dest_cloud_name:sdk_dir(the value is like github.com/gophercloud/gophercloud/openstack)"
        echo "      api_doc_dir"
	echo "      create_success_codes:update_success_codes:delete_success_codes:get_success_codes"
	echo "      service_client_version[old | new, default is old]"
	echo "      update_req_method[Post | Put], default is Put"
	echo "      how to do with the old go file[rm | new], default is new"
	exit 1
fi

tool_dir=$(dirname $(which $0))
. $tool_dir/common.sh

cloud_py="$tool_dir/../release/terraform_provider_cloud.py"

dest_cloud=$(echo $1 | awk -F ':' '{print $1}')
dest_cloud1=$(python $cloud_py $dest_cloud name)
test $? -ne 0 && echo "can not find cloud name: $dest_cloud" && exit 1
dest_cloud=$dest_cloud1

code_home_dir=$(python $cloud_py $dest_cloud code_dir)

code_dir=$(echo $1 | awk -F ':' '{print $2}')
if [ "$(has_prefix $code_dir github.com)" = "no" ]; then
    echo "code_dir: $code_dir should start with github.com"
    exit 1
fi
sdk_name=$(echo $code_dir | awk -F '/' '{print $3}')
code_dir=$code_home_dir/vendor/$code_dir

mkdir -p $code_dir
test $? -ne 0 && echo "make dir failed for: $code_dir" && exit 1

api_doc_dir=$2
create_success_codes=$(echo $3 | awk -F ':' '{print $1}')
update_success_codes=$(echo $3 | awk -F ':' '{print $2}')
delete_success_codes=$(echo $3 | awk -F ':' '{print $3}')
get_success_codes=$(echo $3 | awk -F ':' '{print $4}')

if [ $# -eq 3 ]; then
    service_client_version=""
else
    if [ "$4" != "old" ] && [ "$4" != "new" ]; then
	echo "unknown service_client_version: $4"
	exit 1
    fi
    service_client_version=$(test $4 = "new" && echo "Extension" || echo "")
fi

if [ $# -le 4 ]; then
    update_req_method="Put"
else
    if [ "$5" != "Put" ] && [ "$5" != "Post" ]; then
	echo "unknown update_req_method: $5"
	exit 1
    fi
    update_req_method=$5
fi

if [ $# -le 5 ]; then
    treat_old_file="new"
else
    if [ "$6" != "new" ] && [ "$6" != "rm" ]; then
	echo "unknown treat_old_file: $6"
	exit 1
    fi
    treat_old_file=$6
fi

#echo $service_client_version $update_req_method $treat_old_file

req_go_file=$code_dir/requests.go
req_go_file=$(pre_treat_old_file $treat_old_file $req_go_file)

resp_go_file=$code_dir/results.go
resp_go_file=$(pre_treat_old_file $treat_old_file $resp_go_file)

echo $req_go_file $resp_go_file

#echo $(capitalize abc123)
#exit 0

# ------------------------------
resource_name=$(basename $code_dir)

# write the head of $req_go_file

(
cat << EOF
package $resource_name
EOF
) > $req_go_file

# write the head of $resp_go_file

(
cat << EOF
package $resource_name
EOF
) > $resp_go_file

# ------------------------------

req_resp_generator=$tool_dir/convert_request_response.py

# generate requests.go

err=$(python $req_resp_generator "req_create" $req_go_file $api_doc_dir/create.docx $resource_name "$create_success_codes" "$service_client_version")
test $? -ne 0 && echo "generate requests.go of Create failed: $err" && exit 1
test ${#err} -gt 0 && echo $err

err=$(python $req_resp_generator "req_update" $req_go_file $api_doc_dir/update.docx $resource_name "$update_success_codes" "$service_client_version" $update_req_method)
test $? -ne 0 && echo "generate requests.go of Update failed: $err" && exit 1
test ${#err} -gt 0 && echo $err

(
cat << EOF
'func_start

func Get(c *${sdk_name}.ServiceClient${service_client_version}, id string) (r GetResult) {
	_, r.Err = c.Get(resourceURL(c, id), &r.Body, nil)
	return
}

func Delete(c *${sdk_name}.ServiceClient${service_client_version}, id string) (r DeleteResult) {
	reqOpt := &${sdk_name}.RequestOpts{OkCodes: []int{${delete_success_codes}}}
	_, r.Err = c.Delete(resourceURL(c, id), reqOpt)
	return
}
'func_end
EOF
) >> $req_go_file

sed -i '/func_start$/d' $req_go_file
sed -i '/func_end$/d' $req_go_file

# generatte results.go
resource_name_u=$(capitalize $resource_name)

default_result () {
    local op=$1
(
cat << EOF
'head_start
type ${op}Result struct {
	${sdk_name}.Result
}

func (r ${op}Result) Extract() (*${resource_name_u}, error) {
	s := &${resource_name_u}{}
	return s, r.ExtractInto(s)
}
'head_end
EOF
) >> $resp_go_file 
    sed -i '/head_start$/d' $resp_go_file
    sed -i '/head_end$/d' $resp_go_file
}

fs=("get.docx" "create_resp.docx" "update_resp.docx")
for f in ${fs[@]}
do
    fd=$api_doc_dir/$f
    if [ -f $fd ]; then
        python $req_resp_generator "resp" $resp_go_file $fd
        test $? -ne 0 && echo "generate results.go of $fd failed" && exit 1
        test ${#err} -gt 0 && echo $err
    else
	if [ "$f" = "get.docx" ]; then
	    echo -e "type $resource_name_u struct{\n}\n" >> $resp_go_file
	    default_result Get
	elif [ "$f" = "create_resp.docx" ]; then
	    default_result Create
	elif [ "$f" = "update_resp.docx" ]; then
	    default_result Update
	fi
	
    fi
done

echo -e "type DeleteResult struct {\n${sdk_name}.ErrResult\n}\n" >> $resp_go_file

# ------------------------------

sed -i "s/golangsdk/$sdk_name/g" $req_go_file
sed -i "s/golangsdk/$sdk_name/g" $resp_go_file

goimports -w $req_go_file
goimports -w $resp_go_file

gofmt -w $req_go_file
gofmt -w $resp_go_file

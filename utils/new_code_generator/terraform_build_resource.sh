#!/bin/bash

if [ $# -lt 5 ]; then
	echo "usage: $0"
	echo "      dest_cloud_name:sdk_dir(the value is like github.com/gophercloud/gophercloud/openstack)"
	echo "      api_doc_dir"
	echo "      resource_name:child_resource_name(all the two names' first character should be capital)"
	echo "      resource_go_file_name"
	echo "      resource version[v1 | v2]"
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

dest_cloud_u=$(python $cloud_py $dest_cloud name_of_upper)

code_home_dir=$(python $cloud_py $dest_cloud code_dir)

sdk_dir=$(echo $1 | awk -F ':' '{print $2}')
if [ "$(has_prefix $sdk_dir github.com)" = "no" ]; then
    echo "sdk_dir: $sdk_dir should start with github.com"
    exit 1
fi
sdk_dir=$code_home_dir/vendor/$sdk_dir

mkdir -p $sdk_dir
test $? -ne 0 && echo "make dir failed for: $sdk_dir" && exit 1
sdk_dir_name=$(basename $sdk_dir)

req_go_file=$sdk_dir/requests.go
if [ ! -f $req_go_file ]; then
    echo $req_go_file "not exist" && exit 1
fi
req_struct_names=$(grep "type [a-zA-Z0-9_]* struct {" $req_go_file | awk '{print $2}')

resp_go_file=$sdk_dir/results.go
if [ -f $resp_go_file ]; then
    resp_struct_names=$(grep "type [a-zA-Z0-9_]* struct {" $resp_go_file | awk '{print $2}')
fi

api_doc_dir=$2
resource_name=$(echo $3 | awk -F ':' '{print $1}')
child_resource_name=$(echo $3 | awk -F ':' '{print $2}')
resource_go_file=$code_home_dir/$dest_cloud/$4
resource_version=$(capitalize $5)

if [ $# -le 5 ]; then
    treat_old_file="new"
else
    if [ "$6" != "new" ] && [ "$6" != "rm" ]; then
	echo "unknown treat_old_file: $6"
	exit 1
    fi
    treat_old_file=$6
fi
resource_go_file=$(pre_treat_old_file $treat_old_file $resource_go_file)

echo $resource_go_file
echo $resource_version
#exit 0
# ------------------------------

# write the head of $resource_go_file

name="${resource_name}-${child_resource_name}"
method_prefix=resource${resource_name}${child_resource_name}${resource_version}
(
cat << EOF
package $dest_cloud

func ${method_prefix}() *schema.Resource {
	return &schema.Resource{
		Create: ${method_prefix}Create,
		Read:   ${method_prefix}Read,
		Update: ${method_prefix}Update,
		Delete: ${method_prefix}Delete,
		Importer: &schema.ResourceImporter{
			State: schema.ImportStatePassthrough,
		},

		Timeouts: &schema.ResourceTimeout{
			Create: schema.DefaultTimeout(10 * time.Minute),
			Update: schema.DefaultTimeout(10 * time.Minute),
			Delete: schema.DefaultTimeout(5 * time.Minute),
		},

		Schema: map[string]*schema.Schema{
			"region": &schema.Schema{
				Type:     schema.TypeString,
				Optional: true,
				Computed: true,
			},

EOF
) > $resource_go_file

# ------------------------------

generator=$tool_dir/convert_to_schema.py

err=$(python $generator $child_resource_name $resource_go_file $sdk_dir $api_doc_dir "$req_struct_names" "$resp_struct_names")
test $? -ne 0 && echo "generate resource codes failed: $err" && exit 1
test ${#err} -gt 0 && echo $err

get_client_method=choose${resource_name}${resource_version}Client
(
cat << EOF
	}
}
'func_start

func ${method_prefix}Create(d *schema.ResourceData, meta interface{}) error {
	config := meta.(*Config)
	client, err := ${get_client_method}(d, config)
	if err != nil {
		return fmt.Errorf("Error creating $dest_cloud_u client: %s", err)
	}

	var opts $sdk_dir_name.CreateOpts
	err, _ = buildCreateParam(&opts, d)
	if err != nil {
		return fmt.Errorf("Error creating $name: building parameter failed:%s", err)
	}
	log.Printf("[DEBUG] Create $name Options: %#v", opts)

	_, err = $sdk_dir_name.Create(client, opts).Extract()
	if err != nil {
		return fmt.Errorf("Error creating $name: %s", err)
	}

	return fmt.Errorf("error")
	// Wait for ${child_resource_name} to become active before continuing
	//timeout := d.Timeout(schema.TimeoutCreate)

	d.SetId("")

	return ${method_prefix}Read(d, meta)
}

func ${method_prefix}Read(d *schema.ResourceData, meta interface{}) error {
	return fmt.Errorf("error")
	config := meta.(*Config)
	client, err := ${get_client_method}(d, config)
	if err != nil {
		return fmt.Errorf("Error creating $dest_cloud_u client: %s", err)
	}

	r, err := $sdk_dir_name.Get(client, d.Id()).Extract()
	if err != nil {
		return CheckDeleted(d, err, "$name")
	}
	log.Printf("[DEBUG] Retrieved $name %s: %#v", d.Id(), r)

        d.Set("region", GetRegion(d, config))

	return refreshResourceData(r, d)
}

func ${method_prefix}Update(d *schema.ResourceData, meta interface{}) error {
	return fmt.Errorf("error")
	config := meta.(*Config)
	client, err := ${get_client_method}(d, config)
	if err != nil {
		return fmt.Errorf("Error creating $dest_cloud_u client: %s", err)
	}

	rId := d.Id()

	var updateOpts $sdk_dir_name.UpdateOpts
	err, _ = buildUpdateParam(&updateOpts, d)
	if err != nil {
		return fmt.Errorf("Error updating $name %s: building parameter failed:%s", rId, err)
	}

	// Wait for ${child_resource_name} to become active before continuing
	timeout := d.Timeout(schema.TimeoutUpdate)
	/*
	err = waitFor${resource_name}${child_resource_name}Active(client, rId, timeout)
	if err != nil {
		return err
	}*/

	log.Printf("[DEBUG] Updating $name %s with options: %#v", rId, updateOpts)
	err = resource.Retry(timeout, func() *resource.RetryError {
		_, err := $sdk_dir_name.Update(client, rId, updateOpts).Extract()
		if err != nil {
			return checkForRetryableError(err)
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("Error updating $name %s: %s", rId, err)
	}

	// Wait for ${child_resource_name} to become active before continuing

	return ${method_prefix}Read(d, meta)
}

func ${method_prefix}Delete(d *schema.ResourceData, meta interface{}) error {
	return fmt.Errorf("error")
	config := meta.(*Config)
	client, err := ${get_client_method}(d, config)
	if err != nil {
		return fmt.Errorf("Error creating $dest_cloud_u client: %s", err)
	}

	rId := d.Id()
	log.Printf("[DEBUG] Deleting $name %s", rId)

	timeout := d.Timeout(schema.TimeoutDelete)
	err = resource.Retry(timeout, func() *resource.RetryError {
		err := $sdk_dir_name.Delete(client, rId).ExtractErr()
		if err != nil {
			return checkForRetryableError(err)
		}
		return nil
	})
	if err != nil {
		if isResourceNotFound(err) {
			log.Printf("[INFO] deleting an unavailable $name: %s", rId)
			return nil
		}
		return fmt.Errorf("Error deleting $name %s: %s", rId, err)
	}

	return nil
}
'func_end
EOF
) >> $resource_go_file

sed -i '/func_start$/d' $resource_go_file
sed -i '/func_end$/d' $resource_go_file
# ------------------------------

goimports -w $resource_go_file
gofmt -w $resource_go_file

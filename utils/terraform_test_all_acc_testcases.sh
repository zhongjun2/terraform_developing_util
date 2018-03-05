#!/bin/bash

if [ $# -lt 3 ]; then
    echo -e "this util is used to test all acc testcase in a provider or specified test files\n"
    echo "usage: $0"
    echo "  rest_result_dir(record the out put of go test)"
    echo "  action:"
    echo "    filter: show the result of test"
    echo "    test: test all acc tests again"
    echo "    test_new: test all tests which haven't been tested"
    echo "    test_not_success: test all tests which are failed or haven't been tested"
    echo "  test_files:"
    echo "    if it test all test cases in the code repository, input \"\""
    echo "    otherwise specify the test files in the format: \"file1 file2 ..\""
    echo "  [cloud name alias]"
    exit 1
fi

test_files=$3
dest_cloud_alias=$4
if [ -n "$test_files" ] && [ -z "$(echo $test_files | grep _test.go)" ]; then
    echo "invalid test files" && exit 1
fi

common_funcs="$(dirname $(which $0))/common.sh"
. $common_funcs

get_config="$(dirname $(which $0))/../config/get_config.sh"

if [ -n "$dest_cloud_alias" ]; then
    dest_cloud=$($get_config name $dest_cloud_alias)
    test $? -ne 0 && echo "can not find cloud name: $dest_cloud_alias" && exit 1
else
    dest_cloud_alias=$($get_config guess_cloud_alias $(pwd))
    test $? -ne 0 && echo "Can not guess the cloud name, please input cloud name" && exit 1
    dest_cloud=$($get_config name $dest_cloud_alias)
fi

source_dir="$($get_config code_dir $dest_cloud_alias)/$dest_cloud"

test -z "$test_files" && test_files="${source_dir}/*.go"
need_test=$(egrep "\(t \*testing.T\) {" $test_files | awk -F 'func' '{print $2}' | awk -F '(' '{print $1}' | sort)

result=$(get_file_absolute_path $1)
action=$2

filter_a_acc_test() {
    local files="${result}*"
    local test_case=$1
    local success=$(grep "^--- PASS: $test_case" $files)
    local fail=$(grep "^--- FAIL: $test_case" $files)
    local skip=$(grep "^--- SKIP: $test_case" $files)
    local no_test=$(grep -A1 "TF_ACC=1 go test ./$dest_cloud/ -v -run=$test_case" $files | grep "testing: warning: no tests to run")

    if [ -n "$success" ]; then
        echo -e "success: $test_case"
    elif [ -n "$skip" ]; then
        echo -e "skip: $test_case"
    elif [ -n "$no_test" ]; then
        echo -e "no_test: $test_case"
    elif [ -n "$fail" ]; then
        echo -e "fail: $test_case"
    else
        echo -e "other": $test_case
    fi
}

is_need_test() {
    if [ "$action" = "test" ]; then
        echo "yes"
    elif [ "$action" = "test_new" ]; then 
        test -n "$(filter_a_acc_test $1 | grep other)" && echo "yes" && return 0
    elif [ "$action" = "test_not_success" ]; then
        test -n "$(filter_a_acc_test $1 | grep 'fail\|other')" && echo "yes" && return 0
    fi
    echo "no"
}

run_tests() {
    for i in ${need_test[@]}
    do
        echo $i
        if [ "$(is_need_test $i)" = "no" ]; then
            echo -e "  no need test ### $i \n\n";
            continue
        fi

        terraform_test_one_acc_testcase.sh $i $dest_cloud

        echo -e "\n\n"
    done
}

filter() {
    for i in ${need_test[@]}
    do
        filter_a_acc_test $i
    done
}

out_put=$result
if [ ! -f $result ]; then
    touch $result
    if [ $? -ne 0 ]; then
        echo "create $result failed"
        exit 1
    fi
else
    out_put="$(pre_treat_old_file new $result)"
fi

if [ "$action" = "test" ] || [ "$action" = "test_new" ] || [ "$action" = "test_not_success" ]; then
    run_tests > $out_put

elif [ "$action" = "filter" ]; then
    filter | sort -k1

else
    echo "unknown action:$action"
fi
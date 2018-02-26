from collections import namedtuple
import os
import sys
import re


def _normalize_dir(p):
    return "%s/src/%s" % (os.environ.get("GOPATH"), p)


Cloud = namedtuple("Cloud", "name_upper, name_long, code_dir, sdk_dir")

null_cloud = Cloud("", "", "", "")

clouds = {
    "telefonicaopencloud": Cloud("TelefonicaOpenCloud", "telefonica open cloud", _normalize_dir("github.com/huawei-clouds/terraform-provider-telefonicaopencloud"), ""),
    "huaweicloud":         Cloud("HuaweiCloud",         "huawei cloud",          _normalize_dir("github.com/huawei-clouds/terraform-provider-huaweicloud"), _normalize_dir("github.com/huaweicloud/golangsdk")),
    "opentelekomcloud":    Cloud("OpenTelekomCloud",    "open telekom cloud",    _normalize_dir("github.com/huaweicloud/terraform-provider-opentelekomcloud"), ""),
    "flexibleengine":      Cloud("FlexibleEngine",      "flexible engine",       _normalize_dir("github.com/Karajan-project/terraform-provider-flexibleengine"), ""),
}


def get_cloud_name(cloud_name):
    if cloud_name in clouds:
        return (cloud_name, 0)

    for k in clouds:
        m = re.match("^%s" % cloud_name, k)
        if m and m.end() >= 5:
            return (k, 0)
    return ("", 1)


def get_cloud_name_of_upper(cloud_name):
    n = clouds.get(cloud_name, null_cloud).name_upper
    return (n, 0) if n else (n, 1)


def get_cloud_name_of_long(cloud_name):
    n = clouds.get(cloud_name, null_cloud).name_long
    return (n, 0) if n else (n, 1)


def get_cloud_code_dir(cloud_name):
    n = clouds.get(cloud_name, null_cloud).code_dir
    return (n, 0) if n else (n, 1)


def get_cloud_name_by_dir(dir_name):
    for k, v in clouds.items():
        if dir_name.find(v.code_dir) == 0:
            return k, 0
        elif v.sdk_dir and dir_name.find(v.sdk_dir) == 0:
            return k, 0
    return "", 1


def where_am_i(dir_name):
    t = ""
    c = ""
    for k, v in clouds.items():
        if dir_name.find(v.code_dir) == 0:
            t = "cloud"
            c = k
            break
        elif v.sdk_dir and dir_name.find(v.sdk_dir) == 0:
            t = "sdk"
            c = k
            break
    if c:
        n = clouds[c]
        return "%s:%s:%s:%s" % (t, c, n.code_dir, n.sdk_dir), 0
    return "", 1


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(1)

    methods = {
        "name": get_cloud_name,
        "name_of_upper": get_cloud_name_of_upper,
        "name_of_long": get_cloud_name_of_long,
        "code_dir": get_cloud_code_dir,
        "guess_cloud_name": get_cloud_name_by_dir,
        "where_am_i": where_am_i,
    }
    f = methods.get(sys.argv[1])
    if not f:
        sys.exit(1)

    r, c = f(*sys.argv[2:])
    print(r)
    sys.exit(c)

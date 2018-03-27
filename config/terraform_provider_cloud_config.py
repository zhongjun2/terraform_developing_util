from collections import namedtuple
import os
import sys
import re


def _normalize_dir(p):
    return "%s/src/%s" % (os.environ.get("GOPATH"), p)


sdks = {
    "golangsdk": _normalize_dir("github.com/huaweicloud/golangsdk"),
}


Cloud = namedtuple("Cloud", "name, name_upper, name_long, sdk_name, code_dir")

# key is the alias of cloud
clouds = {
    "telefonicaopencloud": Cloud("telefonicaopencloud", "TelefonicaOpenCloud", "telefonica open cloud", "",           _normalize_dir("github.com/huaweicloud/terraform-provider-telefonicaopencloud")),
    "huaweicloud":         Cloud("huaweicloud",         "HuaweiCloud",         "huawei cloud",          "golangsdk",  _normalize_dir("github.com/huaweicloud/terraform-provider-huaweicloud")),
    "opentelekomcloud":    Cloud("opentelekomcloud" ,   "OpenTelekomCloud",    "open telekom cloud",    "",           _normalize_dir("github.com/terraform-providers/terraform-provider-opentelekomcloud")),
    "flexibleengine":      Cloud("flexibleengine",      "FlexibleEngine",      "flexible engine",       "",           _normalize_dir("github.com/huaweicloud/terraform-provider-flexibleengine")),
}


def _get_cloud(cloud_alias):
    c = clouds.get(cloud_alias)
    if c:
        return c

    p = re.compile("^%s" % cloud_alias)
    for k, c in clouds.items():
        m = p.match(k)
        if m and m.end() >= 5:
            return c

    return None


def get_cloud_name(cloud_alias):
    c = _get_cloud(cloud_alias)
    return (c.name, 0) if c else ("", 1)


def get_cloud_name_of_upper(cloud_alias):
    c = _get_cloud(cloud_alias)
    return (c.name_upper, 0) if c else ("", 1)


def get_cloud_name_of_long(cloud_alias):
    c = _get_cloud(cloud_alias)
    return (c.name_long, 0) if c else ("", 1)


def get_cloud_code_dir(cloud_alias):
    c = _get_cloud(cloud_alias)
    return (c.code_dir, 0) if c else ("", 1)


def get_cloud_alias_by_dir(dir_name):
    for k, v in clouds.items():
        if dir_name.find(v.code_dir) == 0:
            return k, 0
    return "", 1


def where_am_i(dir_name):
    for k, v in clouds.items():
        if dir_name.find(v.code_dir) == 0:
            return "cloud:%s:%s" % (k, v.code_dir), 0

    for _, sdk_dir in sdks.items():
        if dir_name.find(sdk_dir) == 0:
            return "sdk::%s" % sdk_dir, 0

    return ("", 1)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(1)

    methods = {
        "name": get_cloud_name,
        "name_of_upper": get_cloud_name_of_upper,
        "name_of_long": get_cloud_name_of_long,
        "code_dir": get_cloud_code_dir,
        "guess_cloud_alias": get_cloud_alias_by_dir,
        "where_am_i": where_am_i,
    }
    f = methods.get(sys.argv[1])
    if not f:
        sys.exit(1)

    r, c = f(*sys.argv[2:])
    print(r)
    sys.exit(c)

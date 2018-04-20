from functools import partial
import sys

import convert_to_schema as cts


class ConvertToDoc(object):

    def run(self, resource_name, out_file, sdk_dir, api_doc_dir, req_struct_names, resp_struct_names):
        schema = cts.ConvertToSchema()
        schema.pre_run(resource_name, sdk_dir, api_doc_dir, req_struct_names, resp_struct_names)

        for r in self._convert(schema._structs):
            self.write_result(out_file, r)

    def _convert(self, structs):
        argu_desc = []
        attr_desc = ["## Attributes Reference\n\nThe following attributes are exported:\n\n"]

        argu_child_struct = []
        attr_child_struct = []
        struct = structs["CreateOpts"]
        for item in struct:
            is_struct = self._is_struct(item)

            if item.opt_kind == cts.OptKindComputed:
                attr_desc.append(self._convert_single_attr(item, is_struct))

                if is_struct:
                    attr_child_struct.append((item.param_type_info.go_type, item.schema_name))
            else:
                attr_desc.append("* `%s` - See Argument Reference above.\n" % item.schema_name)
                argu_desc.append(self._convert_single_argu(item, is_struct))

                if is_struct:
                    argu_child_struct.append((item.param_type_info.go_type, item.schema_name))

        for cs in argu_child_struct:
            argu_desc.extend(self._convert_struct(structs, self._convert_single_argu, *cs))

        for cs in attr_child_struct:
            attr_desc.extend(self._convert_struct(structs, self._convert_single_attr, *cs))

        return argu_desc, attr_desc

    @classmethod
    def _convert_struct(cls, structs, handle, struct_name, schema_name):
        fcs = partial(cls._convert_struct, structs, handle)

        result = []
        result.append("The `%s` block supports:\n\n" % schema_name)

        child_struct = []
        struct = structs[struct_name]
        for item in struct:
            is_struct = cls._is_struct(item)
            result.append(handle(item, is_struct))

            if is_struct:
                child_struct.append((item.param_type_info.go_type, item.schema_name))

        for cs in child_struct:
            result.extend(fcs(*cs))

        return result

    @classmethod
    def write_result(cls, out_file, result):
        fo = None
        try:
            fo = open(out_file, "a")
            for i in result:
                fo.writelines(i)

        except Exception as ex:
            raise Exception("Write %s failed: %s" % (out_file, ex))

        finally:
            if fo:
                fo.close()


    @classmethod
    def _is_struct(cls, item):
        return cts.ConvertToSchema.is_struct(item.param_type_info.type_kind)

    @classmethod
    def split_long_str(cls, s):
        ls = []
        s1 = s
        while s1 != "":
            i = s1.find(" ", 75)
            s2, s1 = (s1, "") if i == -1 else (s1[:i], s1[(i + 1):])
            ls.append(s2)

        return "\n    ".join(ls)


    @classmethod
    def _convert_opt_kind(cls, kind):
        m = {
            cts.OptKindRequired: "Required",
            cts.OptKindOptionalComputed: "Optional",
            cts.OptKindComputed: "Computed",
            cts.OptKindOptional: "Optional",
        }
        return m.get(kind, "")

    @classmethod
    def _convert_single_attr(cls, item, is_struct):
        return cls.split_long_str(
            "* `%(name)s` - %(desc)s%(struct_desc)s\n" % {
                "name": item.schema_name,
                "desc": item.desc,
                "struct_desc": " The structure is described below." if is_struct else "", 
            })

    @classmethod
    def _convert_single_argu(cls, item, is_struct):
        return cls.split_long_str(
            "* `%(name)s` - (%(kind)s) %(des)s%(struct_desc)s\n\n" % {
                'name': item.schema_name,
                "kind": cls._convert_opt_kind(item.opt_kind),
                "des": item.desc,
                "struct_desc": " The structure is described below." if is_struct else "",
            })


if __name__ == "__main__":
    if len(sys.argv) != 7:
        print "usage: python convert_document.py resource_name, out_file, sdk_dir, api_doc_dir, req_struct_names, resp_struct_names"
        sys.exit(0)

    try:
        ConvertToDoc().run(*sys.argv[1:])
    except Exception as ex:
        print("convert document failed: ", ex)
        sys.exit(1)
    sys.exit(0)

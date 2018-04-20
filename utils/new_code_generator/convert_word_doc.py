from collections import namedtuple
import docx
import re


ParamDef = namedtuple("ParamDef", ["param", "mandatory", "param_type", "desc"])


class WordDocPretreatment(object):

    @classmethod
    def req_struct(cls, req_file):
        return cls._read_doc(req_file, cls._convert_req_opt)

    @classmethod
    def resp_struct(cls, resp_file):
        return cls._read_doc(resp_file, cls._convert_resp_opt)

    @classmethod
    def _read_doc(cls, file_name, handle):

        row_desc = None

        def _handle(items):
            try:
                pd = items
                if row_desc:
                    pd = [items[row_desc[p]] if p in row_desc else ""
                         for p in ["parameter", "mandatory", "type", "description"]
                    ]

                #return handle(ParamDef(*pd))
                return ParamDef(
                    pd[0],
                    pd[1].lower(),
                    cls._parse_param_type(pd[2]),
                    pd[3].replace("\n", " "),
                )
            except Exception as ex:
                print "\n!!!!!! convert error:'%s' at file:%s, row: \n    " % (ex, file_name), items
                if not re.match("^ignore:", ex.message):
                    raise ex

        docs = {}
        doc = docx.Document(file_name)

        for table in doc.tables:
            t = []
            tn = ""
            for i, r in enumerate(table.rows):
                items = []
                for c in r.cells:
                    items.append(c.text.replace(u"\xa0", u" "))

                if i == 0:
                    tn = items[0]
                    continue
                elif i == 1 and items[0] == "Parameter":
                    row_desc = {v.lower(): ii for ii, v in enumerate(item)}
                    continue

                node = _handle(items)
                t.append(node)

            cls._check_param_name_in_a_struct(tn, t)
            docs[tn] = t

        return docs

    @classmethod
    def _check_param_name_in_a_struct(cls, struct_name, nodes):
        """all the lowercase parameter names in a struct should be different"""
        names = [i.param.lower() for i in nodes]
        s = set(names)
        if len(s) != len(names):
            ex = Exception("Not All the lowercase parameter names are different!")
            print "\n!!!!!! For struct: %s, %s" % (struct_name, ex)
            raise ex

    @classmethod
    def _convert_resp_opt(cls, ):
        param = items[0]
        #cls._check_param_name(param)

        param_type = cls._parse_param_type(items[1])

        return ParamDef(
            param=param, 
            param_type=param_type,
            desc=items[2].replace("\n", " "),
        )

    @classmethod
    def _convert_req_opt(cls, items):
        param = items[0]
        #cls._check_param_name(param)

        param_type = cls._parse_param_type(items[2])

        return ParamDef(
            param=param, 
            mandatory= items[1].lower(),
            param_type=param_type,
            desc=items[3].replace("\n", " "),
        )

    @classmethod
    def _check_param_name(cls, name):
        m = re.search("[A-Z]", name)
        if m:
            print "\n!!!!!! param:%s has capital character at %d\n" % (name, m.start())

    @classmethod
    def _parse_param_type(cls, type_str):
        type_map = {
            "string":       'string',
            "integer":      'int',
            "boolean":      'bool',
            "list[string]": '[]string',
        }

        l = type_str.lower()
        if l in type_map:
            return type_map[l]

        m = re.match("^list\[object:", l)
        if m:
            return "[]%s" % type_str[m.end():][:-1]

        m = re.match("^object:", l)
        if m:
            return type_str[m.end():]

        raise Exception("Unknown parameter type: %s" % type_str)

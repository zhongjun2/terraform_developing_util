import sys

import convert_word_doc


class Basic(object):

    def __init__(self, go_file, docx_file):
        self._go_file = go_file
        self._docx_file = docx_file
        self._methods = ""

    @classmethod
    def get_param_name(cls, param):
        #w = param.replace("_", ".")
        #w = w.title()
        #return w.replace(".", "")
        items = []
        for i in param.split("_"):
            if i == "id":
                items.append("ID")
            else:
                items.append(i.capitalize())
            #items.append(i[0].capitalize())
            #items.append(i[1:])
        return "".join(items)

    def _write_go_file(self, descs):
        go_file = self._go_file
        fo = None
        try:
            fo = open(go_file, "a")
            for desc in descs:
                fo.writelines(desc)
        except Exception as ex:
            print "\n!!!!!! edit go file:%s error: %s" % (go_file, ex)
            raise ex
        finally:
            if fo:
                fo.close()


    def _generate_opts(self, doc_struct):
        result = []

        for struct_name, nodes in doc_struct.items():

            struct_desc = "type %s struct {\n" % struct_name
            for n in nodes:
                struct_desc += self._convert_an_opt(n)
            struct_desc += "}\n\n"

            result.append(struct_desc)

        return result

    def _read_word_doc(self):
        return None

    def _convert_an_opt(self, node):
        return ""

    def build_go_file(self):
        doc = self._read_word_doc()
        if not doc:
            return

        descs = self._generate_opts(doc)

        if self._methods:
            descs.append(self._methods)

        self._write_go_file(descs)


class ReqOpts(Basic):

    #def __init__(self, go_file, docx_file):
    #    super(ReqOpts, self).__init__(go_file)
    #    self._docx_file = docx_file

    def _read_word_doc(self):
        return convert_word_doc.WordDocPretreatment.req_struct(self._docx_file)

    def _convert_an_opt(self, node):
        templ = {
            "yes": '\t%(name)s %(type)s `json:"%(para)s" required:"true"`\n',
            "no": '\t%(name)s %(type)s `json:"%(para)s,omitempty"`\n',
        }

        return templ[node.mandatory] % {
            'name': self.get_param_name(node.param),
            "type": node.param_type,
            "para": node.param,
        }


class RespOpts(Basic):

    def _read_word_doc(self):
        return convert_word_doc.WordDocPretreatment.resp_struct(self._docx_file)

    def _convert_an_opt(self, node):
        return '%(name)s %(type)s `json:"%(param)s"`\n' % {
            'name': self.get_param_name(node.param),
            "type": node.param_type,
            "param": node.param,
        }


class CreateReqOpts(ReqOpts):
    def __init__(self, go_file, docx_file, resource_name, req_success_codes, service_client_version):
        super(CreateReqOpts, self).__init__(go_file, docx_file)

        self._methods = self._generate_methods(resource_name, req_success_codes, service_client_version)

    def _generate_methods(self, resource_name, req_success_codes, service_client_version):
        return """type CreateOptsBuilder interface {
\tTo%(resource)sCreateMap() (map[string]interface{}, error)
}

func (opts CreateOpts) To%(resource)sCreateMap() (map[string]interface{}, error) {
\treturn golangsdk.BuildRequestBody(opts, "")
}

func Create(c *golangsdk.ServiceClient%(version)s, opts CreateOptsBuilder) (r CreateResult) {
\tb, err := opts.To%(resource)sCreateMap()
\tif err != nil {
\t\tr.Err = err
\t\treturn
\t}
\tlog.Printf("[DEBUG] create url:%%q, body=%%#v", createURL(c), b)
\treqOpt := &golangsdk.RequestOpts{OkCodes: []int{%(success_code)s}}
\t_, r.Err = c.Post(createURL(c), b, &r.Body, reqOpt)
\treturn
}

""" % {"resource": resource_name.capitalize(), "version": service_client_version, "success_code": req_success_codes}


class UpdateReqOpts(ReqOpts):
    def __init__(self, go_file, docx_file, resource_name, req_success_codes, service_client_version, rest_method):
        super(UpdateReqOpts, self).__init__(go_file, docx_file)

        self._methods = self._generate_methods(resource_name, req_success_codes, service_client_version, rest_method)

    def _generate_methods(self, resource_name, req_success_codes, service_client_version, rest_method):
        return """type UpdateOptsBuilder interface {
\tTo%(resource)sUpdateMap() (map[string]interface{}, error)
}

func (opts UpdateOpts) To%(resource)sUpdateMap() (map[string]interface{}, error) {
\treturn golangsdk.BuildRequestBody(opts, "")
}

func Update(c *golangsdk.ServiceClient%(version)s, id string, opts UpdateOptsBuilder) (r UpdateResult) {
\tb, err := opts.To%(resource)sUpdateMap()
\tif err != nil {
\t\tr.Err = err
\t\treturn
\t}
\tlog.Printf("[DEBUG] update url:%%q, body=%%#v", updateURL(c, id), b)
\treqOpt := &golangsdk.RequestOpts{OkCodes: []int{%(success_code)s}}
\t_, r.Err = c.%(method)s(updateURL(c, id), b, &r.Body, reqOpt)
\treturn
}

""" %   {
            "resource": resource_name.capitalize(),
            "version": service_client_version,
            "success_code": req_success_codes,
            "method": rest_method,
        }


if __name__ == "__main__":

    m = {
        "req_create": CreateReqOpts,
        "req_update": UpdateReqOpts,
        "resp": RespOpts
    }
    try:
        m[sys.argv[1]](*sys.argv[2:]).build_go_file()
    except Exception as ex:
        print "run convert_request_response.py failed: %s", ex
        sys.exit(1)
    sys.exit(0)

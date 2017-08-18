inherit .serialization_utils;

protected string scheme;
protected string id;

string get_scheme() {
  return scheme;
}

string get_id() {
  return id;
}

protected variant void create(string _scheme, string _id) {
  scheme = _scheme;
  id = _id;
}

protected variant void create(Stdio.Buffer buf, .ReplyHeader reply_header) {
  scheme = read_string(buf);
  id = read_string(buf);
}

string|Stdio.Buffer encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_string(buf, scheme);
  encode_string(buf, id);
  return buf;
}

protected string _sprintf(int a, void | mapping b) {
  return sprintf("Id(scheme=%s, id=%s)", 
                  scheme, id);
}
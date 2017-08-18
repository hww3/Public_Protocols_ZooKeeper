inherit .Message;

constant MESSAGE_TYPE = "DELETE";
constant MESSAGE_ID = 2;

constant response_program = .EmptyMessage;

string path;
int version;

protected void create(string _path, int _version) {
  path = _path;
  version = _version;
}

string|Stdio.Buffer encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_string(buf, path);
  encode_int32(buf, version);
  return buf;
}
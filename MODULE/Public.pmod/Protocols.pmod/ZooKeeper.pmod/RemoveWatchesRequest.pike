inherit .Message;

constant MESSAGE_TYPE = "CHECKWATCHES";
constant MESSAGE_ID = 3;

constant response_program = .ExistsResponse;

string path;
int type;

protected void create(string _path, int _type) {
  path = _path;
  type = _type;
}

string|Stdio.Buffer encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_string(buf, path);
  encode_int32(buf, type);
  return buf;
}
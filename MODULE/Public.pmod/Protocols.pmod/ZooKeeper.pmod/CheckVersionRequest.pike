inherit .Message;

constant MESSAGE_TYPE = "CHECK";
constant MESSAGE_ID = 13;

constant response_program = .CheckVersionResponse;

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
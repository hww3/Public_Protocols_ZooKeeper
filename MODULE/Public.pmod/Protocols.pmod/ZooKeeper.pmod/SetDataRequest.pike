inherit .Message;

constant MESSAGE_TYPE = "SETDATA";
constant MESSAGE_ID = 5;

constant response_program = .SetDataResponse;

string path;
string data;
int version;

protected void create(string _path, string _data, int _version) {
  path = _path;
  data = _data;
  version = _version;
}

string|Stdio.Buffer encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_string(buf, path);
  encode_buffer(buf, data);
  encode_int32(buf, version);
  return buf;
}
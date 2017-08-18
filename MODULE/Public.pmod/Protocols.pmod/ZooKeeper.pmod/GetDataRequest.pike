inherit .Message;

constant MESSAGE_TYPE = "GETDATA";
constant MESSAGE_ID = 4;

constant response_program = .GetDataResponse;

string path;
boolean watch;

protected void create(string _path, boolean _watch) {
  path = _path;
  watch = _watch;
}

string|Stdio.Buffer encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_string(buf, path);
  encode_byte(buf, watch);
  return buf;
}
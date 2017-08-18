inherit .Message;

constant MESSAGE_TYPE = "GETCHILDREN";
constant MESSAGE_ID = 8;

public program response_program = .GetChildrenResponse;

string path;
boolean watch;

protected void create(string _path, boolean _watch) {
  path = _path;
  watch = _watch;
}

string encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_string(buf, path);
  encode_byte(buf, watch);
  return (string)buf;
}
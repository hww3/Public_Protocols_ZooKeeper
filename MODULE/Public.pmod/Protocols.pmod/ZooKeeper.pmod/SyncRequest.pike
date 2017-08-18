inherit .Message;

constant MESSAGE_TYPE = "SYNC";
constant MESSAGE_ID = 9;

constant response_program = .SyncResponse;

string path;

protected void create(string _path) {
  path = _path;
}

string|Stdio.Buffer encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_string(buf, path);
  return buf;
}
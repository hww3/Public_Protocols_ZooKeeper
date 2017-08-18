inherit .Message;

constant MESSAGE_TYPE = "SYNC";
constant MESSAGE_ID = 9;

public program response_program = .SyncResponse;

string path;

protected void create(string _path) {
  path = _path;
}

string encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_string(buf, path);
  return (string)buf;
}
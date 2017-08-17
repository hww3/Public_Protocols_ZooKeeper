inherit .Message;

constant MESSAGE_TYPE = "GETACL";
constant MESSAGE_ID = 6;

public program response_program = .GetACLResponse;

string path;

protected void create(string _path) {
  path = _path;
}

string encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_string(buf, path);
  return (string)buf;
}
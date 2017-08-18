inherit .Message;

constant MESSAGE_TYPE = "CREATE";
constant MESSAGE_ID = 1;

constant response_program = .CreateResponse;

string path;
string data;
array(.ACL) acls;
int flags;

protected void create(string _path, string _data, array(.ACL) _acls, int _flags) {
  path = _path;
  data = _data;
  acls = _acls;
  flags = _flags;
}

string|Stdio.Buffer encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_string(buf, path);
  encode_string(buf, data);
  encode_int32(buf, sizeof(acls));
  foreach(acls;; .ACL acl) 
    buf->add(acl->encode());
  encode_int32(buf, flags);

  return buf;
}
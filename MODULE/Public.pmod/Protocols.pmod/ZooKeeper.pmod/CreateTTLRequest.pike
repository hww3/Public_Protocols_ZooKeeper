inherit .Message;

constant MESSAGE_TYPE = "CREATETTL";
constant MESSAGE_ID = 15;

constant response_program = .CreateResponse;

string path;
string data;
array(.ACL) acls;
int flags;
int ttl;

protected void create(string _path, string _data, array(.ACL) _acls, int _flags, long _ttl) {
  path = _path;
  data = _data;
  acls = _acls;
  flags = _flags;
  ttl = _ttl;
}

string|Stdio.Buffer encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_string(buf, path);
  encode_string(buf, data);
  encode_int32(buf, sizeof(acls));
  foreach(acls;; .ACL acl) 
    buf->add(acl->encode());
  encode_int32(buf, flags);
  encode_int32(buf, ttl);

  return buf;
}
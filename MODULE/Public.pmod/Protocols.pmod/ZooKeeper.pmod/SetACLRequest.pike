inherit .Message;

constant MESSAGE_TYPE = "SETACL";
constant MESSAGE_ID = 7;

public program response_program = .SetACLResponse;

string path;
array(.ACL) acls;
int version;

protected void create(string _path, array(.ACL) _acls, int _version) {
  path = _path;
  acls = _acls;
  version = _version;
}

string encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_string(buf, path);
  encode_int32(buf, sizeof(acls));
  foreach(acls;; .ACL acl) 
    buf->add(acl->encode());
  encode_int32(buf, version);

  return (string)buf;
}
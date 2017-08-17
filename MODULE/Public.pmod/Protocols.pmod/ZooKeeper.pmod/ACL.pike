inherit .serialization_utils;

protected int perms;
protected .Id id;

int get_perms() {
  return perms;
}

.Id get_id() {
  return id;
}

protected variant void create(int _perms, .Id _id) {
  perms = _perms;
  id = _id;
}

protected variant void create(Stdio.Buffer buf) {
  perms = read_int32(buf);
  id = .Id(buf);
}

protected string _sprintf(int a, void | mapping b) {
  return sprintf("ACL(perms=%d, id=%O)", 
                  perms, id);
}

string encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_int32(buf, perms);
  buf->add(id->encode());
  return (string)buf;
}
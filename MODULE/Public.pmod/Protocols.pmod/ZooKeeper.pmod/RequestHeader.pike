inherit .serialization_utils;

protected int xid;
protected int type;

protected variant void create(int _xid, int _type) {
  xid = _xid;
  type = _type;
}

protected variant void create(Stdio.Buffer buf) {
  xid = read_int32(buf);
  type = read_int32(buf);
}

int get_xid() { return xid; }
int get_type() { return type; }

protected string _sprintf(int a, void | mapping b) {
  return sprintf("RequestHeader(xid=%x, type=%d)", 
                  xid, type);
}
inherit .serialization_utils;

protected int xid;
protected int zxid;
protected int err;

protected void create(Stdio.Buffer buf) {
  xid = read_int32(buf);
  zxid = read_int64(buf);
  err = read_int32(buf);
}

int get_xid() { return xid; }
int get_zxid() { return zxid; }
int get_err() { return err; }

protected string _sprintf(int a, void | mapping b) {
  return sprintf("ReplyHeader(xid=%x, zxid=%x, err=%d)", 
                  xid, zxid, err);
}
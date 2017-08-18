inherit .serialization_utils;

protected int type;
protected boolean done;
protected int err;

protected variant void create(Stdio.Buffer buf, .ReplyHeader header) {
  type = read_int32(buf);
  done = read_byte(buf);
  err = read_int32(buf);
}

protected variant void create(int _type, boolean _done, int _err) {
  type = _type;
  done = _done;
  err = _err;
}

int get_type() { return type; }
boolean get_done() { return done; }
int get_err() { return err; }

string|Stdio.Buffer encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_int32(buf, type);
  encode_byte(buf, done);
  encode_int32(buf, err);
  return buf;
}

protected string _sprintf(int a, void | mapping b) {
  return sprintf("MultiHeader(type=%d, done=%d, err=%d)", 
                  type, done, err);
}
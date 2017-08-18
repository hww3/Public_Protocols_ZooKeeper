inherit .serialization_utils;

protected int type;
protected boolean done;
protected int err;

protected void create(Stdio.Buffer buf) {
  type = read_int32(buf);
  done = read_byte(buf);
  err = read_int32(buf);
}

int get_type() { return type; }
boolean get_done() { return done; }
int get_err() { return err; }

protected string _sprintf(int a, void | mapping b) {
  return sprintf("MultiHeader(type=%d, done=%d, err=%d)", 
                  type, done, err);
}
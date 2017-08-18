inherit .serialization_utils;

protected int type;
protected int state;
protected string path;

string get_path() {
  return path;
}

int get_state() {
  return state;
}

int get_type() {
  return type;
}

protected variant void create(Stdio.Buffer buf, .ReplyHeader reply_header) {
  type = read_int32(buf);
  state = read_int32(buf);
  path = read_string(buf);
 
}

protected string _sprintf(int a, void | mapping b) {
  return sprintf("WatcherEvent(path=%s, type=%d, state=%d)", 
                  path, type, state);
}
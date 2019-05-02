inherit .serialization_utils;

constant MESSAGE_TYPE = "AUTH";
constant MESSAGE_ID = 100;

protected int type;
protected string scheme;
protected string auth;

protected variant void create(int _type, string _scheme, string _auth) {
  type = _type;
  scheme = _scheme;
  auth = _auth;
}

protected variant void create(Stdio.Buffer buf, .ReplyHeader reply_header) {
  type = read_int32(buf);
  scheme = read_string(buf);
  auth = read_buffer(buf);
}

int get_type() { return type; }
string get_scheme() { return scheme; }
string get_auth() { return auth; }

string|Stdio.Buffer encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_int32(buf, type);
  encode_string(buf, scheme);
  encode_string(buf, auth);

  return buf;
}

protected string _sprintf(int a, void | mapping b) {
  return sprintf("AuthPacket(type=%d, scheme=%s, auth=%O)", 
                  type, scheme, auth);
}
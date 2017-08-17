inherit .Message;

public program response_program = .ConnectResponse;

int protocol_version;
int last_zxid_seen;
int time_out;
int session_id;
string passwd;
boolean readonly;

protected void create(int _protocol_version, int _last_zxid_seen, int _timeout, int _session_id, string _passwd, boolean|void _readonly) {
  protocol_version = _protocol_version;
  last_zxid_seen = _last_zxid_seen;
  time_out = _timeout;
  session_id = _session_id;
  passwd = _passwd;
  readonly = _readonly;
}

string encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_int32(buf, protocol_version);
  encode_int64(buf, last_zxid_seen);
  encode_int32(buf, time_out);
  encode_int64(buf, session_id);
  encode_buffer(buf, passwd);
  encode_byte(buf, readonly);

  return (string)buf;
}
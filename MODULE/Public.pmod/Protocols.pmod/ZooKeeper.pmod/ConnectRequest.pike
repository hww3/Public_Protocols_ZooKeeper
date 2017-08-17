inherit .Message;

public program response_program = .ConnectResponse;

int protocol_version;
int last_zxid_seen;
int time_out;
int session_id;
string passwd;

protected void create(int _protocol_version, int _last_zxid_seen, int _timeout, int _session_id, string _passwd) {
  protocol_version = _protocol_version;
  last_zxid_seen = _last_zxid_seen;
  time_out = _timeout;
  session_id = _session_id;
  passwd = _passwd;
}

string encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  encode_int32(buf, protocol_version);
  encode_int64(buf, last_zxid_seen);
  encode_int32(buf, time_out);
  encode_int64(buf, session_id);
  encode_buffer(buf, passwd);
  
  return (string)buf;
}
inherit .Message;

  int protocol_version;
  int time_out;
  int session_id;
  string passwd;

protected variant void create(Stdio.Buffer buf) {
  protocol_version = read_int32(buf);
  time_out = read_int32(buf);
  session_id = read_int64(buf);
 // passwd = read_buffer(buf);
}   


protected string _sprintf(int a, void | mapping b) {
  return sprintf("ConnectResponse(version=%d, time_out=%d, session_id=%x, passwd=%s)", 
                  protocol_version, time_out, session_id, passwd||"");
}
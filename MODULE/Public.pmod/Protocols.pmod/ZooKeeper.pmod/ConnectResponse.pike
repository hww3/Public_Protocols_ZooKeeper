inherit .Message;

  int protocol_version;
  int time_out;
  int session_id;
  string passwd;
  boolean readonly;
  
  // connect reponses aren't preceeded by a reply header.
protected variant void create(Stdio.Buffer buf, int|.ReplyHeader reply_header) {
  protocol_version = read_int32(buf);
  time_out = read_int32(buf);
  session_id = read_int64(buf);
  passwd = read_buffer(buf);
  readonly = read_byte(buf);
}   


protected string _sprintf(int a, void | mapping b) {
  return sprintf("ConnectResponse(version=%d, time_out=%d, session_id=%x, passwd=%s, readonly=%d)", 
                  protocol_version, time_out, session_id, passwd, readonly);
}
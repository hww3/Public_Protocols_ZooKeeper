
#ifdef ZK_DEBUG
#define DEBUG(X ...) werror("ZK: " + X)
#else
#define DEBUG(X ...)
#endif /* ZK_DEBUG */

constant ZK_PORT = 2181;
constant ZKS_PORT = 2181;

constant NOT_CONNECTED = 0;
constant CONNECTING = 1;
constant CONNECTED = 2;

constant CONNECT_STATES = ([0: "NOT_CONNECTED", 1: "CONNECTING", 2: "CONNECTED"]);

constant CREATED_EVENT = 1;
constant DELETED_EVENT = 2;
constant CHANGED_EVENT = 3;
constant CHILD_EVENT = 4;

constant WATCH_XID = -1;
constant PING_XID = -2;
constant AUTH_XID = -4;

constant NO_NODE_ERROR = -101;

protected Stdio.File|SSL.File conn;
protected SSL.Context ssl_context;

protected Stdio.Buffer buffer;
protected Stdio.Buffer outbuf;
protected Pike.Backend backend;
protected Pike.Backend await_backend = Pike.Backend();

int session_timeout = 12000; // 10 secs

// packet parsing state
protected int packet_started = 0;
protected int have_length = 0;
protected int current_length;
protected int connection_state;

int last_zxid;
int session_id;
int xid;
.Message last_request;

//!
int is_connected() { return connection_state == CONNECTED; }

//! 
void set_ssl_context(SSL.Context context) {
  ssl_context = context;
}

protected void process_message(.Message message);

void send_message(.Message m) {
   string msg = m->encode();  
   DEBUG("Adding outbound message to queue: %O => %O\n", m, msg);
   outbuf->add_hstring(msg, 4);
   last_request = m;
   if(conn->query_application_protocol)
	   conn->write("");
}

protected void send_message_sync(.Message m) {
   string msg = m->encode();  
   DEBUG("Sending outbound message synchronously: %O => %O\n", m, msg);
   conn->set_blocking_keep_callbacks();
   conn->write(sprintf("%4c%s", sizeof(msg), msg));
   conn->set_nonblocking_keep_callbacks();
}

protected void reset_frame_state() {
// reset everything
  packet_started = 0;
  current_length = 0;
}

protected void reset_connection(void|int _local, mixed|void backtrace) {
    connection_state = NOT_CONNECTED;
//    if(timeout_callout_id)
//      remove_call_out(timeout_callout_id);
}

protected void read_cb(mixed id, object data) {
  DEBUG("read_cb: %O %O\n", id, data);
  mixed buf = buffer;

  if(conn->query_application_protocol)
  {
    buf->add(data);
	  data = buf;
  }
  
  if(!packet_started)
  {
     if(sizeof(buf) < 4) return 0; // we need at least 4 bytes to get the message length.
     packet_started = 1;
     current_length = buf->read_int32();
  }

  DEBUG("Expecting packet length of %d\n", current_length);
  if(sizeof(buf) < current_length) {
    DEBUG("Didn't get full length from packet. Will wait for more data.");
    return 0; 
  }
  
  Stdio.Buffer body = buf->read_buffer(current_length);

  DEBUG("Data? length: %O body: %O, remaining: %O\n", current_length, body, sizeof(buf));
  reset_frame_state();

    string s1 = (string) body;// body->read_hstring(4);
    body = Stdio.Buffer(s1);
    DEBUG("deserializing header: %d bytes: %O\n", sizeof(s1), s1);


  // TODO we need to keep track of requests by id, as they may not return in strict order.
    .ReplyHeader header = .ReplyHeader(body);
    DEBUG("got replyheader: %O\n", header);
    switch(header->xid) {
      case PING_XID:
        DEBUG("HAVE PING\n");
        // TODO clear outstanding ping request
        break;
      case AUTH_XID:
        DEBUG("HAVE AUTH\n");
        // TODO resolve auth request
        if(header->err) {
          throw(Error.Generic("AUTH FAILED: " + header->err + "\n"));
        }
        break;
      case WATCH_XID:
        DEBUG("HAVE WATCH\n");
        // TODO handle watch notice
        break;
      default:
        break;
    }
    
    DEBUG("ANALYZING HEADER\n");

    if(header->zxid) {
      last_zxid = header->zxid;
      DEBUG("last_zxid: %O\n", last_zxid);
    }   
    if(header->xid != xid) {
      throw(Error.Generic("Got unexpected xid: " + header->xid + ", was expecting " + xid + "\n"));
    }
        
    int exists_error = header->err == NO_NODE_ERROR && last_request->MESSAGE_ID == .ExistsRequest->MESSAGE_ID;
    werror("exists_error: %O, err: %O\n", exists_error, header->err);
    if(header->err && ! exists_error) {
      throw(Error.Generic("ZK Error: " + header->err + "\n"));
    }
    
    string s = (string) body;// body->read_hstring(4);
    body = Stdio.Buffer(s);
    DEBUG("deserializing %O message: %d bytes: %O\n", last_request->response_program, sizeof(s), s);
    .Message message = last_request->response_program(body);
    
  process_message(message);
  
  if(sizeof(buf)) {
  // data left, so queue up another round.
    DEBUG("have %d in buffer\n", sizeof(buf));
    call_out(read_cb, 0, id, "");
  }
  else DEBUG("buffer empty.\n");
}

protected int write_cb(mixed id) {
//  DEBUG("write_cb %O\n", id);
  if(conn->query_application_protocol && sizeof(outbuf))
  {
	  string s = outbuf->read();
	  int tosend = sizeof(s);
	  int tot = 0;
//	  DEBUG("writing %d\n", sizeof(s));
	  while(tot < tosend) {
       int sent = conn->write(s);
	   tot += sent;
	   if(tot < tosend && sent > 0) s = s[sent..];
    }
//	  DEBUG("wrote %d\n", tot);
	  return tot;
  }
  return 0;
}

protected void close_cb(mixed id) {
  DEBUG("close_cb %O\n", id);
  reset_connection();
  reset_frame_state();
}


#ifdef ZK_DEBUG
#define DEBUG(X ...) werror("ZK: " + X)
#else
#define DEBUG(X ...)
#endif /* ZK_DEBUG */

inherit .serialization_utils;

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

protected ADT.Queue ping_timeout_callout_ids = ADT.Queue();
protected mixed timeout_callout_id;

Thread.Mutex await_mutex = Thread.Mutex();
protected mapping(int:.Message) pending_responses = ([]);
protected boolean sync_mode = 0;

int last_zxid;
int session_id;
int xid;
.Message last_request;

//!
int is_connected() { return connection_state == CONNECTED; }

//!
void set_synchronous(boolean sync) {
	sync_mode = sync;
}

//!
void set_timeout(int msec) {
	session_timeout = msec;
}

//! 
void set_ssl_context(SSL.Context context) {
  ssl_context = context;
}

protected void process_event(.WatcherEvent event);

protected void process_error(Error.Generic err, void|.ReplyHeader header);

protected void process_message(.Message message, void|.ReplyHeader header);

void send_message(.Message m) {
   string msg;
   if(connection_state == CONNECTING){
     if(object_program(m) == .ConnectRequest) {
       msg = m->encode(); 
       xid++;
     }
     else {
       throw(Error.Generic("Not connected.\n"));
    }
   }
   else {
     msg = sprintf("%4c%4c%s", xid,  m->MESSAGE_ID, m->encode());
	  }
	  
   DEBUG("Adding outbound message to queue: %O, type %d => %O\n", m, m->MESSAGE_ID, msg);
   outbuf->add_hstring(msg, 4);
   last_request = m;
   if(conn->query_application_protocol)
	   conn->write("");
}

protected void send_message_sync(.Message m) {

	string msg;
	
   if(connection_state == CONNECTING) {
      if(object_program(m) == .ConnectRequest) {
        msg = m->encode();
	      xid++; 
      } else {
        throw(Error.Generic("Not connected.\n"));
      }
    }
    else {
      msg = sprintf("%4c%4c%s", xid, m->MESSAGE_ID, m->encode());
   }
   DEBUG("Sending outbound message synchronously: %O => %O\n", m, msg);
   conn->set_blocking_keep_callbacks();
   last_request = m;
   conn->write(sprintf("%4c%s", sizeof(msg), msg));
   conn->set_nonblocking_keep_callbacks();
}

protected .Message send_message_await_response(.Message m, int timeout) {
  .Message r = 0;
  int message_identifier = xid;

  if(!message_identifier) throw(Error.Generic("No message identifier (xid) specified. Cannot receive a response.\n"));
  int attempts = 0;
    mixed err;

  register_pending(message_identifier, m);
  do {
    send_message(m);
    err = catch(r = await_response(message_identifier, timeout));
    if(r || err) break;
  }  while(0); // (attempts++ < max_retries);

  unregister_pending(message_identifier);

  if(err) throw(err);
  return r;
}


protected .Message await_response(int message_identifier, int timeout) {
  .Message m = 0;
  Pike.Backend orig;

  float f = (float)timeout;
  
  DEBUG("await_response %d\n", message_identifier);

  if((m = pending_responses[message_identifier])) {
    DEBUG("await_response %O have PendingResponse\n", m);
    if(m->message)
      return m->message;
    else if(m->error) throw(m->error);
  }
// TODO
// there is a theoretical race condition here
// or at least a possible performance gap that could occur if a
// client is waiting and the lock is held while messages are not 
// delivered. we should 

DEBUG("await_response: response is pending.");

  while(f > 0.0) {
    
    object key = await_mutex->trylock();

    if(!key) {
      key = await_mutex->lock();
       if((m = pending_responses[message_identifier])) {
      DEBUG("await_response %O have PendingResponse\n", m);
      if(m->message) {
        key = 0;
        return m->message;
       }
      else if(m->error) {
        key = 0;
        throw(m->error);
      }
      }
    }

    if(!orig) orig = conn->query_backend();

    // DEBUG("waiting %f seconds for message %d\n", f, message_identifier);
    conn->set_backend(await_backend);
    f = f - await_backend(f);
    key = 0;
    if((m = pending_responses[message_identifier]) && (m->error || m->message))
      break;
  }

  conn->set_backend(orig);
  if(m && m->error) throw(m->error);
  return m?m->message:m; // timeout
}

protected void async_await_response(int message_identifier, .Message message, int response_timeout, 
    function success, function failure, mixed data) {
    register_pending(message_identifier, message, response_timeout, success, failure, data);
}

protected variant void register_pending(int message_identifier, .Message message) {
  .PendingResponse pr = .PendingResponse(this, message_identifier, message, 0);
  pending_responses[message_identifier] = pr;
}

protected variant void register_pending(int message_identifier, .Message message,  int timeout, function success, function failure, mixed data) {
  .PendingResponse pr = .PendingResponse(this, message_identifier, message, timeout);
  if(data) pr->data = data;
  if(success) pr->success = success;
  if(failure) pr->failure = failure;
    else pr->failure = report_timeout;
  pending_responses[message_identifier] = pr;
}

void unregister_pending(int message_identifier) {
  if(has_index(pending_responses, message_identifier)) {
    DEBUG("clearing pending response marker for %d\n", message_identifier);
    m_delete(pending_responses, message_identifier);
  }
}

protected void reset_frame_state() {
// reset everything
  packet_started = 0;
  current_length = 0;
}

protected void reset_connection(void|int _local, mixed|void backtrace) {
    connection_state = NOT_CONNECTED;
    if(timeout_callout_id)
      remove_call_out(timeout_callout_id);
}

protected void read_cb(mixed id, object data) {
  DEBUG("read_cb: %O %O\n", id, data);
  .ReplyHeader header;
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

    int handled = 1;

	if(connection_state == CONNECTING) {
	    DEBUG("deserializing connection response: %d bytes: %O\n", sizeof(s1), s1);
		handled = 0; // ConnectResponse is a special case, it has no ReplyHeader, but we do have a body.
		xid++;
	}
	else if(connection_state == CONNECTED) {
	    DEBUG("deserializing header: %d bytes: %O\n", sizeof(s1), s1);
	 	header = .ReplyHeader(body);
		DEBUG("got replyheader: %O\n", header);
		switch(header->get_xid()) {
			case PING_XID:
			DEBUG("HAVE PING\n");
			handle_ping();
			break;
			case AUTH_XID:
			DEBUG("HAVE AUTH\n");
			// TODO resolve auth request
			if(header->get_err()) {
				throw(Error.Generic("AUTH FAILED: " + header->get_err() + "\n"));
			}
			break;
			case WATCH_XID:
			DEBUG("HAVE WATCH\n");
			// TODO handle watch notice
			.WatcherEvent event = .WatcherEvent(body);
			process_event(event);
			break;
			default:
			handled = 0;
			break;
		}

		if(!handled) {
			DEBUG("ANALYZING HEADER\n");
			int zxid = header->get_zxid();
			if(zxid) {
				last_zxid = zxid;
				DEBUG("last_zxid: %O\n", last_zxid);
			}   
			if(header->get_xid() != xid) {
				throw(Error.Generic("Got unexpected xid: " + header->get_xid() + ", was expecting " + xid + "\n"));
			}

			xid ++;
			int err = header->get_err();
			
			int exists_error = err == NO_NODE_ERROR && last_request->MESSAGE_ID == .ExistsRequest->MESSAGE_ID;
		
			if(err && ! exists_error) {
			DEBUG(sprintf("got error but still have a body %O\n", body));
			  program ep = .errors_by_code[err];
			  if(!ep) ep = .Errors.ZooKeeperError;
				process_error(ep(header->get_xid(), header->get_zxid()), header);
				handled = 1;
			}
		}	
	}
	
	if(!handled) {
	    string s = (string) body;// body->read_hstring(4);
	    body = Stdio.Buffer(s);
	    DEBUG("deserializing %O message: %d bytes: %O\n", last_request->response_program, sizeof(s), s);
	    .Message message;
	    message = last_request->response_program(body);
  		process_message(message, header);
	}    
	
  if(sizeof(buf)) {
  // data left, so queue up another round.
    DEBUG("have %d in buffer\n", sizeof(buf));
    call_out(read_cb, 0, id, "");
  }
  else DEBUG("buffer empty.\n");
}

protected void handle_ping() {}

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

//!
void disconnect() {
  //check_connected();
  low_disconnect(1);
}

protected void low_disconnect(int _local, mixed|void backtrace) {
	DEBUG("low_disconnect()\n");
  if(conn->is_open()) {
	  send_message_await_response(.CloseRequest(), 5);
    conn->close();
  }
  reset_connection(_local, backtrace);
  reset_frame_state();
}

void report_timeout(.PendingResponse response) {
  DEBUG("A timed out waiting for response after %d attempts.\n", response->attempts);
}

protected void report_error(mixed error) {
  werror(master()->describe_backtrace(error));
}

protected void destroy() {
	low_disconnect(1);
	
  foreach(pending_responses; int key; object pending_response) {
    m_delete(pending_responses, key);
    destruct(pending_response);
  }
}


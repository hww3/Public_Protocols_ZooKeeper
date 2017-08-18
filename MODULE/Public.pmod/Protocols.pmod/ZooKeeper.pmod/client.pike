inherit .protocol;

#ifdef ZK_DEBUG
#define DEBUG(X ...) werror("ZK: " + X)
#else
#define DEBUG(X ...)
#endif /* ZK_DEBUG */

protected string host;
protected int port;
protected float timeout;

//protected string username;
//protected string password;

protected Standards.URI connect_url;

protected function(.client:void) connect_cb;
protected function(.client,.Reason:void) disconnect_cb;

protected mapping(string:array) watchers = ([]);
//! ZK client

//! create a client which will connect to an zookeeper server on the specified server and port.
protected variant void create(string _host, int _port) {
   create("zk://" + _host + ":" + _port);
}

//!
void set_timeout(int msec) {
	::set_timeout(msec);
	timeout = session_timeout / 1000.0;
	DEBUG("timeout is " + timeout + " seconds.\n");
}

//! create a client 
//!
//! @param _connect_url
//!   A url in the form of  @tt{zk://[user[:password]@@][hostname][:port]@} or  @tt{zks://[user[:password]@@][hostname][:port]@}
//!
protected variant void create(string _connect_url) {
    connect_url = Standards.URI(_connect_url);
	if(!(<"zk", "zks">)[connect_url->scheme]) throw(Error.Generic("Connect url must be of type zk or zks.\n"));
	
	host = connect_url->host;
	port = connect_url->port;
//	username = connect_url->user;
//	password = connect_url->password;
	
	if(!port) {
		if(connect_url->scheme == "zks") port = ZKS_PORT;
		else port = ZK_PORT;
	}
	
	timeout = session_timeout / 1000.0;
	DEBUG("timeout is " + timeout + " seconds.\n");
	
	backend = Pike.DefaultBackend;
}

//! specify a callback to be run when a client is disconnected.
void set_disconnect_callback(function(.client,.Reason:void) cb) {
	disconnect_cb = cb;
}

//! connect and specify a method to be called when the connection successfully completes.
variant void connect(function(.client:void) _connect_cb) {
	connect_cb = _connect_cb;
	connect();
}

//! connect to the server.
//!
//! @note
//!  this method may return before the connection has succeeded or failed. 
variant void connect() {
   if(connection_state != NOT_CONNECTED) throw(Error.Generic("Connection already in progress.\n"));
	
   connection_state = CONNECTING;
   
   conn = Stdio.File();
   conn->set_blocking();
   DEBUG("connecting to %s, %d.\n", host, port);
   if(!conn->connect(host, port))  {
     connection_state = NOT_CONNECTED;
     throw(Error.Generic("Unable to connect to ZK server.\n"));
   }

   if(connect_url->scheme == "zks") {
	   DEBUG("Starting SSL/TLS\n");
       conn = SSL.File(conn, ssl_context || SSL.Context());
	   conn->set_blocking();
	   if(!conn->connect(host))
	     throw(Error.Generic("Unable to start TLS session with ZK server.\n"));
	   //conn->write("");
   }

   buffer = Stdio.Buffer();
   outbuf = Stdio.Buffer();
   if(connect_url->scheme != "zks")
     conn->set_buffer_mode(buffer, outbuf);
   conn->set_write_callback(write_cb);
   conn->set_close_callback(close_cb);
   conn->set_read_callback(read_cb);
   conn->set_nonblocking_keep_callbacks();
   
   .ConnectRequest m = .ConnectRequest(xid, last_zxid, session_timeout, session_id, "\0"*16);

   if(sync_mode)
     send_message_sync(m);
   else
     send_message(m);
	 
   if(sync_mode) {
	   
	   Pike.Backend orig;

	   float f = (float)timeout;
	   while(f > 0.0) {
    	       
	     if(!orig) orig = conn->query_backend();

	     DEBUG("waiting %f seconds for message\n", f);
	     conn->set_backend(await_backend);
	     f = f - await_backend(f);
		 
	     if(connection_state == CONNECTED)
	       break;
	 } 
  	 conn->set_backend(orig);
  	if(connection_state != CONNECTED)
	  throw(Error.Generic("Connection timeout\n"));
	}
}

variant string get_data(string path) {
	.GetDataRequest message = .GetDataRequest(path, 0);
	.Message reply = send_message_await_response(message, (int)timeout);
	
	return reply->data;
}

variant string get_data(string path, function watch_cb) {
	return "";
}

mapping get_data_full(string path) {
	.GetDataRequest message = .GetDataRequest(path, 0);
	.Message reply = send_message_await_response(message, (int)timeout);
	
	return (["data": reply->data, "stat": reply->stat]);
}

variant .Stat set_data(string path, string data, int|void version) {
	.SetDataRequest message = .SetDataRequest(path, data, version);
	.Message reply = send_message_await_response(message, (int)timeout);
	
	return reply->stat;
}

variant string set_data(string path, string data, int|void version, function watch_cb) {
	return "";
}

variant boolean create_node(string path, string data, array(.ACL) acls, int|void flags, function cb) {
  .CreateRequest message = .CreateRequest(path, data, acls, flags);
  .Message reply = send_message_await_response(message, (int) timeout);
}

variant string create_node(string path, string data, array(.ACL) acls, int|void flags) {
  .CreateRequest message = .CreateRequest(path, data, acls, flags);
  .Message reply = send_message_await_response(message, (int) timeout);
  return reply->path;
}

//! @note
//!   requires ZooKeeper 3.6 or newer
variant string create_node_ttl(string path, string data, array(.ACL) acls, int|void flags, int ttl) {
  .CreateRequest message = .CreateTTLRequest(path, data, acls, flags, ttl);
  .Message reply = send_message_await_response(message, (int) timeout);
  return reply->path;
}

boolean sync(string path) {
  .SyncRequest message = .SyncRequest(path);
  .Message reply = send_message_await_response(message, (int) timeout);
  return reply->path;
}

variant boolean exists(string path, boolean|void watch) {
  .ExistsRequest message = .ExistsRequest(path, watch);
  .Message reply = send_message_await_response(message, (int) timeout);
  boolean exists = reply->stat?1:0;
  return exists;
}

variant boolean exists(string path, boolean|void watch, function|void cb, mixed|void ... data) {
  .ExistsRequest message = .ExistsRequest(path, watch);
  .Message reply = send_message_await_response(message, (int) timeout);
  //werror("reply: %O\n", reply->stat);
  boolean exists = reply->stat?1:0;
  if(exists)
    register_watcher(path, cb, @data);
  return exists;
}

boolean set_acl(string path, array(.ACL) acls, int|void version) {
    .SetACLRequest message = .SetACLRequest(path, acls, version);
    .Message reply = send_message_await_response(message, (int) timeout);
    return true;
}

array(string) get_children(string path, boolean|void watch) {
  .GetChildrenRequest message = .GetChildrenRequest(path, watch);
  .Message reply = send_message_await_response(message, (int) timeout);
  return reply->children;
}

mapping get_children2(string path, boolean|void watch) {
  .GetChildren2Request message = .GetChildren2Request(path, watch);
  .Message reply = send_message_await_response(message, (int) timeout);
  return (["children": reply->children, "stat": reply->stat]);
}

.Stat check_version(string path, int version) {
  .CheckVersionRequest message = .CheckVersionRequest(path, version);
  .Message reply;
mixed err;
err = catch(reply = send_message_await_response(message, (int) timeout));
if(err && err->is_bad_version_error) return false;
else if(err) throw(err);
else return reply->stat;
}

variant boolean get_acl(string path, int|void version, function cb) {
  .GetACLRequest message = .GetACLRequest(path);
  .Message reply = send_message_await_response(message, (int) timeout);
}

variant array(.ACL) get_acl(string path) {
  .GetACLRequest message = .GetACLRequest(path);
  .Message reply = send_message_await_response(message, (int) timeout);
  return reply->acls;
}

variant boolean delete(string path, int|void version) {
  .DeleteRequest message = .DeleteRequest(path, version);
  .Message reply = send_message_await_response(message, (int) timeout);
  return true;
}

variant boolean delete(string path, int|void version, function cb) {
  .DeleteRequest message = .DeleteRequest(path, version);
  .Message reply = send_message_await_response(message, (int) timeout);
}


protected void send_ping() {
	.PingRequest message = .PingRequest();
	ping_timeout_callout_ids->put(call_out(ping_timeout, timeout));
	send_message(message);
}

protected void handle_ping() {
    DEBUG("Got PingResponse\n");
    if(sizeof(ping_timeout_callout_ids)) {
      DEBUG("removing ping timeout callout\n");
      remove_call_out(ping_timeout_callout_ids->get());
    }
}

protected void ping_timeout() {
  // no ping response received before timeout.
  DEBUG("No ping response received before timeout, disconnecting.\n");
  disconnect();
}

//! method used internally by the ZK client
protected void send_message(.Message m) {
   ::send_message(m);
   if(timeout_callout_id) remove_call_out(timeout_callout_id);
   timeout_callout_id = call_out(send_ping, (timeout > 1? timeout - 1: 0.5));
}

protected void send_message_sync(.Message m) {
   ::send_message_sync(m);
   if(timeout_callout_id) remove_call_out(timeout_callout_id);
   timeout_callout_id = call_out(send_ping, (timeout > 1? timeout - 1: 0.5));
}

protected void register_watcher(string path, function cb, mixed ... data) {
  if(!has_index(watchers, path))
    watchers[path] = ({ ({cb, data}) });
  else    
    watchers[path] += ({ ({cb, data}) });
}

protected void process_event(.WatcherEvent event) {
  if(!has_index(watchers, event->get_path())) return; // TODO we shouldn't have events without watchers, so probably should clean up.
  
  foreach(watchers[event->get_path()];; array cbd)
    call_out(cbd[0], 0, event, @cbd[1]);
}

protected void process_error(Error.Generic err, void|.ReplyHeader header) {
  DEBUG("got response error: %O header: %O\n", err, header);
    int message_identifier = header->get_xid();
  if(has_index(pending_responses, message_identifier)) {
    object pending_response = pending_responses[message_identifier];
    pending_response->received_exception(err);
  } 
}

protected void process_message(.Message message, .ReplyHeader|void header) {
  DEBUG("got response message: %O\n", message);
  
  if(object_program(message) == .ConnectResponse) {
	  if(connection_state == CONNECTING) {
	  	connection_state = CONNECTED;
		if(connect_cb) call_out(connect_cb, 0, this);
	}
      else 
	  	throw(Error.Generic("Got ConnectResponse but not in CONNECTING state.\n"));
	
		return;
  }
  
  int message_identifier = header->get_xid();
  if(has_index(pending_responses, message_identifier)) {
    object pending_response = pending_responses[message_identifier];
    pending_response->received_message(message);
  } 
}
inherit .protocol;

#ifdef ZK_DEBUG
#define DEBUG(X ...) werror("ZK: " + X)
#else
#define DEBUG(X ...)
#endif /* ZK_DEBUG */

#define REQUIRE_TX() { do { if(!current_transaction) throw(Error.Generic("Not in a transaction!\n")); } while(0); }

array(Standards.URI) urls;
array(Standards.URI) connect_urls;
protected string host;
protected int port;
protected float timeout;
protected int read_only;
protected int attempts_since_success;
//protected string username;
//protected string password;

protected Standards.URI connect_url;

protected function(.client:void) connect_cb;
protected function(.client,.Reason:void) disconnect_cb;

protected ADT.List current_transaction;
protected mapping(string:mapping) watchers = ([]);
//! ZK client

//! create a client which will connect to an zookeeper server on the specified server and port.
protected variant void create(string _host, int _port, int|void _read_only) {
   create("zk://" + _host + ":" + _port, _read_only);
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
protected variant void create(string _connect_url, int|void _read_only) {
    create(({_connect_url}), _read_only);
}

protected variant void create(array(string) _connect_urls, int|void _read_only) {
	if(!sizeof(_connect_urls)) throw(Error.Generic("At least one ZK url must be provided.\n"));
	
	array u = allocate(sizeof(_connect_urls));
	foreach(_connect_urls; int i; mixed _connect_url) {
    connect_url = Standards.URI(_connect_url);
      if(!(<"zk", "zks">)[connect_url->scheme]) throw(Error.Generic("Connect url[" + i + "] must be of type zk or zks.\n"));
	  u[i] = connect_url;
	}
	
	urls = u;
	connect_urls = Array.shuffle(urls);
	
	read_only = _read_only;
	timeout = session_timeout / 1000.0;
	DEBUG("timeout is " + timeout + " seconds.\n");
	
	backend = Pike.DefaultBackend;
}


//! specify a callback to be run when a client is disconnected.
void set_disconnect_callback(function(.client,.Reason:void) cb) {
	disconnect_cb = cb;
}

protected void low_disconnect(int _local, mixed|void backtrace) {
  pending_responses = ([]);
  ::low_disconnect(_local, backtrace);
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

   Standards.URI connect_url = connect_urls[0];
	host = connect_url->host;
	port = connect_url->port;
//	username = connect_url->user;
//	password = connect_url->password;
	
	if(!port) {
		if(connect_url->scheme == "zks") port = ZKS_PORT;
		else port = ZK_PORT;
	}	
   
   conn = Stdio.File();
   conn->set_blocking();
   DEBUG("connecting to %s, %d.\n", host, port);
   if(!conn->connect(host, port))  {
     connection_state = NOT_CONNECTED;
     report_error(Error.Generic("Unable to connect to ZK server " + host + ":" + port + ".\n"));
	   attempts_since_success++;
	   if(!was_connected && attempts_since_success >= sizeof(urls)) { // we have no more left to try
		   attempts_since_success = 0;
		   throw(Error.Generic("Unable to connect to any specified ZK server.\n"));
     }
  	 else { reconnect(); return; }
   }

   if(connect_url->scheme == "zks") {
	   DEBUG("Starting SSL/TLS\n");
       conn = SSL.File(conn, ssl_context || SSL.Context());
	   conn->set_blocking();
	   if(!conn->connect(host)) {
  	     report_error(Error.Generic("Unable to start TLS session with ZK server " + host + ":" + port + ".\n"));
		attempts_since_success++;
		if(!was_connected && attempts_since_success == sizeof(urls)) { // we have no more left to try
			attempts_since_success = 0;
			throw(Error.Generic("Connection timeout\n"));
		}
  	 else { reconnect(); return; }
	 }
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
  	 if(connection_state != CONNECTED) {
			attempts_since_success++;
			if(!was_connected && attempts_since_success == sizeof(urls)) // we have no more left to try
			{
				// we're in synchronous mode, so no need to keep a backoff period
				attempts_since_success = 0;
				throw(Error.Generic("Connection timeout\n"));
			}
   	  else { reconnect(); return; }

  		}
	}
}

protected void close_cb(mixed id) {
  ::close_cb(id);
  if(disconnect_cb) call_out(disconnect_cb, 0, this);
  else if(auto_reconnect) call_out(reconnect, 0, 1);
}

protected float calculate_backoff(int attempts_since_success) {
	int passes = attempts_since_success / sizeof(urls); // how many times have we been through the list?
	int at_start = !(attempts_since_success % sizeof(urls)); 

  werror("passes: %O, urls: %O, at_start: %O\n", passes, sizeof(urls), at_start);
	random_seed(time());

  if(!passes) return 0.0; // first time through, go quickly.

  if(at_start) 	
		return random(2.0) + 5*passes;
	else return random(1.0);
}

void reconnect() {	
	low_disconnect(1);
	
	if(sizeof(connect_urls) == 1) {
		connect_url = connect_urls[0];
		connect_urls = Array.shuffle(urls);
	} else {
		[connect_url, connect_urls] = Array.shift(connect_urls);
	}

    float sleepytime = calculate_backoff(attempts_since_success);

	DEBUG("reconnecting in " + sleepytime + " seconds.\n");
	
	if(sync_mode) {
	  sleep(sleepytime);
	  connect();	
    } else {
	  call_out(connect, sleepytime);
	}
}

//!
string get_data(string path, boolean|void watch, function cb, mixed|void ... data) {
	.GetDataRequest message = .GetDataRequest(path, watch);
  if(watch)
    register_watcher(path, cb, @data);

	.Message reply = send_message_await_response(message, (int)timeout);
	return reply->data;
}

//!
mapping get_data_full(string path) {
	.GetDataRequest message = .GetDataRequest(path, 0);
	.Message reply = send_message_await_response(message, (int)timeout);
	
	return (["data": reply->data, "stat": reply->stat]);
}

//!
.Stat set_data(string path, string data, int|void version) {
	.SetDataRequest message = make_set_data_request(path, data, version);
	.Message reply = send_message_await_response(message, (int)timeout);
	
	return reply->stat;
}

.SetDataRequest make_set_data_request(string path, string data, int|void version) {
  return .SetDataRequest(path, data, version);
}
//!
string create_node(string path, string data, array(.ACL) acls, int|void flags) {
  .CreateRequest message = make_create_request(path, data, acls, flags);
  .Message reply = send_message_await_response(message, (int) timeout);
  return reply->path;
}

protected .CreateRequest make_create_request(string path, string data, array(.ACL) acls, int|void flags) {
  return .CreateRequest(path, data, acls, flags);
}

void add_create_node(string path, string data, array(.ACL) acls, int|void flags) {
  REQUIRE_TX();
  current_transaction->append(make_create_request(path, data, acls, flags));
}

void add_delete(string path, int|void version) {
  REQUIRE_TX();
  current_transaction->append(make_delete_request(path, version));
}

void add_set_data(string path, string data, int|void version) {
  REQUIRE_TX();
  current_transaction->append(make_set_data_request(path, data, version));
}

void add_check_version(string path, int version) {
  REQUIRE_TX();
  current_transaction->append(make_check_version_request(path, version));
}


void start_transaction() {
  if(current_transaction) throw(Error.Generic("Already in a transaction!\n"));
  current_transaction = ADT.List();
}

array commit_transaction() {
  REQUIRE_TX();
  .TransactionRequest message = .TransactionRequest(current_transaction);
  .Message reply = send_message_await_response(message, (int) timeout);
  werror("reply: %O\n", reply);
  current_transaction = 0;
  return reply->return_results();
}


//! @note
//!   requires ZooKeeper 3.6 or newer
string create_node_ttl(string path, string data, array(.ACL) acls, int|void flags, int ttl) {
  .CreateRequest message = .CreateTTLRequest(path, data, acls, flags, ttl);
  .Message reply = send_message_await_response(message, (int) timeout);
  return reply->path;
}

boolean sync(string path) {
  .SyncRequest message = .SyncRequest(path);
  .Message reply = send_message_await_response(message, (int) timeout);
  return reply->path;
}

//!
variant boolean exists(string path) {
  .ExistsRequest message = make_exists_request(path, 0);
  .Message reply = send_message_await_response(message, (int) timeout);
  boolean exists = reply->stat?1:0;
  return exists;
}

//!
variant boolean exists(string path, boolean watch, function cb, mixed|void ... data) {
  .ExistsRequest message = make_exists_request(path, watch);
  if(watch)
    register_watcher(path, cb, @data);
    
  .Message reply = send_message_await_response(message, (int) timeout);
  //werror("reply: %O\n", reply->stat);
  boolean exists = reply->stat?1:0;

  return exists;
}

protected .ExistsRequest make_exists_request(string path, boolean watch) {
  return .ExistsRequest(path, watch);
}

//!
boolean set_acl(string path, array(.ACL) acls, int|void version) {
    .SetACLRequest message = .SetACLRequest(path, acls, version);
    .Message reply = send_message_await_response(message, (int) timeout);
    return true;
}

//!
array(string) get_children(string path, boolean|void watch, function|void cb, mixed|void ... data) {
  .GetChildrenRequest message = .GetChildrenRequest(path, watch);

  if(watch)
    register_watcher(path, cb, @data);
    
  .Message reply = send_message_await_response(message, (int) timeout);
  return reply->children;
}

//!
mapping get_children2(string path, boolean|void watch, function|void cb, mixed|void ... data) {
  .GetChildren2Request message = .GetChildren2Request(path, watch);
  
  if(watch)
    register_watcher(path, cb, @data);
    
  .Message reply = send_message_await_response(message, (int) timeout);
  return (["children": reply->children, "stat": reply->stat]);
}

//!
.Stat check_version(string path, int version) {
  .CheckVersionRequest message = make_check_version_request(path, version);
  .Message reply;
mixed err;
err = catch(reply = send_message_await_response(message, (int) timeout));
if(err && err->is_bad_version_error) return false;
else if(err) throw(err);
else return reply->stat;
}

protected .CheckVersionRequest make_check_version_request(string path, int version) {
  return .CheckVersionRequest(path, version);
}
//!
array(.ACL) get_acl(string path) {
  .GetACLRequest message = .GetACLRequest(path);
  .Message reply = send_message_await_response(message, (int) timeout);
  return reply->acls;
}

//!
boolean delete(string path, int|void version) {
  .DeleteRequest message = make_delete_request(path, version);
  .Message reply = send_message_await_response(message, (int) timeout);
  return true;
}

.DeleteRequest make_delete_request(string path, int|void version) {
  return .DeleteRequest(path, version);
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
  DEBUG("No ping response received before timeout, reconnecting.\n");
  reconnect();
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
    watchers[path] = ([ ({cb, data}) :1 ]);
  else    
    watchers[path][({cb, data})] = 1;
}

variant void clear_watchers(string path) {
  m_delete(watchers, path);
}

variant void clear_watchers() {
  watchers = ([]);
}

protected void process_event(.WatcherEvent event) {
  string path = event->get_path();
  
  if(!has_index(watchers, path)) return; // TODO we shouldn't have events without watchers, so probably should clean up.
  
  mapping w = watchers[path];
  
  foreach(w; array cbd;) {
    m_delete(w, cbd);
    call_out(cbd[0], 0, event, @cbd[1]);
  }
}

protected void process_error(Error.Generic err, void|.ReplyHeader header) {
  DEBUG("got response error: %O header: %O\n", err, header);
    int message_identifier = header->get_xid();
    object pending_response;
    if(has_index(pending_responses, message_identifier)) {
      pending_response = pending_responses[message_identifier];
    }

    if(err->is_session_expired_error) {
      // what to do here?
      call_out(session_timeout_received, 0, pending_response);
      if(disconnect_cb)
        call_out(disconnect_cb, 0, this);
      low_disconnect(0);
    }

    if(pending_response)
      pending_response->received_exception(err);
    else report_error(err); // really shouldn't get here.
}

protected void session_timeout_received(object pending_response) {
  reconnect();
}

protected void process_message(.Message message, .ReplyHeader|void header) {
  DEBUG("got response message: %O\n", message);
  
  if(object_program(message) == .ConnectResponse) {
	  if(connection_state == CONNECTING) {
		  if(message->read_only && !read_only) {
			  attempts_since_success++;
			  DEBUG("need a r/w server, so reconnecting");
			  reconnect();
		  } 
	    attempts_since_success = 0;
	  	connection_state = CONNECTED;
  		was_connected = 1;
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
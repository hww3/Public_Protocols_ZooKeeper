inherit .protocol;

#ifdef ZK_DEBUG
#define DEBUG(X ...) werror("ZK: " + X)
#else
#define DEBUG(X ...)
#endif /* ZK_DEBUG */

protected string host;
protected int port;
//protected string username;
//protected string password;

protected Standards.URI connect_url;


//! ZK client

//! create a client which will connect to an zookeeper server on the specified server and port.
protected variant void create(string _host, int _port) {
   create("zk://" + _host + ":" + _port);
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
	
	backend = Pike.DefaultBackend;
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

  /*
   if(username)
   {
       m->has_username = 1;
	   m->username = username;
	   if(password)
	   {
  	     m->has_password = 1;
  	     m->password = password;
	   }
   }
 */
   
   send_message(m);
}


void process_message(.Message message) {
  DEBUG("got response message: %O\n", message);
}
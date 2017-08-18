inherit .serialization_utils;

constant MESSAGE_TYPE = "RESERVED";
constant  MESSAGE_ID = 0;

#ifdef ZK_DEBUG
#define DEBUG(X ...) werror("ZK: " + X)
#else
#define DEBUG(X ...)
#endif /* ZK_DEBUG */

//constant response_program = 0;

protected variant void create() { throw(Error.Generic("Creation not allowed\n")); }

protected variant void create(Stdio.Buffer buf, .ReplyHeader reply_header) {
  throw(Error.Generic("Creation from buffer not allowed\n"));
}

public string|Stdio.Buffer encode() { }

public mixed return_results() { return 0; }
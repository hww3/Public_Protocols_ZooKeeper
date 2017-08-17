inherit .serialization_utils;

constant MESSAGE_TYPE = "RESERVED";
constant  MESSAGE_ID = 0;

#ifdef ZK_DEBUG
#define DEBUG(X ...) werror("ZK: " + X)
#else
#define DEBUG(X ...)
#endif /* ZK_DEBUG */

public program response_program;

protected variant void create() { throw(Error.Generic("Creation not allowed\n")); }

protected variant void create(Stdio.Buffer buf) {
  throw(Error.Generic("Creation from buffer not allowed\n"));
}

public string encode() {
}

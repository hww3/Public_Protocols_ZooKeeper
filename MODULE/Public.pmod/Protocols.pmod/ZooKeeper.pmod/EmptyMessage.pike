inherit .serialization_utils;

constant MESSAGE_TYPE = "EMPTY";
constant  MESSAGE_ID = 9999;

#ifdef ZK_DEBUG
#define DEBUG(X ...) werror("ZK: " + X)
#else
#define DEBUG(X ...)
#endif /* ZK_DEBUG */

public program response_program;

protected variant void create() {
 throw(Error.Generic("Creation not allowed\n"));
}

protected variant void create(Stdio.Buffer buf) {
}

public string encode() {
}

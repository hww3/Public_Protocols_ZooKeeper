inherit .Message;

constant MESSAGE_TYPE = "PING_REQUEST";
constant  MESSAGE_ID = 11;

protected void create() {
}

string|Stdio.Buffer encode() { return ""; }
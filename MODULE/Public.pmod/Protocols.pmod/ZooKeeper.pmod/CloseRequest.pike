inherit .Message;

constant MESSAGE_TYPE = "CLOSE";
constant MESSAGE_ID = -11;

public program response_program = .NilResponse;

protected void create() {
}

string encode() {
	return "";
}
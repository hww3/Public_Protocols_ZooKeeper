inherit .Message;

constant MESSAGE_TYPE = "MULTI";
constant MESSAGE_ID = 14;

constant response_program = .TransactionResponse;

ADT.List operations;

protected void create(ADT.List _operations) {
  operations = _operations;
}

string|Stdio.Buffer encode() {
  Stdio.Buffer buf = Stdio.Buffer();
  
  foreach(operations;; object op) {
    buf->add(.MultiHeader(op->MESSAGE_ID, 0, -1)->encode());
    buf->add(op->encode());
  }
  
  buf->add(.MultiHeader(-1, 1, -1)->encode());
  
  return buf;
}

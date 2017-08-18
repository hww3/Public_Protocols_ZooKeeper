inherit .Message;

string data;
.Stat stat;

protected variant void create(Stdio.Buffer buf, .ReplyHeader reply_header) {
    data = read_buffer(buf);
    stat = .Stat(buf);
 }
 
 public mixed return_results() { return data; }
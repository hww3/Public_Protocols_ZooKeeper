inherit .Message;

string path;

protected variant void create(Stdio.Buffer buf, .ReplyHeader reply_header) {
    path = read_string(buf);
 }
 
 public mixed return_results() { return path; }
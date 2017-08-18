inherit .Message;

.Stat stat;

protected variant void create(Stdio.Buffer buf, .ReplyHeader reply_header) {
    if(sizeof(buf))
        stat = .Stat(buf);
 }
 
 public mixed return_results() { return stat; }
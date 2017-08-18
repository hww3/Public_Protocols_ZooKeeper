inherit .Message;

.Stat stat;

protected variant void create(Stdio.Buffer buf, .ReplyHeader reply_header) {
	stat = .Stat(buf);
}

public mixed return_results() { return stat; }
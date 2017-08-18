inherit .Message;

.Stat stat;

protected variant void create(Stdio.Buffer buf) {
	stat = .Stat(buf);
}
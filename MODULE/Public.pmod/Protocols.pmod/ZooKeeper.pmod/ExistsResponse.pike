inherit .Message;

.Stat stat;

protected variant void create(Stdio.Buffer buf) {
    if(sizeof(buf))
        stat = .Stat(buf);
 }
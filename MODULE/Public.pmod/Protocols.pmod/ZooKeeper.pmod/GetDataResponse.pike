inherit .Message;

string data;
.Stat stat;

protected variant void create(Stdio.Buffer buf) {
    data = read_buffer(buf);
    stat = .Stat(buf);
 }
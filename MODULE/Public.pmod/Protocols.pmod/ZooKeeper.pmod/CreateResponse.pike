inherit .Message;

string path;

protected variant void create(Stdio.Buffer buf) {
    path = read_string(buf);
 }
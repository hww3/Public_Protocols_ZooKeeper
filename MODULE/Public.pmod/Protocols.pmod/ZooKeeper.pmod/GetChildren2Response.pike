inherit .Message;

array(string) children;
.Stat stat;

protected variant void create(Stdio.Buffer buf, .ReplyHeader reply_header) {
    int child_count = read_int32(buf);
    children = allocate(child_count);
    
    for(int i = 0; i < child_count; i++) 
      children[i] = read_string(buf);
    stat = .Stat(buf);
 }
 
 public mixed return_results() { return (["children": children, "stat": stat]); }
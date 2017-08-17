inherit .Message;

array(.ACL) acls;
.Stat stat;

protected variant void create(Stdio.Buffer buf) {
    int acl_count = read_int32(buf);
    acls = allocate(acl_count);
    
    for(int i = 0; i < acl_count; i++) 
      acls[i] = .ACL(buf);
    
    stat = .Stat(buf);
 }
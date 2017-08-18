object p;

int main() {

  p = Public.Protocols.ZooKeeper.client("zk://localhost");
 p->set_synchronous(true); 
 p->connect();
  
  mixed err;

  object acl = p->get_acl("/");
  
  werror("acl: %O\n", acl);
  int exists = p->exists("/foo/bar/gazonk3", 1, watch_cb, "watcher");
  werror("exists? %O\n", exists);
  
  if(!exists) {
    if(err = catch(werror("create: %O", p->create_node("/foo/bar/gazonk3", "whee", ({acl})))))
    werror("exception occurred: %O\n", err);
	p->set_acl("/foo/bar/gazonk3", ({Public.Protocols.ZooKeeper.OPEN_ACL_UNSAFE}));
    }
    
    p->start_transaction();
    
    int t =  time();
    for(int i = 0; i < 3; i++) {
      //p->add_create_node("/foo/bar/tx" + t + i, "whee" + i, ({Public.Protocols.ZooKeeper.OPEN_ACL_UNSAFE}));
      //p->add_set_data("/foo/bar/tx" + t + i, "lalala" + i);
      p->add_check_version("/foo/bar/tx" + t + i, -1);
    }
    
    mixed res = p->commit_transaction();
    werror("tx res: %O\n", res);
    
  //else p->delete("/foo/bar/gazonk3");
  //werror("version? %O\n", p->check_version("/foo/bar/gazonk3", -1));
 // werror("create: %O", p->create_node_ttl("/foo/bar/gazonk4", "whee", ({acl}), 0, 15000));
  
  werror("children: %O", p->get_children2("/foo/bar"));
//  if(err = catch(werror("set_data: %O", p->set_data("/foo/bar", "hww3"))))
p->disconnect();
return 0;
}

void watch_cb(object event, string f) {
  werror("WATCH_EVENT: %O, %O\n", event, f);
}

void quit()
{
	p->disconnect();
	call_out(exit, 1, 0);
}

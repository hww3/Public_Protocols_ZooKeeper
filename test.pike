object p;

int main() {

  p = Public.Protocols.ZooKeeper.client(({"zk://localhost", "zk://localhost:1234"}));
  p->set_auth("foo", "bar");
  p->connect(has_connected);
  werror("Client: %O\n", p);
 return -1;

}

public void has_connected(mixed ... args) {
  werror("has_connected(%O)\n", args);
  mixed err;

  object acl = p->get_acl("/");
  
  werror("acl: %O\n", acl);
  int exists = p->exists("/foo/bar/gazonk3", 1, watch_cb, "watcher");
  werror("exists? %O\n", exists);
  
  return;
  if(!exists) {
    if(err = catch(werror("get_acl: %O", p->create_node("/foo/bar/gazonk3", "whee", ({acl})))))
    werror("exception occurred: %O\n", err);
    }
  else p->delete("/foo/bar/gazonk3");
//  if(err = catch(werror("set_data: %O", p->set_data("/foo/bar", "hww3"))))
  call_out(quit, 2);
}

void watch_cb(object event, string f) {
  werror("WATCH_EVENT: %O, %O\n", event, f);
}

void quit()
{
	p->disconnect();
	call_out(exit, 1, 0);
}

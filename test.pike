object p;

int main() {

  p = Public.Protocols.ZooKeeper.client("zk://localhost");
  werror("Client: %O\n", p);
  p->connect(has_connected);
  werror("Client: %O\n", p);
 return -1;

}

public void has_connected(mixed ... args) {
  werror("has_connected(%O)\n", args);
  werror("get_data: %O", p->get_data("/foo/bar"));
  call_out(quit, 2);
}

void quit()
{
	p->disconnect();
	call_out(exit, 1, 0);
}

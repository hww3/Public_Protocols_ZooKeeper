object p;

int main() {

  p = Public.Protocols.ZooKeeper.client("zk://localhost");
  werror("Client: %O\n", p);
  p->connect();
  werror("Client: %O\n", p);
 return -1;

}

public void has_connected(mixed ... args) {
  werror("has_connected(%O)\n", args);
}

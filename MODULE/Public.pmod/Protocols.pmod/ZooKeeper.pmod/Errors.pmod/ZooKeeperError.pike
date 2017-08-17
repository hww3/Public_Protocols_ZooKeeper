inherit Error.Generic;

constant error_name = "ZooKeeperError";
constant nice_error_name = "ZooKeeper Error";
constant zookeeper_error_code = 9999;
constant is_zookeeper_error = 1;

protected variant void create(string message, void|array backtrace) {
  ::create(message, backtrace);
}

protected variant void create(int xid, int zxid) {
  // hide this function from the backtrace
  mixed bt = predef::backtrace()[0..<2];

  ::create(nice_error_name + ": xid=" + xid + ", zxid=" + zxid + "\n", bt);
}
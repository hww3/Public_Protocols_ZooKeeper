inherit .serialization_utils;

long czxid;      // created zxid
long mzxid;      // last modified zxid
long ctime;      // created
long mtime;      // last modified
int version;     // version
int cversion;    // child version
int aversion;    // acl version
long ephemeral_owner; // owner id if ephemeral, 0 otw
int data_length;  //length of the data in the node
int num_children; //number of children of this node
long pzxid; // last modified children

protected void create(Stdio.Buffer buf) {
  czxid = read_int64(buf);
  mzxid = read_int64(buf);
  ctime = read_int64(buf);
  mtime = read_int64(buf);
  version = read_int32(buf);
  cversion = read_int32(buf);
  aversion = read_int32(buf);
  ephemeral_owner = read_int64(buf);
  data_length = read_int32(buf);
  num_children = read_int32(buf);
  pzxid = read_int64(buf);

}
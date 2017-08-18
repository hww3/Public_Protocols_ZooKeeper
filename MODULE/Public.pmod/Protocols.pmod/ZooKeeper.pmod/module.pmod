mapping(int:program(Public.Protocols.ZooKeeper.Errors.ZooKeeperError)) errors_by_code = ([]);
mapping(int:program(Public.Protocols.ZooKeeper.Message)) messages_by_type = ([]);

protected void create() {

   foreach(mkmapping(indices(.Errors), values(.Errors));mixed k;mixed prog) {
//      werror("errors: k: %O v: %O\n", k, prog);
      errors_by_code[prog->zookeeper_error_code] = prog;
   }
   
   foreach(mkmapping(indices(Public.Protocols.ZooKeeper), values(Public.Protocols.ZooKeeper)); mixed k; mixed prog) {
     if(programp(prog)) {
       if(has_index(prog, "MESSAGE_ID") && prog->MESSAGE_ID >0) 
         messages_by_type[prog->MESSAGE_ID] = prog;
     }
   }
//   werror("errors_by_code: %O\n", errors_by_code);
//   werror("messages_by_type: %O\n", messages_by_type);
   
}

constant PERMIT_READ = 1;
constant PERMIT_WRITE = 2;
constant PERMIT_CREATE = 4;
constant PERMIT_DELETE = 8;
constant PERMIT_ADMIN = 16;
constant PERMIT_ALL = 31;

constant CREATED_EVENT = 1;
constant DELETED_EVENT = 2;
constant CHANGED_EVENT = 3;
constant CHILD_EVENT = 4;

// Shortcuts for common Ids
final .Id ANYONE_ID_UNSAFE = .Id("world", "anyone");
final .Id AUTH_IDS = .Id("auth", "");

// Shortcuts for common ACLs
final .ACL OPEN_ACL_UNSAFE = .ACL(PERMIT_ALL, ANYONE_ID_UNSAFE);
final .ACL CREATOR_ALL_ACL = .ACL(PERMIT_ALL, AUTH_IDS);
final .ACL READ_ACL_UNSAFE = .ACL(PERMIT_READ, ANYONE_ID_UNSAFE);

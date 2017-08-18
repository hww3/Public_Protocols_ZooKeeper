inherit .Message;

ADT.List results;

protected variant void create(Stdio.Buffer buf, .ReplyHeader header) {
   
   results = ADT.List();
   .MultiHeader h;
   
   do {
     object response;
     program mp;
     
     h = .MultiHeader(buf, header);
     int type = h->get_type();
     if(type == -1) {
        if(h->get_done()) break; // done means not an error.
        int err = h->get_err();
        int err2 = read_int32(buf);
        if(err != err2) throw(Error.Generic("Whoa, got inconsistent error data from ZK: " + err + "/" + err2 + "\n"));
        program ep = .errors_by_code[err];
        if(!ep) ep = .Errors.ZooKeeperError;
		results->append(ep(header->get_xid(), header->get_zxid()));
     } else if(mp = .messages_by_type[type]) {
       .Message m = mp->response_program(buf, header);
       results->append(m);
     }
     
   } while(!h->get_done());
}

mixed return_results() {
  array resA = allocate(sizeof(results));
  foreach(results; int i; mixed res)
    resA[i] = res->return_results();
    return resA;
}
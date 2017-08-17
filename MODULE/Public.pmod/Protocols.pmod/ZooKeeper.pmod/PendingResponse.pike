#ifdef ZK_DEBUG
#define DEBUG(X ...) werror("ZooKeeper.PendingResponse: " + X)
#else
#define DEBUG(X ...)
#endif /* ZK_DEBUG */

int message_identifier;
.Message message;
.Message original_message;
.Errors.ZooKeeperError error;
mixed timeout_callout_id;
function(.PendingResponse:void) success;
function(.PendingResponse:void) failure;
int timeout;
int timeout_timestamp;
object client;
mixed data;

protected void create(object client, int message_identifier, .Message orig, int timeout) {
  this.client = client;
  this.message_identifier = message_identifier;
  this.original_message = orig;
  this.timeout = timeout;

  if(timeout)
    configure();
}

protected void configure() {
  timeout_timestamp = timeout + time();
  timeout_callout_id = call_out(failure_callout, timeout, this);
}

protected void failure_callout(.PendingResponse response) {
 
  DEBUG("Timed out waiting for response to message_identifier=%d, max_retries reached.\n", message_identifier);

    client->unregister_pending(message_identifier);
    if(failure) failure(this);
}

void destroy() {
  if(timeout_callout_id) remove_call_out(timeout_callout_id);
}

void received_message(.Message message) {
  this.message = message;
  if(timeout_callout_id) remove_call_out(timeout_callout_id);
  if(timeout) client->unregister_pending(message_identifier); // messages with no timeout will be handled synchronously.
  if(success) success(this);
}

void received_exception(Error.Generic err) {
//werror("got an exception from message: %O\n", original_message);
  this.error = err;
  if(timeout_callout_id) remove_call_out(timeout_callout_id);
  if(timeout) client->unregister_pending(message_identifier); // messages with no timeout will be handled synchronously.
  if(failure) failure(this);

}
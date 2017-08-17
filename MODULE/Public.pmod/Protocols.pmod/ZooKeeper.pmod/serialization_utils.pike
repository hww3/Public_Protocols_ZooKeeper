typedef int(0..1) boolean;
typedef int long;

void encode_string(Stdio.Buffer buf, string str) {
  if(!strlen(str))
    buf->add_int32(-1);
  else
    buf->add_hstring(string_to_utf8(str), 4);
}

void encode_buffer(Stdio.Buffer buf, string str) {
  if(!strlen(str))
    buf->add_int32(-1);
  else
    buf->add_hstring(str, 4);
}


void encode_int64(Stdio.Buffer buf, int byte) {
  buf->add_int(byte, 8);
}

void encode_int32(Stdio.Buffer buf, int byte) {
  buf->add_int(byte, 4);
}

void encode_byte(Stdio.Buffer buf, int byte) {
  buf->add_int(byte, 1);
}

void encode_word(Stdio.Buffer buf, int word) {
  buf->add_int(word, 2);
}

int read_byte(Stdio.Buffer buf) {
  return buf->read_sint(1);
}

int read_word(Stdio.Buffer buf) {
  return buf->read_sint(2);
}

int read_int32(Stdio.Buffer buf) {
  return buf->read_sint(4);
}

int read_int64(Stdio.Buffer buf) {
 return  buf->read_sint(8);
}

string read_string(Stdio.Buffer buf) {
  return utf8_to_string(buf->read_hstring(4) || "");
}

string read_buffer(Stdio.Buffer buf) {
  return buf->read_hstring(4);
}
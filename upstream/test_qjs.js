const bytes = new Uint8Array(8192);
try {
  String.fromCharCode.apply(null, bytes);
  console.log("8192 OK");
} catch(e) {
  console.log("8192 FAIL: " + e);
}

const bytes2 = new Uint8Array(65536);
try {
  String.fromCharCode.apply(null, bytes2);
  console.log("65536 OK");
} catch(e) {
  console.log("65536 FAIL: " + e);
}

// Expecting secondary_member_id and secondary_host to be passed in
var ret = rs.add({
  _id: secondary_member_id,
  host: secondary_host,
  votes: 0,
  priority: 0
})

if (!ret["ok"]) {
  printjson(ret);
  quit(1);
}

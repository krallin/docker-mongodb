// Expecting:
// replica_set_name
// primary_member_id
// primary_host

var ret = rs.initiate({
  _id: replica_set_name,
  members: [{
    _id: primary_member_id,
    host: primary_host
  }]
});

if (!ret["ok"]) {
  printjson(ret);
  quit(1);
}

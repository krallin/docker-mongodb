// We expect member_id to be an input that is to be tested.

var conf = rs.conf();
var member;

for (var i = 0; i < conf["members"].length; i++) {
  member = conf["members"][i];
  if (member._id === member_id) {
    print("Member ID is in use");
    printjson(member);
    quit(1);
  }
}

var conf = rs.conf();
var ret = 0;

for (var i = 0; i < conf["members"].length; i++) {
  member = conf["members"][i];
  // In Mongo 2.6, priority and votes aren't returned when
  // they are default (1), so we check for undefined as well.
  if (
      (member.priority !== 1 && typeof member.priority !== 'undefined') ||
      (member.votes !== 1 && typeof member.votes !== 'undefined')
  ) {
    print("MISCONFIGURED: " + member.host);
    printjson(member);
    ret = 1;
  } else {
    print("OK: " + member.host);
  }
}

quit(ret);

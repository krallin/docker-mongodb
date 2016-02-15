var status = rs.status();

var primary = null;
for (var i = 0; i < status["members"].length; i++) {
  member = status["members"][i];
  if (member.stateStr === "PRIMARY" ) {
    primary = member
  }
}

if (!primary) {
  print("Failed to locate primary!");
  quit(1);
} else {
  print("PRIMARY HOST PORT:" + primary.name);
}

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
  printjson(status);
  quit(1);
} else {
  print(extract_prefix + primary.name);
}

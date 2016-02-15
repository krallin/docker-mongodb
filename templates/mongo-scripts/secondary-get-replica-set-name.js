var status = rs.status();

if (!status["ok"]) {
  quit(1);
}

var name = status["set"];
print("REPLICA SET NAME:" + name);

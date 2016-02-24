var conf = rs.isMaster();
var name = conf["me"];
print("SERVER NAME:" + conf["me"]);

// Expecting user_name, user_passphrase and user_db as inputs

var writeConcern = {"w": 1, "j": true};

db.getSiblingDB(user_db).createUser({
  "user": user_name, "pwd": user_passphrase, "roles": ["dbOwner"]
}, writeConcern);

db.getSiblingDB("admin").createUser({
  "user": user_name, "pwd": user_passphrase, "roles": ["clusterAdmin", "root"]
}, writeConcern);

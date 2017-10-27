// Expect replica_set_name to be set as a variable.
var local = db.getSiblingDB('local');
var ret = local.system.replset.remove({ _id: replica_set_name });

if (ret.nRemoved <= 0) {
  quit(1);
}

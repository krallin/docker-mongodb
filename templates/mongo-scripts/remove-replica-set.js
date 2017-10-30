var local = db.getSiblingDB('local');
var ret = local.dropDatabase();

if (!ret.ok) {
  quit(1);
}

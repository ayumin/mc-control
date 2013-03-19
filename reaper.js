var config = require('./configure');
var redis = config.createRedisClient()

var reaper_seconds = 2;

//shared
function time() { return (new Date()).getTime() }

prune_devices = function(){
  redis.zremrangebyscore('devices', 0, time());
}

setInterval(prune_devices, (reaper_seconds * 1000));

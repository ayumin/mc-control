var config = require('./configure');
var redis = config.createRedisClient()

var reaper_seconds = 2

//shared
function time() { return (new Date()).getTime() }

prune_devices = function(){
  redis.zremrangebyscore('devices', 0, time());
}

setInterval(prune_devices, (reaper_seconds * 1000));

set_throughput = function(){
  redis.get('readings-count', function(err, count){
    redis.set('readings-throughput', count / reaper_seconds, function(error, count){
      redis.set('readings-count', 0)
    })
  })
}

setInterval(set_throughput, (reaper_seconds * 1000));

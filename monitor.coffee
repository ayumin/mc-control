config = require './configure'
redis = config.createRedisClient()

now = -> (new Date()).getTime()

# Prune Device List
reaper_seconds  = 2
reaper_interval = reaper_seconds * 1000
prune_devices   = -> redis.zremrangebyscore('devices', 0, now());
setInterval prune_devices, reaper_interval

# Measure Readings Throughput
throughput_seconds  = 1
throughput_interval = 1000
set_throughput = ->
  redis.get 'readings-count', (err, count) ->
    throughput = count / throughput_seconds
    redis.set 'readings-throughput', throughput , (err, count) ->
      console.log "throughput=#{throughput}"
      redis.set 'readings-count', 0
setInterval set_throughput, throughput_interval

# Send out Mothership readings
mothershipReadings = ->
  readings = {}
  redis.zcard "devices", (err, connections) ->
    redis.get 'readings-throughput', (err, count) ->
      readings.throughput  = count
      readings.connections = connections
      io.sockets.in('mothership').emit('mothership-readings', readings)

setInterval mothershipReadings, mothership_interval * 1000

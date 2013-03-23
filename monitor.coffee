config = require './configure'
http   = require("http")
redis  = config.createRedisClient()

readings_interval = parseInt(process.env.READINGS_INTERVAL || 5)
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

io = require("socket.io").listen(http.createServer())

io.configure "production", ->
  io.set "transports", process.env.TRANSPORTS.split(',')
  io.set "polling duration", 7
  io.enable 'browser client minification'
  io.enable 'browser client etag'
  io.enable 'browser client gzip'
  io.set 'log level', parseInt(process.env.SOCKETIO_LOG_LEVEL || 1)

# redis pub/sub
io.configure ->
  io.set "heartbeat interval", 10

  if (!process.env.SINGLE_DYNO_MODE)
    RedisStore = require("socket.io/lib/stores/redis")
    io.set 'store', new RedisStore
      redis    : require("redis")
      redisPub : config.createRedisClient()
      redisSub : config.createRedisClient()
      redisClient : config.createRedisClient()

# Send out Mothership readings
mothershipReadings = ->
  readings = {}
  redis.zcard "devices", (err, connections) ->
    redis.get 'readings-throughput', (err, count) ->
      readings.throughput  = count
      readings.connections = connections
      io.sockets.in('mothership').emit('mothership-readings', readings)

setInterval mothershipReadings, readings_interval * 1000

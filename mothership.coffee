# Device MotherShip
#
coffee = require("coffee-script")
config = require("./configure")
express = require("express")
redis = config.createRedisClient()
tempo = require("./tempo")
moment = require('moment')

connection_expiry_seconds = parseInt(process.env.CONNECTION_EXPIRY || "30")
mothership_interval       = parseInt(process.env.MOTHERSHIP_INTERVAL || 5)

time = -> (new Date()).getTime()

app = express.createServer()

ensure_auth = express.basicAuth (user, pass, cb) ->
  if pass is process.env.HTTP_PASSWORD
    cb null, pass
  else
    cb "fail"

io = require("socket.io").listen(app)
config.configure app, io

# Mothership Home Page
app.get "/", ensure_auth, (req, res) ->
  res.render "analytics", title:"Machine Cloud Control Center"

# Mothership Device List
app.get "/devices", ensure_auth, (req, res) ->
  res.render "index",
    title: "Machine Cloud Control Center"

# Sensor Control Interface
app.get "/sensor/:id", ensure_auth, (req, res) ->
  res.render "device",
    title: "Machine Cloud Control Center"
    device_id: req.param("id")

# History API
app.get "/sensor/:id/history/hour", tempo.history

# Sensor Contral API
app.get "/sensor/:id/set/:key/:value", (req, res) ->
  message = {}
  message[req.param("key")] = req.param("value")

  io.sockets.in(req.param('id')).emit('control-device', message)
  res.setHeader "Access-Control-Allow-Origin", "*"
  res.send "OK"

# User <-> Device API
app.get "/user/:user/device", (req, res) ->
  redis.get "user:" + req.params.user + ":device", (err, device) ->
    console.log "device", device
    res.send JSON.stringify(device)

app.post "/user/:user/device", (req, res) ->
  redis.set "user:" + req.params.user + ":device", req.body.device, (err) ->
    res.send "ok"

app.delete '/user/:user/device', (req, res) ->
  redis.del 'user:' + req.params.user + ':device', (err) ->
    res.send('ok')

control_readings = (readings) ->
  if readings.battery and readings.battery < 1
    init: true

refresh_device_connection = (device_id) ->
  t = time() + (connection_expiry_seconds * 1000)
  redis.zadd "devices", t, device_id

device_key = (id) => "device:#{id}"

last_readings = (readings, callback) ->
  key = device_key(readings.device_id)
  redis.hgetall key, (err, result) ->
    callback(result || {})
    redis.hmset key, status:  readings.status
    location = {}
    location[readings.device_id] = "#{readings.lat},#{readings.long}"
    redis.hmset "device:locations", location


# Setup WebSockets
io.sockets.on "connection", (socket) ->
  socket.on "listen-device", (device_id) ->
    redis.del(device_key(device_id))
    socket.join device_id
    console.log "listen-device", device_id

  socket.on "listen-mothership", ->
    socket.join "mothership"
    init_packet = {}
    redis.zrange "devices", 0, -1, (error, devices) ->
      init_packet.devices = devices or []
      redis.hgetall "device:locations", (err, locations) ->
        init_packet.locations = locations
        socket.emit 'mothership-init', init_packet

  socket.on "register-device", (device_id, readings) ->
    socket.set "device-id", device_id, ->
      socket.join device_id
      refresh_device_connection device_id
      io.sockets.in('mothership').emit('add-device', device_id, readings)
      console.log "register-device", device_id

  #Sensor Reporting API
  socket.on "readings", (readings) ->
    device = readings.device_id
    if device
      redis.incr 'readings-count'
      refresh_device_connection device
      last_readings readings, (last) ->
        #console.log("LAST", last, readings)
        if last.status == 'OK' and readings.status == 'FAIL'
          redis.hmget "device:locations", device, (err, location) ->
            [lat, long] = (location || "").toString().split(",")
            console.log("code=42 failure=true device_id=#{device} lat=#{lat} long=#{long}")

      readings.time = moment().format()

      logline = ("#{key}=#{value}" for key, value of readings).join(' ')
      console.log(logline + " readings=true")

      #broadcast to everyone in room besides this socket
      for client in io.sockets.clients(readings.device_id)
        client.emit "readings", readings unless client is socket

      #check for control response
      if message = control_readings(readings)
        io.sockets.in(readings.device_id).emit('control-device', message)

  socket.on "disconnect", ->
    #cleanup when a device disconnects
    socket.get "device-id", (err, id) ->
      io.sockets.in('mothership').emit('remove-device', id)
      redis.zrem "devices", id
      redis.del(device_key(id))
      redis.hdel "device:locations", id
      console.log "device-disconnect=" + id

mothershipReadings = ->
  readings = {}
  redis.zcard "devices", (err, connections) ->
    redis.get 'readings-count', (err, count) ->
      readings.throughput  = (count / mothership_interval)
      readings.connections = connections
      io.sockets.in('mothership').emit('mothership-readings', readings)
      redis.set 'readings-count', 0

setInterval mothershipReadings, mothership_interval * 1000

app.listen process.env.PORT or 3000, ->
  console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env

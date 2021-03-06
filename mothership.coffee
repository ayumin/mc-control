# Device MotherShip
#
agent = require("superagent")
async = require("async")
coffee = require("coffee-script")
config = require("./configure")
express = require("express")
redis = config.createRedisClient()
tempo = require("./tempo")
moment = require('moment')

FAIL = /fail/i
OK   = /ok/i
RECALL = /recall/i

connection_expiry_seconds = parseInt(process.env.CONNECTION_EXPIRY || "30")

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

app.get "/admin/fail_many", ensure_auth, (req, res) ->
  num = req.query.num || 10
  console.log "fail_many num=#{num}"
  redis.zrange "devices", 0, -1, (error, devices) ->
    devices.unshift "raspi.mc-device01"
    devices.unshift "raspi.mc-device02"
    devices.unshift "raspi.mc-device03"
    async.parallel (devices[1..num].map (device_id) ->
      (callback) -> fail(device_id, callback)),
      () -> res.send "ok"

control_readings = (readings) ->
  if readings.battery and readings.battery <= 2
    init: true

refresh_device_connection = (device_id) ->
  t = time() + (connection_expiry_seconds * 1000)
  redis.zadd "devices", t, device_id

device_key = (id) => "device:#{id}"

last_readings = (readings, callback) ->
  key = device_key(readings.device_id)
  redis.hgetall key, (err, result) ->
    redis.hmset key,
      status: readings.status
      lat: readings.lat.toString()
      long: readings.long.toString()
      temp: readings.temp.toString()
      battery: readings.battery.toString()
    callback(result || {})

compare_with_last_readings = (readings) ->
  last_readings readings, (last) ->
    if (!RECALL.test(last.status)) and RECALL.test(readings.status)
      redis.hget device_key(readings.device_id), 'push_token', (err, push_token) ->
        # get push token from the environment
        push_token = process.env.PUSH_TOKEN
        logline = "recall=true device_id=#{readings.device_id} push_token=#{push_token}"
        console.log(logline)

    if (!FAIL.test(last.status)) and FAIL.test(readings.status)
      logline = "code=42 failure=true device_id=#{readings.device_id}"
      logline += " lat=#{readings.lat} long=#{readings.long}"
      console.log(logline)

fail_url = (device_id) ->
  "#{process.env.API_URL}/sensor/#{device_id}/set/status/FAIL"

fail = (device_id, async_callback) ->
  console.log('fail', device_id)
  console.log(fail_url(device_id))
  agent
    .get(fail_url(device_id))
    .end (err, res) ->
      console.log err if err
      console.log('failed', device_id)
      async_callback()

stream_devices_and_locations = (socket) ->
  redis.zrange "devices", 0, -1, (error, devices) ->
    devices.map (device) ->
      redis.hgetall device_key(device), (err, readings) ->
        readings ||= {}
        socket.emit 'add-device', device,
          lat: readings.lat
          long: readings.long

# Setup WebSockets
io.sockets.on "connection", (socket) ->
  socket.on "listen-device", (device_id) ->
    redis.del device_key(device_id)
    socket.join device_id
    console.log "listen-device", device_id

  socket.on "listen-device-hash", (data) ->
    redis.del device_key(data.id), ->
      redis.hset device_key(data.id), 'push_token', data.push_token || ''
    socket.join data.id
    console.log "listen-device", data.id

  socket.on "listen-mothership", ->
    socket.join "mothership"
    stream_devices_and_locations socket

  socket.on "register-device", (device_id, readings) ->
    socket.set "device-id", device_id, ->
      socket.join device_id
      refresh_device_connection device_id
      io.sockets.in('mothership').emit('add-device', device_id, readings)
      console.log "register-device", device_id

  #Sensor Reporting API
  socket.on "readings", (readings) ->
    if device = readings.device_id
      redis.incr 'readings-count'
      refresh_device_connection device
      compare_with_last_readings readings

      # log the readings
      readings.time = moment().format()
      logline = ("#{key}=#{value}" for key, value of readings).join(' ')
      console.log(logline + " readings=true")

      #broadcast to everyone in room besides this socket
      for client in io.sockets.clients(device)
        client.emit "readings", readings unless client is socket

      #check for control response
      if message = control_readings(readings)
        io.sockets.in(device).emit('control-device', message)

  socket.on "disconnect", ->
    #cleanup when a device disconnects
    console.log "socket-disconnect=true"
    socket.get "device-id", (err, id) ->
      return unless id
      console.log "device-disconnect-start=#{id}"
      io.sockets.in('mothership').emit('remove-device', id)
      redis.zrem "devices", id
      redis.del device_key(id)
      console.log "device-disconnect=" + id

app.listen process.env.PORT or 3000, ->
  console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env

# Device MotherShip
#
coffee = require("coffee-script")
express = require("express")
app = module.exports = express.createServer()
io = require("socket.io").listen(app)
config = require("./configure")
config.configure app, io
redis = config.createRedisClient()
tempo = require("./tempo")
connection_expiry_seconds = 20

time = -> (new Date()).getTime()

# Mothership Home Page
app.get "/", (req, res) ->
  res.render "index",
    title: "The Mothership"

# Sensor Control Interface
app.get "/sensor/:id", (req, res) ->
  res.render "device",
    title: "The Mothership"
    device_id: req.param("id")

# History API
app.get "/sensor/:id/history/hour", tempo.history

# Sensor Contral API
app.get "/sensor/:id/set/:key/:value", (req, res) ->
  message = {}
  message[req.param("key")] = req.param("value")

  io.sockets.in(req.param('id')).emit('control-device', message)
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

# Setup WebSockets
io.sockets.on "connection", (socket) ->
  socket.on "listen-device", (device_id) ->
    socket.join device_id
    console.log "listen-device", device_id

  socket.on "listen-mothership", -> socket.join "mothership"

  socket.on "register-device", (device_id) ->
    socket.set "device-id", device_id, ->
      socket.join device_id
      refresh_device_connection device_id
      console.log "register-device", device_id

  #Sensor Reporting API
  socket.on "readings", (readings) ->
    refresh_device_connection readings.device_id

    #broadcast to everyone in room besides this socket
    for client in io.sockets.clients(readings.device_id)
      client.emit "readings", readings unless client is socket

    #check for control response
    if message = control_readings(readings)
      io.sockets.in(readings.device_id).emit('control-device', message)

  socket.on "disconnect", ->
    #cleanup when a device disconnects
    socket.get "device-id", (err, id) ->
      redis.zrem "devices", id
      console.log "device-disconnect=" + id

mothershipReadings = ->
  readings = {}
  redis.zrange "devices", 0, -1, (error, devices) ->
    devices = devices or []
    readings.connections = devices.length
    readings.devices = devices
    io.sockets.in('mothership').emit('mothership-readings', readings);

setInterval mothershipReadings, 2000

app.listen process.env.PORT or 3000, ->
  console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env
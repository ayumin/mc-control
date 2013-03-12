/**
 * Module dependencies.
 */

require('coffee-script');
var express = require('express');
var sensor = require('./sensor');

var app = module.exports = express.createServer();
var io  = require('socket.io').listen(app);

var config = require('./configure');
config.configure(app, io);
var redis = config.createRedisClient()

var TempoDBClient = require('tempodb').TempoDBClient;
var tempodb = new TempoDBClient(process.env.TEMPODB_API_KEY,
                                process.env.TEMPODB_API_SECRET)

function time() { return (new Date()).getTime() }

var connection_expiry_minutes = 5;

//Mothership
app.get('/', function(req, res){
  res.render('index', {
    title: 'The Mothership'
  });
});

//Consumer - Facing Sensor Page
app.get('/consumer/:id', function(req, res){
  res.render('device', {
    title: 'Panasonic.com',
    device_id: req.param('id')
  });
});

// Sensor Control API
app.get('/sensor/:id', function(req, res){
  res.render('device', {
    title: 'The Mothership',
    device_id: req.param('id')
  });
});


app.get('/sensor/:id/set/:key/:value', function(req, res){
  message = {}
  message[req.param('key')] = req.param('value')
  io.sockets.in(req.param('id')).emit('control-device', message)
  res.send('OK');
})

var readings = [];

control_readings = function(readings){
  if(readings.battery && readings.battery < 1){
    return {init: true}
  }
}

tempodb_readings = function(readings){
  var ts = new Date();
  var data = [
    {key: 'battery:' + readings.device_id, v: readings.battery},
    {key: 'temp:' + readings.device_id,    v: readings.temp},
  ];

  tempodb.write_bulk(ts, data, function(result){
    var out = result.response;
    console.log('tempodb='+out);
  })

}

refresh_device_connection = function(device_id) {
  var t = time() + (60 * connection_expiry_minutes) ;
  redis.zadd('devices', t, device_id)
}

prune_devices = function(){
  redis.zremrangebyscore('devices', 0, time());
}
setInterval(prune_devices, 1000 * 30);

//setup websockets
io.sockets.on('connection', function(socket) {

  socket.on('listen-device', function(device_id) {
    socket.join(device_id)
    console.log("listen-device", device_id)
  })

  socket.on('listen-mothership', function() {
    socket.join('mothership');
  })

  socket.on('register-device', function(device_id) {
    socket.set('device-id', device_id, function(){
      socket.join(device_id);
      refresh_device_connection(device_id);
    })
    console.log("register-device", device_id)
  })

  //Sensor Reporting API
  socket.on('readings', function(readings) {
    refresh_device_connection(readings.device_id);

    //broadcast to everyone in room besides this socket
    var clients = io.sockets.clients(readings.device_id)
    for(var i = 0; i < clients.length; i++){
      if(clients[i] != socket){
        clients[i].emit('readings', readings)
      }
    }

    //check for control response
    var message;
    if(message = control_readings(readings)){
      io.sockets.in(readings.device_id).emit('control-device', message)
    }

    tempodb_readings(readings)
  })

  socket.on('disconnect', function(){
    //cleanup when a device disconnects
    socket.get('device-id', function(err, id){
      console.log("device-disconnect=" + id);
    })
  })

})

mothershipReadings = function(){
  readings = {}
  redis.zrange('devices', 0, -1, function(error, devices){
    console.log(devices)
    devices = devices || [];
    readings.connections = devices.length;
    readings.devices = devices;
    io.sockets.in('mothership').emit('mothership-readings', readings);
  })
}

setInterval(mothershipReadings, 2000);

app.on('error', function(){ console.log(e) })
app.listen(process.env.PORT || 3000);
console.log("Express server listening on port %d in %s mode", app.address().port, app.settings.env);

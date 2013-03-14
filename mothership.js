/**
 * Module dependencies.
 */
var express = require('express');

var app = module.exports = express.createServer();
var io  = require('socket.io').listen(app);

var config = require('./configure');
config.configure(app, io);
var redis = config.createRedisClient()

function time() { return (new Date()).getTime() }

var connection_expiry_seconds = 20;

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

app.get('/user/:user/device', function(req, res) {
  redis.get('user:' + req.params.user + ':device', function(err, device) {
    console.log('device', device);
    res.send(JSON.stringify(device))
  });
});

app.post('/user/:user/device', function(req, res) {
  redis.set('user:' + req.params.user + ':device', req.body.device, function(err) {
    res.send('ok');
  });
});

app.delete('/user/:user/device', function(req, res) {
  redis.del('user:' + req.params.user + ':device', function(err) {
    res.send('ok');
  });
});

var readings = [];

control_readings = function(readings){
  if(readings.battery && readings.battery < 1){
    return {init: true}
  }
}

refresh_device_connection = function(device_id) {
  var t = time() + (connection_expiry_seconds * 1000) ;
  redis.zadd('devices', t, device_id)
}


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

  })

  socket.on('disconnect', function(){
    //cleanup when a device disconnects
    socket.get('device-id', function(err, id){
      redis.zrem('devices', id)
      console.log("device-disconnect=" + id);
    })
  })

})

mothershipReadings = function(){
  readings = {}
  redis.zrange('devices', 0, -1, function(error, devices){
    devices = devices || [];
    readings.connections = devices.length;
    readings.devices = devices;
    io.sockets.in('mothership').emit('mothership-readings', readings);
  })
}

setInterval(mothershipReadings, 2000);

app.on('error', function(e) { console.log('error:' + e) })

app.listen(process.env.PORT || 3000, function() {
  console.log("Express server listening on port %d in %s mode", app.address().port, app.settings.env);
});

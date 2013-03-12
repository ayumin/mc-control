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

  console.log(data);

  tempodb.write_bulk(ts, data, function(result){
    var out = result.response;
    if (result.body) {
        out += ': ' + JSON.stringify(result.body);
    }
    console.log('tempodb='+out+'\n');
  })

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
      redis.sadd('devices', device_id, redis.print)
      socket.join(device_id);
    })
    console.log("register-device", device_id)
  })

  //Sensor Reporting API
  socket.on('readings', function(readings) {
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
      redis.srem('devices', id, redis.print)
      console.log("device-disconnect=" + id);
    })
  })

})


mothershipReadings = function(){
  readings = {}
  redis.scard('devices', function(error, connections){
    readings.connections = connections;
    redis.smembers('devices', function(error, devices){
      readings.devices = devices;
      io.sockets.in('mothership').emit('mothership-readings', readings);
    })
  })
}

setInterval(mothershipReadings, 2000);

app.on('error', function(){ console.log(e) })
app.listen(process.env.PORT || 3000);
console.log("Express server listening on port %d in %s mode", app.address().port, app.settings.env);

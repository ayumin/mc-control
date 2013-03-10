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
var redis_client = config.createRedisClient()

//Consumer - Facing Sensor Page
app.get('/consumer/:id', function(req, res){
  res.render('index', {
    title: 'Panasonic.com',
    device_id: req.param('id')
  });
});

// Sensor Control API
app.get('/sensor/:id', function(req, res){
  res.render('index', {
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

control_readings = function(readings){
  if(readings.battery && readings.battery < 1){
    return {init: true}
  }
  return null;
}

//setup websockets
io.sockets.on('connection', function(socket) {

  socket.on('register', function(device_id) {
    console.log("register", device_id)
    socket.join(device_id)
  })

  //Sensor Reporting API
  socket.on('readings', function(readings) {
    //broadcast to everyone in room besides this socket
    var clients = io.sockets.clients(readings.device_id)
    for(var i = 0; i < clients.length; i++){
      if(clients[i] != socket){
        clients[i].emit('update', readings)
      }
    }

    //check for control response
    var message;
    if(message = control_readings(readings)){
      io.sockets.in(readings.device_id).emit('control-device', message)
    }
  })

})

app.listen(process.env.PORT || 3000);
console.log("Express server listening on port %d in %s mode", app.address().port, app.settings.env);

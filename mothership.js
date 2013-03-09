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

//Sensor Reporting API
app.post('/sensor/report/:id', function(req, res){
  console.log(req.body);
  //update listening websockets
  io.sockets.in(req.param('id')).emit('update', req.body)
  //ship it to tempodb
  res.send('OK');
})

// Sensor Control API
app.get('/sensor/:id', function(req, res){
  res.render('index', {
    title: 'The Mothership',
    device_id: req.param('id')
  });
});

app.get('/sensor/:id/fail', function(req, res){
  s = new sensor.TempSensor(req.param('id'));
  s.fail();
  res.send('OK');
})

app.get('/sensor/:id/set/:reading/:level', function(req, res){
  s = new sensor.TempSensor(req.param('id'))
  s.set_reading(req.param('reading'), req.param('level'));
  res.send('OK');
})

//setup websockets
io.sockets.on('connection', function(socket) {

  socket.on('register', function(device_id) {
    console.log("register", device_id)
    socket.join(device_id)
  })

})

app.listen(3000);
console.log("Express server listening on port %d in %s mode", app.address().port, app.settings.env);

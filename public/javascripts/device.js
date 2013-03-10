$(function() {

  device_id  = function() {
    return $('#device').attr('data-id');
  }

  var socket = io.connect();

  //register interest in the list
  register = function(){
    socket.emit('register', device_id())
  }
  socket.on('connect', function() { register() })

  //setup the websocket
  socket.on('update', function(readings){
    $('#temp').text(readings.temp);
    $('#battery').text(readings.battery);
    $('#status').text(readings.status);
  })

  socket.on('control-device', function(message){
    $('#control-message .message').text(' ' + JSON.stringify(message));
    $('#control-message').show();
  })

  $('#control-message').hide();
})

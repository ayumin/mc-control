$(function() {
  var socket = io.connect();

  device_id  = function() {
    return $('#device').attr('data-id');
  }

  //register interest in the list
  register = function(){
    socket.emit('register', device_id())
  }

  register();

  //setup the websocket
  socket.on('update', function(readings){
    console.log('update');
    $('#temp').text(readings.temp);
    $('#battery').text(readings.battery);
    $('#status').text(readings.status);
    console.log(readings);
  })

})

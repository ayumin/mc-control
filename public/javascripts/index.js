$(function() {

  var socket = io.connect();

  socket.on('connect', function(){
    socket.emit('listen-mothership');
  });

  socket.on('mothership-readings', function(readings){
    console.log(readings);
    $('#num_devices').text(readings.connections)

    $devices = $('#devices')
    $devices.empty()
    $.each(readings.devices.sort(), function(i, device_name){
      var $a = $('<a>').
        attr('href', '/sensor/' + device_name).
        text(device_name)
      var $li = $('<li>').append($a)
      $devices.append($li)
    })
  })

})

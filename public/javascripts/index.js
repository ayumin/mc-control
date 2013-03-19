DEBUG=false
$(function() {

  var socket = io.connect();

  socket.on('connect', function(){
    socket.emit('listen-mothership');
  });

  $devices = $('#devices')

  function add_to_list(device_id) {
    var $a = $('<a>').
      attr('href', '/sensor/' + device_id).
      text(device_id)
    var $li = $('<li>').append($a).attr('id', device_id)
    $devices.append($li)
  }

  socket.on('mothership-init', function(data) {
    if(DEBUG) console.log('mothership-init', data)
    $.each(data.devices.sort(), function(){ add_to_list(this) })
  })

  socket.on('mothership-readings', function(readings) {
    $('#num_devices').text(readings.connections)
    console.log("Devices: " + readings.connections)
    if(readings.connections == 0) $devices.empty()
  })

  socket.on('add-device', function(device, readings) {
    if(DEBUG) console.log('add-device', device, readings)
    add_to_list(device)
  })

  socket.on('remove-device', function(device) {
    $('#' + device).remove()
  })

})

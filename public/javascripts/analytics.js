$(function() {

  var map = new google.maps.Map(document.getElementById('map'), {
    center: new google.maps.LatLng(36.893738, 136.502165),
    zoom: 6,
    mapTypeId: google.maps.MapTypeId.ROADMAP,
    panControl: false,
    zoomControl: false,
    streetViewControl: false
  });

  var socket = io.connect();

  socket.on('connect', function(){
    socket.emit('listen-mothership');
  });

  var known_devices = [];
  var markers = {};

  socket.on('mothership-readings', function(readings) {
    $('#device-count').text(readings.connections)

    var current_devices = [];

    $(readings.devices).each(function() {
      var device = this.toString();

      if (!readings.locations || !readings.locations[device])
        return;

      current_devices.push(device);

      if (known_devices.indexOf(device) != -1)
        return;

      var parts = readings.locations[device].split(',');
      var loc = new google.maps.LatLng(parseFloat(parts[0]), parseFloat(parts[1]));
      var marker = new google.maps.Marker({
        position: loc,
        map: map,
        title: 'Device ' + device
      });
      markers[device] = marker;

      known_devices.push(device);
    });

    var gone = known_devices.filter(function(item) {
      return(current_devices.indexOf(item) == -1);
    });

    $(gone).each(function() {
      var device = this.toString();
      markers[device].setMap(null);
      delete markers[device];
      known_devices.splice(known_devices.indexOf(device), 1);
    });
  });

});

$(function() {

  var map = new google.maps.Map(document.getElementById('map'), {
    center: new google.maps.LatLng(36.893738, 136.502165),
    zoom: 6,
    mapTypeId: google.maps.MapTypeId.ROADMAP,
    panControl: false,
    zoomControl: false,
    streetViewControl: false
  });

  var markers = [];

  var socket = io.connect();

  socket.on('connect', function(){
    socket.emit('listen-mothership');
  });

  socket.on('mothership-readings', function(readings) {
    console.log('readings', readings);

    $('#device-count').text(readings.connections)

    $(markers).each(function() {
      this.setMap(null);
    });

    markers = [];

    $(readings.devices).each(function() {
      var device = this.toString();

      if (readings.locations[device]) {
        var parts = readings.locations[device].split(',');
        var loc = new google.maps.LatLng(parseFloat(parts[0]), parseFloat(parts[1]));
        var marker = new google.maps.Marker({
          position: loc,
          map: map,
          title: 'Device ' + device
        });
        markers.push(marker);
      }
    });
  });

});

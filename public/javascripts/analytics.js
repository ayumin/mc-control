DEBUG=false

$(function() {

  var map = new google.maps.Map(document.getElementById('map'), {
    center: new google.maps.LatLng(36.893738, 136.502165),
    zoom: 6,
    mapTypeId: google.maps.MapTypeId.ROADMAP,
    panControl: false,
    zoomControl: true,
    streetViewControl: false
  });

  var socket = io.connect();

  socket.on('connect', function(){ socket.emit('listen-mothership') });

  var known_devices = [];
  var markers = {};
  var locations = {};

  function add_to_map(device, lat, _long) {
    var loc = new google.maps.LatLng(parseFloat(lat), parseFloat(_long));
    var marker = new google.maps.Marker({
      position: loc,
      map: map,
      title: 'Device ' + device,
      url: '/sensor/' + device
    });
    google.maps.event.addListener(marker, 'click', function() {
      window.location.href = marker.url;
    });
    markers[device] = marker;
  }

  socket.on('mothership-init', function(data) {
    if(DEBUG) console.log('mothership-init', data)
    known_devices = data.devices
    locations     = data.locations

    $.each(data.devices, function() {
      if(locations[this]){
        var parts = locations[this].split(',');
        add_to_map(this, parts[0], parts[1])
      }
    })
  })

  socket.on('mothership-readings', function(readings) {
    $('#device-count').text(readings.connections)
    $('#throughput').text(readings.throughput)
    console.log(readings)

    if(readings.connections == 0){
      $.each(markers, function(){
        this.setMap(null);
        delete this;
      })
    }
  })

  socket.on('add-device', function(device, readings) {
    if(DEBUG) console.log('add-device', device, readings)
    add_to_map(device, readings.lat, readings.long)
    known_devices.push(device)
  })

  socket.on('remove-device', function(device) {
    if(DEBUG) console.log('remove-device', device)
    if (markers[device]) {
      markers[device].setMap(null);
      delete markers[device];
    }
    known_devices.splice(known_devices.indexOf(device), 1);
  })
});

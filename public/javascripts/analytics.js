DEBUG=false

$(function() {

  function format_number(number) {
    if (number) {
      return number.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    } else {
      return '--';
    }
  }

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

  var markers = {};
  var locations = {};

  function add_to_map(device, lat, _long) {
    var loc = new google.maps.LatLng(parseFloat(lat), parseFloat(_long));
    var marker = new google.maps.Marker({
      position: loc,
      map: map,
      title: 'Device ' + device,
      url: '/sensor/' + device,
      target: '_blank'
    });
    google.maps.event.addListener(marker, 'click', function() {
      var infowindow = new google.maps.InfoWindow({
        content: "<a href='" + marker.url + "'>" + marker.title + "</a>"
      })
      infowindow.open(map, marker)
    });
    markers[device] = marker;
  }

  socket.on('mothership-readings', function(readings) {
    $('#device-count').text(format_number(readings.connections))
    $('#throughput').text(format_number(readings.throughput))
    if(DEBUG) console.log(readings)

    if(readings.connections == 0){
      $.each(markers, function(){
        this.setMap(null);
      })
      markers.length = 0;
    }
  })

  socket.on('add-device', function(device, readings) {
    if(DEBUG) console.log('add-device', device, readings)
    add_to_map(device, readings.lat, readings.long)
  })

  socket.on('remove-device', function(device) {
    if(DEBUG) console.log('remove-device', device, markers[device])
    if (markers[device]) {
      markers[device].setMap(null);
      delete markers[device];
    }
  })
});

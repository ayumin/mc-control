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

  socket.on('mothership-readings', function(readings) {
    $('#device-count').text(readings.connections)
    console.log('readings', readings);
  });

  $('#location-data li').each(function() {
    var id = $(this).attr('id');
    var parts = $(this).text().split(',')
    var loc = new google.maps.LatLng(parseFloat(parts[0]), parseFloat(parts[1]));
    var marker = new google.maps.Marker({
      position: loc,
      map: map,
      title: 'Device ' + id
    });
    var infowindow = new google.maps.InfoWindow({
      content: 'Device ' + id
    });
  });

});

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

  // subscribe to list of devices
  //

});

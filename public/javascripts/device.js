String.prototype.capitalize = function() {
  return this.charAt(0).toUpperCase() + this.slice(1);
}

$(function() {

  device_id  = function() {
    return $('#device').attr('data-id');
  }

  var socket = io.connect();

  //register interest in the list
  register = function(){
    socket.emit('listen-device', device_id())
  }
  socket.on('connect', function() { register() })

  function bootstrap(){
    return {time: 0, value: 0};
  }

  var temp_data = d3.range(28).map(bootstrap)
  var temp_t    = 0;
  var temp_chart = chart("#tempchart", temp_data);

  var battery_data = d3.range(28).map(bootstrap)
  var battery_t    = 0;
  var battery_chart = chart("#batterychart", battery_data);

  //update all the things when we get new readings
  socket.on('readings', function(readings){
    $('#temp').text(readings.temp);
    $('#battery_readings').text(readings.battery);
    $('#status').text(readings.status);
    $('#city_name').text(readings.city_name.capitalize());
    $('#location').text(readings.lat + ', ' + readings.long);

    //update battery bar
    set_battery(readings.battery);

    //update status string color
    if(readings.status == 'OK'){
      $('#status').css('color', 'green');
    }else if(readings.status.match(/FAIL/)){
      $('#status').css('color', 'red');
    }else{
      $('#status').css('color', '#c09853');
    }

    //update temperature data chart
    temp_data.shift();
    var new_data = {time: temp_t+=1, value: readings.temp};
    console.log(new_data);
    temp_data.push(new_data);
    temp_chart.redraw(temp_data);

    //update battery data chart
    battery_data.shift();
    var new_data = {time: battery_t+=1, value: readings.battery};
    console.log(new_data);
    battery_data.push(new_data);
    battery_chart.redraw(battery_data);
  })

  //show alert on control-device messages
  socket.on('control-device', function(message){
    $alert = $('<div>').addClass('alert')
    $alert.append($('<button>').addClass('close')
                               .attr('data-dismiss', 'alert')
                               .text('x'))
    $alert.append($('<strong>').text("Control message"))
    $alert.append($('<span>').text(' ' + JSON.stringify(message)));
    $('#alerts').append($alert);
  })

})

function set_battery(pct) {
  this.last_battery = pct;

  $bar = $('#battery_level .bar')
  $bar.removeClass('bar-success');
  $bar.removeClass('bar-warning');
  $bar.removeClass('bar-danger');
  $bar.css('width', pct + '%');

  if (pct > 30) {
    $bar.addClass('bar-success');
  } else if (pct > 10) {
    $bar.addClass('bar-warning');
  } else {
    $bar.addClass('bar-danger');
  }
}

function chart(selector, data) {
  var w = 20,
      h = 40;

  var x = d3.scale.linear()
      .domain([0, 1])
      .range([0, w]);

  var y = d3.scale.linear()
      .domain([0, 100])
      .rangeRound([0, h]);

  var chart = d3.select(selector).append("svg")
      .attr("class", "chart")
      .attr("width", w * data.length - 1)
      .attr("height", h);

  chart.selectAll("rect")
      .data(data)
    .enter().append("rect")
      .attr("x", function(d, i) { return x(i) - .5; })
      .attr("y", function(d) { return h - y(d.value) - .5; })
      .attr("width", w)
      .attr("height", function(d) { return y(d.value); });

  chart.append("line")
      .attr("x1", 0)
      .attr("x2", w * data.length)
      .attr("y1", h - .5)
      .attr("y2", h - .5)
      .style("stroke", "#000");

  chart.redraw = function (data) {

    var rect = this.selectAll("rect")
        .data(data, function(d) { return d.time; });

    rect.enter().insert("rect", "line")
        .attr("x", function(d, i) { return x(i + 1) - .5; })
        .attr("y", function(d) { return h - y(d.value) - .5; })
        .attr("width", w)
        .attr("height", function(d) { return y(d.value); })
      .transition()
        .duration(1000)
        .attr("x", function(d, i) { return x(i) - .5; });

    rect.transition()
        .duration(1000)
        .attr("x", function(d, i) { return x(i) - .5; });

    rect.exit().remove();

  }

  return chart;
}


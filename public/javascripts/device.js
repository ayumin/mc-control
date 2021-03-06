String.prototype.capitalize = function() {
  return this.charAt(0).toUpperCase() + this.slice(1);
}

$(function() {

  $('#send_to_device button').click(function(){
    var $key = $('#send_to_device input[name=key]')
    var $value = $('#send_to_device input[name=value]')
    $.get(window.location + "/set/" + $key.val() + "/" + $value.val())
    $key.val('')
    $value.val('')
  })

  device_id  = function() {
    return $('#device').attr('data-id');
  }

  var socket = io.connect();

  //register interest in the list
  register = function(){
    socket.emit('listen-device', device_id())
  }
  socket.on('connect', function() { register() })

  function bootstrap_highcharts(i){
    return {x: (new Date() - ((5-i)*1000)), y: 0};
  }

  function bootstrap(){
    return {time: 0, value: 0};
  }

  Highcharts.setOptions({global: { useUTC: false } });

 $.getJSON(window.location + '/history/hour', function(res, data, xhr) {
    var seed = $.map(res.temp.slice(-20,-1), function(temp) {
      return {x: new Date(temp.t), y: temp.v}
    })
    if(seed.length == 0) seed = d3.range(5).map(bootstrap_highcharts)
    makeTempChart(seed)
  })

  var battery_data = d3.range(28).map(bootstrap)
  var battery_t    = 0;
  var battery_chart = chart("#batterychart", battery_data);

  //update all the things when we get new readings
  socket.on('readings', function(readings){
    $('#temp').text(readings.temp);
    $('#battery_readings').text(readings.battery);
    $('#status').text(readings.status);
    $('#location').text(readings.lat + ', ' + readings.long);

    if(readings.city) {
      $('#city_name').text(readings.city.capitalize());
    }
    if(readings.country) {
      $('#country_name').text(readings.country.capitalize());
    }

    //update battery bar
    set_battery(readings.battery);

    //update status string color
    if(readings.status.match(/ok/i)){
      $('#status').css('color', 'green');
    }else if(readings.status.match(/fail/i)){
      $('#status').css('color', 'red');
    }else{
      $('#status').css('color', '#c09853');
    }

    //update temperature data chart
    if(window.temp_chart) {
      var time = new Date();
      if(readings.time) time = new Date(readings.time);
      val = parseFloat(readings.temp)
      //console.log(time, val)
      //console.log(readings)
      window.temp_chart.series[0].addPoint({x:time, y:val}, true, true);
    }

    //update battery data chart
    battery_data.shift();
    var new_data = {time: battery_t+=1, value: readings.battery};
    //console.log(new_data);
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


function makeTempChart(seed_data) {
console.log(seed_data)
  window.temp_chart = new Highcharts.Chart({
    chart: {
      height: 200,
      renderTo: 'tempchart',
      type: 'spline',
      marginRight: 10,
      marginTop: 0,
      events: {},
    },
    title: {
      text: 'Temperature Readings',
      style: { display:'none' }
    },
    xAxis: {
      type: 'datetime'
    },
    yAxis: {
      title: {
        text: 'Temp'
      },
      plotLines: [{
        value: 0,
        width: 1,
        color: '#808080'
      }]
    },
    tooltip: {
      formatter: function() {
        return '<b>'+ this.series.name +'</b><br/>'+
        Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) +'<br/>'+
        Highcharts.numberFormat(this.y, 2);
      }
    },
    legend: { enabled: false },
    exporting: { enabled: false },
    series: [{
      name: "Temperature",
      data: seed_data
    }]
  });
}

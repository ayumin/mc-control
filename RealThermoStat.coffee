thermostat = require('./ThermoStat')

five = require("johnny-five")

LED_PIN = 13
TEMP_SENSOR_PIN = 'A0' 
TEMP_RATE = parseInt(process.env.TEMP_RATE || 1)

exports.RealThermoStat = class RealThermoStat extends thermostat.ThermoStat

  constructor: () ->
    super('raspi')
    @city = 'San Francisco'
    @country = 'USA'
    @lat  = @jitter_location(37.774929)
    @long = @jitter_location(-122.419416)

  init: () ->
    super
    @board = new five.Board()
    @init_board()
    @temp = 0

  jitter_location: (location) ->
    location += ((Math.random() * 0.1) - 0.05)
    parseFloat(location.toFixed(4))

  take_readings: () ->
    readings = super
    readings.city    = @city
    readings.country = @country
    readings.lat = @lat
    readings.long = @long
    readings

  init_board: () ->
    @board.on "ready", () =>
      @led = new five.Led(LED_PIN)
      @temp_sensor = new five.Sensor
        pin: TEMP_SENSOR_PIN
        freq: TEMP_RATE * 1000

  # start the timers
  start: () ->
    super()
    @start_sample()

  # stop the timers
  stop: () ->
    super()
    clearInterval(@real_sample)

  # vary the temperature
  start_sample: () ->
    # default: (2hrs/36readings)*(sec/hr)*(millis/sec)
    sample = () =>
      if @temp_sensor
        @temp = @temp_sensor.value * 0.004882814;
        @temp = (@temp - 0.5) * 100;
    @real_sample = setInterval(sample, TEMP_RATE * 1000)

(new exports.RealThermoStat).start()

###

socket.on('error', function(error){
  console.log(error);
});

board.on("ready", function() {

  var led = new five.Led(13)
  var temp_reading = null;

  this.firmata.analogRead(0, function(reading){
    temp_reading = reading;
  });


  var i = 0;

  setInterval(function(){
    var temp = temp_reading * 0.004882814;
    temp     = (temp - 0.5) * 100;
    console.log(temp_reading, temp);
    i = i + 1;
    socket.emit('readings',
      {temp: temp,
       battery: 100 - i,
       status: 'OK',
       device_id: n
      });
  }, 1000);


  socket.on('control-device', function(settings){
    console.log('control-device', settings);

    if(settings.light_on){
      console.log("LED ON");
      led.on();
    };

    if(settings.light_off || settings.init){
      console.log("LED OFF");
      led.off();
    }

    if(settings.init){
      i = 0;
    }
  });

});
###

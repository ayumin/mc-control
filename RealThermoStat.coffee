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
    @board = new five.Board()

  safe_keys: () ->
    keys = super
    keys.push 'city'
    keys.push 'country'
    keys.push 'lat'
    keys.push 'long'
    keys

  init: () ->
    super
    @temp = 0
    @last = {}

  jitter_location: (location) ->
    location += ((Math.random() * 0.1) - 0.05)
    parseFloat(location.toFixed(4))

  process_readings: (readings) ->
    if @led
      @led.on()  if readings.status == 'FAIL'
      @led.off() if @last.status == 'FAIL' and readings.status == 'OK'
    @last = readings

  take_readings: () ->
    readings = super
    readings.city    = @city
    readings.country = @country
    readings.lat = @lat
    readings.long = @long
    @process_readings(readings)
    readings

  init_board: () ->
    @board.on "ready", () =>
      @led = new five.Led(LED_PIN)
      @temp_sensor = new five.Sensor
        pin: TEMP_SENSOR_PIN
        freq: TEMP_RATE * 1000

    @socket.on 'control-device', (settings) =>
      @led.on()  if settings.led?.match(/on/i)
      @led.off() if settings.led?.match(/off/i)

  # start the timers
  start: () ->
    super()
    @init_board()
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
        @temp = ((@temp - 0.5) * 100).toFixed(2);
    @real_sample = setInterval(sample, TEMP_RATE * 1000)

(new exports.RealThermoStat).start()

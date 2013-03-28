spawn      = require("child_process").spawn
thermostat = require('./ThermoStat')

five = require("johnny-five")

RED_LED_PIN = 12
GRN_LED_PIN = 13
BLU_LED_PIN = 9

# Set GRN_LED_PIN to 9 to make it blue
# GRN_LED_PIN = 9

TEMP_SENSOR_PIN = 'A0'
TEMP_RATE = parseInt(process.env.TEMP_RATE || 3)

FAIL = /fail/i
OK   = /ok/i
RECALL = /recall/i

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

    # commented out because this prevents manual failures from being triggered
    # as it recovers from them as long as the temperature is < 200

    # if @temp > 200
    #   @status = 'FAIL'

    # if (FAIL.test(@last.status)) and (@temp < 200)
    #   @status = 'OK'

    if @red_led && @green_led
      if (!FAIL.test(@last.status)) and FAIL.test(readings.status)
        console.log('failmode')
        @red_led.stop().on()
        @green_led.stop().off()
      if (!RECALL.test(@last.status)) and RECALL.test(readings.status)
        console.log('recallmode')
        @red_led.strobe(500)
        @green_led.strobe(500)
      if (!OK.test(@last.status)) and OK.test(readings.status)
        console.log('allok')
        @red_led.stop().off()
        @green_led.stop().on()
    @last = readings

  take_readings: () ->
    readings = super
    readings.city    = @city
    readings.country = @country
    readings.lat = @lat
    readings.long = @long
    @process_readings(readings)
    readings

  update: ->
    @green_led.off()
    @red_led.on()
    @blue_led.on()
    git_pull = spawn('git', ['pull'])
    git_pull.stdout.on 'data', (data) -> console.log(data.toString())
    git_pull.stderr.on 'data', (data) -> console.log(data.toString())
    git_pull.on 'close', (code) =>
      console.log "git exit with #{code}"
      process.exit()

  init_board: () ->
    @board.on "ready", () =>
      @red_led = new five.Led(RED_LED_PIN)
      @red_led.off()
      @blue_led = new five.Led(BLU_LED_PIN)
      @blue_led.off()
      @green_led = new five.Led(GRN_LED_PIN)
      @green_led.on()
      @temp_sensor = new five.Sensor
        pin: TEMP_SENSOR_PIN
        freq: TEMP_RATE * 1000

    @socket.on 'control-device', (settings) =>
      @green_led.on()  if settings.green_led?.match(/on/i)
      @green_led.off() if settings.green_led?.match(/off/i)
      @red_led.on()  if settings.red_led?.match(/on/i)
      @red_led.off() if settings.red_led?.match(/off/i)

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
        @temp = parseFloat(((@temp - 0.5) * 100).toFixed(2))
    @real_sample = setInterval(sample, TEMP_RATE * 1000)

(new exports.RealThermoStat).start()

io         = require 'socket.io-client'
spawn      = require('child_process').spawn

api_url    = process.env.API_URL
exports.battery_drain_rate = process.env.BATTERY_DRAIN || 5
exports.readings_rate      = process.env.READINGS_INTERVAL || 3

exports.ThermoStat = class ThermoStat
  constructor: (@id) ->

  init: () ->
    @battery = 100
    @status = 'OK'
    @temp = 0

  safe_keys: () -> ['battery', 'status', 'temp']

  # start the timers
  start: () ->
    @connect()
    @init()
    @start_battery_drain()
    @start_reporter()

  # stop the timers
  stop: () ->
    clearInterval(@drain)
    clearInterval(@reporter)
    @socket.disconnect()

  connection_settings: () ->
    settings =
      'connect timeout': 10 * 1000,
      'try multiple transports': false
      'reconnection delay': Math.floor(Math.random() * 2000)
      'backoff': 1
      'max reconnection attempts': 500
    if process.env.FORCE_NEW_CONNECTION
      settings['force new connection'] = true
    settings

  hookup_errors: ->
    process.on "uncaughtException", (err) =>
      console.log('uncaught_error=true', err)
      @socket.disconnect()
      @socket.socket.connect()

    @socket.on 'error', (err) =>
      console.log('error=true', err)
      @socket.disconnect()
      @socket.socket.connect()

    @socket.on 'connect_failed', (err) =>
      console.log('connect_failed=true error=true', err)
      @socket.disconnect()
      @socket.socket.connect()

  update: ->
    git_pull = spawn('git', ['pull'])
    git_pull.stdout.on 'data', (data) -> console.log(data.toString())
    git_pull.stderr.on 'data', (data) -> console.log(data.toString())
    git_pull.on 'close', (code) ->
      console.log "git exit with #{code}"
      process.exit()

  connect:  ->
    @socket = io.connect api_url, @connection_settings()
    @socket.on 'connect', () =>
      @socket.emit 'register-device', @id, @take_readings()

    @socket.on 'control-device', (settings) =>
      console.log('control-message: ', settings)
      if(settings.init)
        @init()
      else if (settings.update)
        @update()
      else
        for key in @safe_keys()
          if value = settings[key]
            value = parseFloat(value)   if /temp|battery/i.test(key)
            value = value.toUpperCase() if /status/i.test(key)
            this[key] = value

    @hookup_errors()

  fail: () -> @status = 'FAIL'
  ok:   () -> @status =  'OK'

  # drain the battery
  start_battery_drain: (rate = exports.battery_drain_rate) ->
    rate  = parseFloat(rate) * 1000
    drain = () => @battery -= 1
    @drain = setInterval(drain, rate + Math.random()*rate)

  take_readings: () ->
    battery:   @battery
    temp:      @temp
    status:    @status

  # report state to device API
  start_reporter: (rate = exports.readings_rate) ->
    rate = parseFloat(rate) * 1000
    reporter = () =>
      readings = @take_readings()
      readings.device_id = @id
      @socket.emit 'readings', readings
      @log() unless process.env.SILENT_DEVICE is 'true'

    @reporter = setInterval(reporter, rate)

  # log state to STDOUT
  log: () ->
    logdata = ("#{k}=#{v}" for k, v of @take_readings())
    logline = "device=#{@id} #{logdata.join(' ')}"
    console.log(logline)

exports.RandomThermoStat = class RandomThermoStat extends ThermoStat
  init: () ->
    super
    @temp = Math.round((Math.random()*10) + 15)

  # start the timers
  start: () ->
    super
    @start_random_temp_walk()

  # stop the timers
  stop: () ->
    super
    clearInterval(@walk)

  # vary the temperature
  start_random_temp_walk: () ->
    rate = 1000 + Math.random() * 1000
    walk = () =>
      if Math.random() > 0.5
        sign = 1
      else
        sign = -1
      vector = sign * Math.round(1 + Math.random() * 1)
      @temp   = parseInt(@temp) + vector
    @walk = setInterval(walk, rate)


exports.CityThermoStat = class CityThermoStat extends ThermoStat

  constructor: (@id, @weather_report) ->
    super(@id)
    location = @weather_report.location
    @city = location.city
    @country = location.country
    @lat  = @jitter_location(location.lat)
    @long = @jitter_location(location.long)
    @readings = @weather_report.readings

  init: () ->
    super
    @temp = @readings[0]
    @i = 0

  jitter_location: (location) ->
    location += ((Math.random() * 0.1) - 0.05)
    parseFloat(location.toFixed(4))

  next_temp: () ->
    @i = (@i + 1) % @readings.length
    @readings[@i]

  take_readings: () ->
    readings = super
    readings.city    = @city
    readings.country = @country
    readings.lat = @lat
    readings.long = @long
    readings

  # start the timers
  start: () ->
    super()
    @start_temp_walk()

  # stop the timers
  stop: () ->
    super()
    clearInterval(@walk)

  # vary the temperature
  start_temp_walk: () ->
    # default: (2hrs/36readings)*(sec/hr)*(millis/sec)
    rate = parseInt(process.env.TEMP_RATE || 2 / 36 * 3600) * 1000
    walk = () => @temp = @next_temp()
    @walk = setInterval(walk, rate)

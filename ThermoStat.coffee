io         = require 'socket.io-client'

api_url    = process.env.API_URL
exports.battery_drain_rate = process.env.BATTERY_DRAIN || 5
exports.readings_rate      = process.env.READINGS_INTERVAL || 3

exports.ThermoStat = class ThermoStat
  constructor: (@id) ->

  init: () ->
    @battery = 100
    @status = 'OK'

  # start the timers
  start: () ->
    @init()
    @connect()
    @start_battery_drain()
    @start_reporter()

  # stop the timers
  stop: () ->
    clearInterval(@drain)
    clearInterval(@walk)
    clearInterval(@reporter)

  connect: () ->
    @socket = io.connect(api_url, 'force new connection': true)
    @socket.on 'connect', () =>
      @socket.emit('register-device', @id)

    @socket.on 'control-device', (settings) =>
      console.log('control-message: ', settings)
      if(settings.init)
        @init()
      else
        for key, value of settings
          this[key] = value

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
      @log()

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

  constructor: (@id, @city_name, @readings) ->
    super(@id)
    @location = @city_location(@city_name)
    @location[0] += @location_jitter()
    @location[1] += @location_jitter()

  init: () ->
    super
    @temp = @readings[0]
    @i = 0

  city_location: (name) ->
    switch name
      when "ciba" then [35.605057,140.123306]
      when "gifu" then [35.423298,136.760654]
      when "kyoto" then [35.011636,135.768029]
      when "osaka" then [34.693738,135.502165]
      when "shizuoka" then [34.975562,138.382760]
      when "tokyo" then [35.689487,139.691706]

  location_jitter: () ->
    ((Math.random() * 0.1) - 0.05).toFixed(4)

  next_temp: () ->
    @i = (@i + 1) % @readings.length
    @readings[@i]

  take_readings: () ->
    readings = super
    readings.city_name = @city_name
    readings.lat = @location[0]
    readings.long = @location[1]
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

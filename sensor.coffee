superagent = require 'superagent'
io         = require 'socket.io-client'

api_url    = process.env.API_URL

exports.battery_drain_rate = process.env.BATTERY_DRAIN || 0.5
exports.readings_rate      = process.env.READINGS_INTERVAL || 3

exports.TempSensor = class TempSensor
  status_ok: 0
  status_fail: 1

  constructor: (@id) ->

  init: () ->
    @battery_level = 100
    @temp = Math.round((Math.random()*10) + 15)
    @status = 'OK'

  # start the timers
  start: () ->
    @init()
    @connect()
    @start_battery_drain()
    @start_reporter()
    @start_random_temp_walk()

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

  # drain the battery
  start_battery_drain: (rate = exports.battery_drain_rate) ->
    rate  = parseInt(rate) * 1000
    drain = () => @battery_level -= 1
    @drain = setInterval(drain, rate + Math.random()*rate)

  # report state to device API
  start_reporter: (rate = exports.readings_rate) ->
    rate = parseInt(rate) * 1000
    reporter = () =>
      readings =
        device_id: @id
        battery:   @battery_level
        temp:      @temp
        status:    @status
      @log()
      @socket.emit 'readings', readings

    @reporter = setInterval(reporter, rate)

  # log state to STDOUT
  log: () ->
    logline = "device=#{@id} "
    logline += "battery=#{@battery_level} "
    logline += "temp=#{@temp} "
    logline += "status=#{@status} "
    console.log(logline)

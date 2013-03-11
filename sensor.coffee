superagent = require 'superagent'
io         = require 'socket.io-client'

api_url    = process.env.API_URL

battery_drain_rate = process.env.BATTERY_DRAIN || 500

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
    @start_logger()
    @start_reporter()
    @start_random_temp_walk()

  # stop the timers
  stop: () ->
    clearInterval(@drain)
    clearInterval(@logger)
    clearInterval(@reporter)
    clearInterval(@walk)

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
  start_random_temp_walk: (rate = 1000) ->
    walk = () =>
      if Math.random() > 0.5
        sign = 1
      else
        sign = -1
      vector = sign * Math.round(1 + Math.random() * 1)
      @temp   = parseInt(@temp) + vector
    @walk = setInterval(walk, rate + Math.random()*rate)

  # drain the battery
  start_battery_drain: (rate = battery_drain_rate) ->
    drain = () => @battery_level -= 1
    @drain = setInterval(drain, rate + Math.random()*rate)

  # report state to device API
  start_reporter: (rate = 1000) ->
    reporter = () =>
      @socket.emit 'readings',
        device_id: @id
        battery:   @battery_level
        temp:      @temp
        status:    @status

    @reporter = setInterval(reporter, rate)

  # log state to STDOUT
  start_logger: (rate = 1000) ->
    logger = () =>
      logline = "device=#{@id} "
      logline += "battery=#{@battery_level} "
      logline += "temp=#{@temp} "
      logline += "status=#{@status} "
      console.log(logline)
    @logger = setInterval(logger, rate)

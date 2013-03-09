superagent   = require 'superagent'
api_url      = process.env.API_URL
report_url   = api_url + '/sensor/report'
config       = require('./configure')
redis        = config.createRedisClient()

battery_drain_rate = process.env.BATTERY_DRAIN || 500

exports.TempSensor = class TempSensor
  status_ok: 0
  status_fail: 1

  constructor: (@id) ->

  init: () ->
    @set_reading 'battery_level', 100
    @set_reading 'temp', Math.round((Math.random()*10) + 15)
    @ok()

  # start the timers
  start: () ->
    @init()
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

  # set one reading in redis
  set_reading: (name, value) ->
    redis.hset("readings:#{@id}", name, value, redis.print)

  # get the readings from redis and pass them to a callback
  get_readings: (callback) ->
    redis.hgetall "readings:#{@id}", (err, readings) ->
      callback(readings)

  fail: () -> @set_reading 'status', 'FAIL'
  ok:   () -> @set_reading 'status', 'OK'

  # vary the temperature
  start_random_temp_walk: (rate = 1000) ->
    walk = () =>
      @get_readings (readings) =>
        if Math.random() > 0.5
          sign = 1
        else
          sign = -1
        vector = sign * Math.round(1 + Math.random() * 1)
        temp   = parseInt(readings.temp) + vector
        @set_reading 'temp', temp
    @walk = setInterval(walk, rate + Math.random()*rate)

  # drain the battery
  start_battery_drain: (rate = battery_drain_rate) ->
    drain = () =>
      @get_readings (readings) =>
        if readings.battery_level > 0
          @set_reading 'battery_level', readings.battery_level -= 1
        else
          @init()
    @drain = setInterval(drain, rate + Math.random()*rate)

  # report state to device API
  start_reporter: (rate = 1000) ->
    reporter = () =>
      @get_readings (readings) =>
        superagent.agent().post("#{report_url}/#{@id}")
          .on('error', (e) =>
            console.log("error=#{e.code} id=#{@id}"))
          .send({
            battery: readings.battery_level
            temp:    readings.temp
            status:  readings.status
          }).end()

    @reporter = setInterval(reporter, rate)

  # log state to STDOUT
  start_logger: (rate = 1000) ->
    logger = () =>
      @get_readings (readings) =>
        logline = "device=#{@id} "
        logline += "battery=#{readings.battery_level} "
        logline += "temp=#{readings.temp} "
        logline += "status=#{readings.status} "
        console.log(logline)
    @logger = setInterval(logger, rate)

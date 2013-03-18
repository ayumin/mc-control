moment = require 'moment'
async  = require 'async'


TempoDBClient = require("tempodb").TempoDBClient
tempodb = new TempoDBClient(process.env.TEMPODB_API_KEY, process.env.TEMPODB_API_SECRET)

exports.history = (req, res) ->

  device_id   = req.param('id')
  temp_key    = "device:ThermoStat.temp.id:#{device_id}.series"
  battery_key = "device:ThermoStat.battery.id:#{device_id}.series"
  start       = moment().subtract('minutes', 20).toDate()
  end         = moment().toDate()

  history =
    battery: []
    temp: []

  battery_data =  (cb) ->
    values  = []
    options = key: battery_key
    tempodb.read start, end, options, (result) ->
      console.log("tempdo-db-status=#{result.response}")
      try
        for event in result.body[0].data
          history.battery.push(parseFloat(event.v))
      catch err
        console.log(err, result.response, result.body)
      cb()

  temp_data =  (cb) ->
    values = []
    options = key: temp_key
    tempodb.read start, end, options, (result) ->
      console.log("tempdo-db-status=#{result.response}")
      try
        for event in result.body[0].data
          history.temp.push(event)
      catch err
        console.log(err, result.response, result.body)
      cb()

  async.parallel
    battery: battery_data
    temp: temp_data
    , () -> res.json(history)

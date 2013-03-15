moment = require 'moment'
async  = require 'async'


TempoDBClient = require("tempodb").TempoDBClient
tempodb = new TempoDBClient(process.env.TEMPODB_API_KEY, process.env.TEMPODB_API_SECRET)

exports.history = (req, res) ->

  device_id   = req.param('id')
  battery_key = "battery:#{device_id}"
  temp_key    = "temp:#{device_id}"
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
      cb()

  temp_data =  (cb) ->
    values = []
    options = key: temp_key
    tempodb.read start, end, options, (result) ->
      console.log("tempdo-db-status=#{result.response}")
      try
        for event in result.body[0].data
          history.temp.push(parseFloat(event.v))
      cb()

  async.parallel
    battery: battery_data
    temp: temp_data
    , () ->
      res.json(history)

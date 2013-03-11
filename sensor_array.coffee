sensor  = require './sensor'

argv = process.argv.slice(2)
n    = parseInt(argv[0])

#to hold timers
sensors = []

kick = (id) ->
  func = () ->
    s = new sensor.TempSensor(id)
    sensors[id] = s
    s.start()
  setTimeout(func, Math.random()*1000)

kick(num) for num in [1..n]

sensor  = require './sensor'

argv = process.argv.slice(2)
n    = parseInt(argv[0])
mode = argv[1]

if mode == 'uuid'
  uuid = require 'node-uuid'
  next = (i) -> uuid.v4()
else
  next = (i) -> i

#to hold timers
sensors = []

kick = (i) ->
  func = () ->
    id = next(i)
    s = new sensor.TempSensor(id)
    sensors[id] = s
    s.start()
  setTimeout(func, Math.random()*1000)

kick(num) for num in [1..n]

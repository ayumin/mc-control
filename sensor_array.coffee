sensor  = require './sensor'

argv = process.argv.slice(2)
n    = parseInt(argv[0])

#to hold timers
sensors = []

for num in [0..n]
  s = new sensor.TempSensor(num)
  sensors[num] = s
  s.start()

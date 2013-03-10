sensor  = require './sensor'

argv = process.argv.slice(2)
n    = parseInt(argv[0])

#to hold timers
sensors = []

for num in [1..n]
  s = new sensor.TempSensor(num)
  sensors[num] = s
  kicker = () -> s.start()
  setTimeout(kicker, 1000*Math.random())

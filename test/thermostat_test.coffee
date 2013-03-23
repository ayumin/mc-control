thermostat = require "#{__dirname}/../Thermostat"
assert     = require 'assert'
request    = require 'superagent'

# Test Device Constructor sets id
device = new thermostat.ThermoStat('test')
assert.ok(device.id == 'test')

# Init sets values
assert.ok(device.battery == undefined)
assert.ok(device.status  == undefined)
assert.ok(device.temp    == undefined)
device.init()
assert.ok(device.battery == 100)
assert.ok(device.status  == 'OK')
assert.ok(device.temp    == 0)

device.start()
verify_mothership_talks_back_to_device = () ->
  request
    .get('http://localhost:5000/sensor/test/set/status/FAIL')
    .end ->
      verify_status = ->
        assert.ok(device.status == 'FAIL')
        device.stop()
      setTimeout verify_status, 500

setTimeout verify_mothership_talks_back_to_device, 500

### start_battery_drain() drains the battery
device.start_battery_drain(0.001)
last_battery_reading = null
verify_drain = ->
  assert.ok(device.battery < 100)
  device.stop()
  last_battery_reading = device.battery
  #setTimeout(verify_drain, 100)
###

# Battery reading doesn't continue to decrease
# after stopping
#
#verify_stop = ->
#  assert.ok(device.battery == last_battery_reading)
#setTimeout(verify_stop, 200)

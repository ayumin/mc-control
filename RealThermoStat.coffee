
thermostat = require('./ThermoStat')

exports.RealThermoStat = class RealThermoStat extends thermostat.RandomThermoStat
  
  constructor: () ->
    super('raspi')



(new exports.RealThermoStat).start()

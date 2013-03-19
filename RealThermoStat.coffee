
thermostat = require('./ThermoStat')

exports.RealThermoStat = class RealThermoStat extends thermostat.RandomThermoStat
  
  constructor: () ->
    super('raspi')



(new exports.RealThermoStat).start()

###
var five = require("johnny-five"),
    board = new five.Board();

socket.on('error', function(error){
  console.log(error);
});

board.on("ready", function() {

  var led = new five.Led(13)
  var temp_reading = null;
 
  this.firmata.analogRead(0, function(reading){
    temp_reading = reading;
  });


  var i = 0;

  setInterval(function(){ 
    var temp = temp_reading * 0.004882814;
    temp     = (temp - 0.5) * 100;
    console.log(temp_reading, temp);
    i = i + 1;
    socket.emit('readings', 
      {temp: temp,
       battery: 100 - i,
       status: 'OK',
       device_id: n
      });
  }, 1000);


  socket.on('control-device', function(settings){
    console.log('control-device', settings); 

    if(settings.light_on){
      console.log("LED ON");
      led.on();
    };

    if(settings.light_off || settings.init){
      console.log("LED OFF");
      led.off();
    } 

    if(settings.init){
      i = 0;
    }
  });

});
###

# Machine Cloud Control Panel

It's like there's a network of machines in the sky.

This app is a demo of bi-directional low-latency communication using
websockets.  It is a simulation of thousands of network-enabled
ThermoStats.  Each ThermoStat has an internal state that it communicates
to the "mothership."  The "mothership" can return control messages to
the device.


## Messages

`listen-device` - register interest in a device's `control-device` and `readings` channels.
`listen-mothership` - register interest in the mother's status (number of connected devices)
`register-device` - register a new device
`control-device` - control a device
`readings` - device's readings

## ENV Vars

    API_URL - url sensors connect to
    BATTERY_DRAIN - rate of battery drain in one percent per seconds
    TEMP_RATE - number of seconds between using next temp reading
    SENSORS - number of device connections opened by the `int_sensor` and `uuid_sensor` processes
    NODE_ENV

    #Redis Add-ON
    REDISTOGO_URL

    #For History API - heroku addons:add tempodb
    TEMPODB_API_HOST
    TEMPODB_API_KEY
    TEMPODB_API_PORT
    TEMPODB_API_SECRET
    TEMPODB_API_SECURE





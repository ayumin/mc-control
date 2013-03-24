# Machine Cloud Control Panel

It's like there's a network of machines in the sky.

This app is a demo of machine to machine bi-directional low-latency communication using
websockets.  It is a simulation of thousands of network-enabled
ThermoStats.  Each ThermoStat has an internal state that it communicates
to the "mothership."  The "mothership" can return control messages to
the device.


## WebSocket Messages

`listen-device` - register interest in a device's `control-device` and `readings` channels.
`listen-mothership` - register interest in the mother's status (number of connected devices)
`register-device` - register a new device
`control-device` - control a device
`readings` - device's readings

## ENV Vars

    API_URL - url sensors connect to
    BATTERY_DRAIN - rate of battery drain in one percent per X seconds
    DASHBOARD_READINGS_INTERVAL - rate at which to sent analytics to the dashboad
    HTTP_PASSWORD - http basic password
    NODE_ENV - development or production environment
    READINGS_INTERVAL - rate, in seconds, for sending readings to the server
    SENSORS - number of device connections opened by the `int_sensor` and `uuid_sensor` processes
    SILENT_DEVICE - set to 'true' to stop devices from logging every reading (they are
      already logged by the server)
    SINGLE_DYNO_MODE - don't use redis pub/sub for socket.io (can't scale past 1 web process)
    TEMP_RATE - number of seconds between using next temp reading from a city
    TRANSPORTS - comma separated list of transport protocols for socket.io

    #Redis Add-ON
    heroku addons:add redisgreen

    set REDIS_NAME to env var with redis url if not using REDISGREEN_URL for redis url

    #For History API - credentials come from l2tempo
    # you can use bin/update_config to push the proper creds after
    # dropping and re-adding the tempodb add-on from l2tempo

    TEMPODB_API_HOST
    TEMPODB_API_KEY
    TEMPODB_API_PORT
    TEMPODB_API_SECRET
    TEMPODB_API_SECURE

## Commands

    device_array <n> "uuid" [optional] - start a cluster of virtual devices
    fail_device  <device_id> - fail a specific device
    fix_device <device_id> - fix a specific device
    fail_n <n> - fail N devices
    reset - reset the redis database
    real_device - scrit to run on the Raspberry PI to start the "real" device
    set_temp <device_id> <temp> - set the temp of a specific device
    update_config - update the app with the TEMPODB creds from l2tempo
    web - run the web server on PORT






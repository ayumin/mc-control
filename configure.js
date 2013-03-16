var express = require('express');
var redis   = require('redis');

exports.configure = function(app, io) {
  app.configure(function(){
    app.set('views', __dirname + '/views');
    app.set('view engine', 'jade');
    app.use(express.bodyParser());
    app.use(express.methodOverride());
    app.use(express.logger());
    app.use(app.router);
    app.use(express.static(__dirname + '/public'));
  });

  app.configure('development', function(){
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));
    process.env.PORT = process.env.PORT || 3333;
  });

  app.configure('production', function(){
    app.use(express.errorHandler());
  });

  var RedisStore = require('socket.io/lib/stores/redis');

  io.configure('production', function () {
    if(process.env.FORCE_XHR_POLLING){
      io.set("transports", ["xhr-polling"]);
      io.set("polling duration", 10);
    }

    io.set('store', new RedisStore({
      redis    : redis
    , redisPub : exports.createRedisClient()
    , redisSub : exports.createRedisClient()
    , redisClient : exports.createRedisClient()
    }));

    io.enable('browser client minification');  // send minified client
    io.enable('browser client etag');          // apply etag caching logic based on version number
    io.enable('browser client gzip');          // gzip the file
    console.log("set log level")
    io.set('log level', 1);                    // reduce logging
  });

  io.configure('development', function(){
    io.set('store', new RedisStore({
      redisPub : exports.createRedisClient()
    , redisSub : exports.createRedisClient()
    , redisClient : exports.createRedisClient()
    }));
  })
}

exports.createRedisClient = function(){
  var redis_client = null;

  //Setup Redis
  if (process.env.REDISTOGO_URL) {
    var rtg   = require("url").parse(process.env.REDISTOGO_URL);
    redis_client = redis.createClient(rtg.port, rtg.hostname);
    var redis_password = rtg.auth.split(":")[1]
  } else {
    redis_client = redis.createClient();
  }

  redis_client.on("error", function (err) {
    console.log("Redis Error " + err);
  });

  if(redis_password){
    console.log("method=auth-redis");
    redis_client.auth(redis_password);
  }
  return redis_client
}


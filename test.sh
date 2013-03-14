#! /usr/bin/env sh

curl http://localhost:5000/sensor/$1/set/temp/100
curl http://localhost:5000/sensor/$1/history/hour

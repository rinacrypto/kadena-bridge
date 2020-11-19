#!/bin/sh

NODE=$1
echo Sending to $NODE
curl -sk -X POST $NODE/api/v1/send --header "Content-Type:application/json;charset=utf-8" -d @-

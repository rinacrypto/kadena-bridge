#!/bin/sh

NODE=$1
curl -X POST -d @- $NODE/api/v1/poll --header "Content-Type:application/json;charset=utf-8"

#!/bin/sh

envsubst < /lua/script.template.lua > /lua/script.lua 

echo "exec $@"

exec "$@"

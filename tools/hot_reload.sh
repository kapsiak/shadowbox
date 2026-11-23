#!/bin/sh
# Hot-reloads files edited outside the Defold editor into the running game (run from the project
# root). The editor only notices outside edits when it rescans the disk, which it does after
# running a shell command, so this runs a no-op through the editor first. Don't compile in
# between: a compile takes the change, and the hot reload then finds nothing new to send.
port=$(cat .internal/editor.port)
token=$(cat .internal/editor.token)
curl -s -X POST -H "Authorization: Bearer $token" --data 'editor.execute("true")' "localhost:$port/eval" > /dev/null
curl -s -X POST -H "Authorization: Bearer $token" "localhost:$port/command/hot-reload"
echo

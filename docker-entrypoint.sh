#!/bin/bash

# FILE=/north-america-latest.osm.pbf
FILE=uruguay-latest.osm.pbf
if [ -f "/data/$FILE" ]; then
  echo "$FILE exists."
else 
  echo "Coping $FILE."
  # wget https://fp-graphhopper.s3.amazonaws.com/north-america-latest.osm.pbf
  wget https://fp-graphhopper.s3.amazonaws.com/uruguay-latest.osm.pbf -P /data
fi

exec ./graphhopper.sh -c config-example.yml -i /data/$FILE --host 0.0.0.0
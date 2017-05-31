#!/bin/sh
function vol-id-by-name() {
   # VOLNAME=$1
   cinder show $1 | grep ' id ' | awk '{print $4}';
}

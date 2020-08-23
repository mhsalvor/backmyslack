#!/bin/bash

function line {
  local count=2
  local buff=2
  local col=$(tput cols)
  printf "+"
    while [  $count -lt $col ]; do
      printf "="
      let count++
    done
  printf "+\n"
}

function write() {
   local text=$1
   local buff=${#text}
   local col=$(tput cols)
   local jump1=$((($buff+$col-1)/2))
   local jump2=$((($col-$buff)/2))
printf "|%*s" $jump1 "$text"
printf "%*s\n" $jump2 "|"
}

VAR="pluto pioop"
line
write "amanda $VAR"
line
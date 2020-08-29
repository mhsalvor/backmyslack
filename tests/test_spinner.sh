#!/bin/bash

spinner()
{
     tput civis;
     local pid=$1
     local delay=0.05
     while [[ $(ps -eo pid | grep  ${pid}) ]]; do
    for i in \| / - \\; do
            printf ' [%c]\b\b\b\b' $i
            sleep $delay
          done
     done
     printf '\b\b\b\b'
     tput cnorm;
}

sleep 100 & spinner $!
#cp -a ../testbk_dir/VIDEO ../testbk_dir/to_exclude & spinner $!

#!/bin/bash

NOTE_NUMBER=13

while [ ${NOTE_NUMBER} -lt 112 ]; do
    sendmidi ch 1 dev "IAC 1" on ${NOTE_NUMBER} 127
    sleep 0.5
    sendmidi ch 1 dev "IAC 1" off ${NOTE_NUMBER} 0
    NOTE_NUMBER=$(expr ${NOTE_NUMBER} + 1)
    sleep 0.5
done


#!/bin/bash

grep '^"'$1'" =>' ~/public_html/wma/rev.inc | cut -d'>' -f2 | cut -d, -f1

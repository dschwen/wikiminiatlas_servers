#!/usr/bin/env python3

import geolink

print(geolink.parse(b"pagename=Mount_Logan&params=60_35_03.5_N_140_27_20.5_W_type:mountain_region:CA&title=Houston's+Peak".decode('utf-8'), "Tangle Woold Island (Alabama)", 1))

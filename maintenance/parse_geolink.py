#!/usr/bin/env python3

import re
from urllib import parse

link = 'pagename=List_of_islands_of_Michigan&params=45.29833_N_83.48972_W_region:US-MI_type:isle&title=Tanglewood+Island'

qs = parse.parse_qs(link)

if not 'params' in qs:
    raise "heck!"

# parse params
params = qs['params'][0].split('_')

print(params)


if params[1] == 'N':
    lat = float(params[0])
    offset = 2

elif params[1] == 'S':
    lat = -float(params[0])
    offset = 2

elif params[2] == 'N':
    lat = float(params[0]) + float(params[1]) / 60.0
    offset = 3

elif params[2] == 'S':
    lat = -float(params[0]) - float(params[1]) / 60.0
    offset = 3

elif params[3] == 'N':
    lat = float(params[0]) + float(params[1]) / 60.0
    offset = 4

elif params[3] == 'S':
    lat = -float(params[0]) - float(params[1]) / 60.0
    offset = 4

else:
    print("NS parse error")


if params[offset + 1] == 'E':
    lon = float(params[offset + 0])
    offset += 2

elif params[offset + 1] == 'W':
    lon = -float(params[offset + 0])
    offset += 2

elif params[offset + 2] == 'E':
    lon = float(params[offset + 0]) + float(params[offset + 1]) / 60.0
    offset += 3

elif params[offset + 2] == 'W':
    lon = -float(params[offset + 0]) - float(params[offset + 1]) / 60.0
    offset += 3

elif params[offset + 3] == 'E':
    lon = float(params[offset + 0]) + float(params[offset + 1]) / 60.0
    offset += 4

elif params[offset + 3] == 'W':
    lon = -float(params[offset + 0]) - float(params[offset + 1]) / 60.0
    offset += 4

else:
    print("EW parse error")


print(lat, lon)
aux = {i[0]: i[1] for i in [p.split(':') for p in params[offset:]]}

# population number
if 'pop' in aux:
    pop = int(aux['pop'])
else:
    pop = 0

# determine style index
if 'type' in aux:
    type = aux['type']

    if type == 'mountain':
        style = 2

    elif type == 'country':
        style = 3

    elif type == 'city':
        if pop < 1000000:
            style = 8
        if pop < 500000:
            style = 7
        if pop < 100000:
            style = 6
        if pop < 10000:
            style = 5
        if pop >= 1000000:
            style = 9

    elif type == 'event':
         style = 10

    else:
         style = 0

us_states = "Alabama|Alaska|Arizona|Arkansas|California|Colorado|Connecticut|Delaware|Florida|Georgia|Hawaii|Idaho|Illinois|Indiana|Iowa|Kansas|Kentucky|Louisiana|Maine|Maryland|Massachusetts|Michigan|Minnesota|Mississippi|Missouri|Montana|Nebraska|Nevada|New Hampshire|New Jersey|New Mexico|New York|North Carolina|North Dakota|Ohio|Oklahoma|Oregon|Pennsylvania|Rhode Island|South Carolina|South Dakota|Tennessee|Texas|Utah|Vermont|Virginia|Washington|West Virginia|Wisconsin|Wyoming"
au_territories = "New South Wales|Victoria|South Australia|Queensland|Western Australia|Northern Territory|Tasmania|Australian Capital Territory"
cdn_terrprov = "Ontario|Quebec|Nova Scotia|New Brunswick|Manitoba|British Columbia|Prince Edward Island|Saskatchewan|Alberta|Newfoundland and Labrador|Northwest Territories|Yukon|Nunavut"

us1_re = re.compile('^(.*) Township, .* County, (' + us_states + ')$')
us2_re = re.compile('^(.*) Township, (' + us_states + ')$')
us3_re = re.compile('^(.*) \((' + us_states + ')\)$')
us4_re = re.compile('^(.*) \(.*County, (' + us_states + ')\)$')

all_prov_re = re.compile("^(.*), (" + us_states + '|' + au_territories + '|' + cdn_terrprov + ')$')

# take care of a few special cases
def shortenName(name):
    match = us1.match(name)
    if match:
        return match.group(1) + "Twp."

    match = us2.match(name)
    if match:
        return match.group(1) + "Twp."

    match = us3.match(name)
    if match:
        return match.group(1)

    match = us4.match(name)
    if match:
        return match.group(1)

    match = all_prov_re.match(name)
    if match:
        return match.group(1)

    return name

name = shortenName(name)

# calculate final weight
weight = (weight + pop/20 - len(name)**2) * primary

print(style, aux)

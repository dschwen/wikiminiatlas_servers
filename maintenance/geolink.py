# geolink parsing module

import re
import os
import math
from urllib import parse as urllib_parse

us_states = "Alabama|Alaska|Arizona|Arkansas|California|Colorado|Connecticut|Delaware|Florida|Georgia|Hawaii|Idaho|Illinois|Indiana|Iowa|Kansas|Kentucky|Louisiana|Maine|Maryland|Massachusetts|Michigan|Minnesota|Mississippi|Missouri|Montana|Nebraska|Nevada|New Hampshire|New Jersey|New Mexico|New York|North Carolina|North Dakota|Ohio|Oklahoma|Oregon|Pennsylvania|Rhode Island|South Carolina|South Dakota|Tennessee|Texas|Utah|Vermont|Virginia|Washington|West Virginia|Wisconsin|Wyoming"
au_territories = "New South Wales|Victoria|South Australia|Queensland|Western Australia|Northern Territory|Tasmania|Australian Capital Territory"
cdn_terrprov = "Ontario|Quebec|Nova Scotia|New Brunswick|Manitoba|British Columbia|Prince Edward Island|Saskatchewan|Alberta|Newfoundland and Labrador|Northwest Territories|Yukon|Nunavut"

us1_re = re.compile('^(.*) Township, .* County, (' + us_states + ')$')
us2_re = re.compile('^(.*) Township, (' + us_states + ')$')
us3_re = re.compile('^(.*) \((' + us_states + ')\)$')
us4_re = re.compile('^(.*) \(.*County, (' + us_states + ')\)$')

all_prov_re = re.compile("^(.*), (" + us_states + '|' + au_territories + '|' + cdn_terrprov + ')$')

#
# take care of a few special cases to enable shorter names
#
def shortenName(name):
    match = us1_re.match(name)
    if match:
        return match.group(1) + "Twp."

    match = us2_re.match(name)
    if match:
        return match.group(1) + "Twp."

    match = us3_re.match(name)
    if match:
        return match.group(1)

    match = us4_re.match(name)
    if match:
        return match.group(1)

    match = all_prov_re.match(name)
    if match:
        return match.group(1)

    return name

list_n = ['n', 'N']
list_e = ['e', 'E', 'o', 'O']
list_s = ['s', 'S']
list_w = ['w', 'W']

# load globes list
with open(os.path.join(os.path.dirname(__file__), 'globes.dat')) as globes_file:
    list_globe = [i.rstrip('\n').lower() for i in globes_file.readlines()]

city_re = re.compile('^city\((.*)\)$')
semicolon_re = re.compile('^([+-]?([0-9]+([.][0-9]*)?|[.][0-9]+));([+-]?([0-9]+([.][0-9]*)?|[.][0-9]+))$')

#
# parse link and default page name
#
def parse(link, name, weight):
    qs = urllib_parse.parse_qs(link.replace(';','%3B'))
    if not 'params' in qs:
        raise ValueError("No 'params' parameter found", qs)

    # parse params
    params = qs['params'][0].split('_')

    # starting with coords...
    match = semicolon_re.match(params[0])
    if match:
        # matches the uncommon lat;lon syntax
        lat = float(match.group(1))
        lon = float(match.group(4))
    else:
        if params[1] in list_n:
            lat = float(params[0].replace(',','.'))
            offset = 2

        elif params[1] in list_s:
            lat = -float(params[0].replace(',','.'))
            offset = 2

        elif params[2] in list_n:
            lat = float(params[0].replace(',','.')) + float(params[1].replace(',','.') or '0') / 60.0
            offset = 3

        elif params[2] in list_s:
            lat = -float(params[0].replace(',','.')) - float(params[1].replace(',','.') or '0') / 60.0
            offset = 3

        elif params[3] in list_n:
            lat = float(params[0].replace(',','.')) + float(params[1].replace(',','.') or '0') / 60.0 + float(params[2].replace(',','.') or '0') / 3600.0
            offset = 4

        elif params[3] in list_s:
            lat = -float(params[0].replace(',','.')) - float(params[1].replace(',','.') or '0') / 60.0 - float(params[2].replace(',','.') or '0') / 3600.0
            offset = 4

        else:
            raise ValueError("NS parse error", params)

        if params[offset + 1] in list_e:
            lon = float(params[offset + 0].replace(',','.'))
            offset += 2

        elif params[offset + 1] in list_w:
            lon = -float(params[offset + 0].replace(',','.'))
            offset += 2

        elif params[offset + 2] in list_e:
            lon = float(params[offset + 0].replace(',','.')) + float(params[offset + 1].replace(',','.') or '0') / 60.0
            offset += 3

        elif params[offset + 2] in list_w:
            lon = -float(params[offset + 0].replace(',','.')) - float(params[offset + 1].replace(',','.') or '0') / 60.0
            offset += 3

        elif params[offset + 3] in list_e:
            lon = float(params[offset + 0].replace(',','.')) + float(params[offset + 1].replace(',','.') or '0') / 60.0 + float(params[offset + 2].replace(',','.') or '0') / 3600.0
            offset += 4

        elif params[offset + 3] in list_w:
            lon = -float(params[offset + 0].replace(',','.')) - float(params[offset + 1].replace(',','.') or '0') / 60.0 - float(params[offset + 2].replace(',','.') or '0') / 3600.0
            offset += 4

        else:
            raise ValueError("EW parse error", params)

    try:
        aux = {i[0]: i[1] for i in [p.split(':') for p in params[offset:]]}
    except:
        aux = {}

    # determine type and style index
    style = 0
    pop = 0
    type = None
    if 'type' in aux:
        type = aux['type']

        if type == 'mountain':
            style = 2

        elif type == 'country':
            style = 3

        elif type == 'event':
             style = 10

        else:
            match = city_re.match(type)
            if match:
                try:
                    pop = int(match.group(1).replace(',','').replace('.',''))
                except:
                    # invalid population entries (should get fixed, but we ignore them for now)
                    pop = 0

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

    # determine heading (if provided)
    heading = None
    if 'heading' in aux:
        heading = float(aux['heading'])

    # planetary body (default to 0 = earth)
    globe = 0
    if 'globe' in aux and aux['globe']:
        # normalize globe capitalization (throws for invalid globes - which should not be displayed on earth)
        globe = list_globe.index(aux['globe'].lower())

    # deal with scale
    scale = 0
    if 'scale' in aux and aux['scale']:
        scale = int(aux['scale'].replace(',','').replace('.',''))

    # deal with dim (do something fancier in the future)
    if 'dim' in aux and aux['dim']:
        try:
            scale = int(aux['dim'])
        except:
            if aux['dim'][-2:] == 'km':
                scale = int(float(aux['dim'][:-2]) * 1000)
            elif aux['dim'][-2:] == 'mi':
                scale = int(float(aux['dim'][:-2]) * 1609.3)
            elif aux['dim'][-1:] == 'm':
                scale = int(aux['dim'][:-1])

    # process page name or title
    if 'title' in qs and qs['title'][0]:
        name = qs['title'][0]
        weight = 0
        bad = False
    else:
        name = shortenName(name)
        bad = True

    # calculate final weight
    weight = (weight + pop/20 + scale - len(name)**2)

    if math.isnan(lat):
        raise ValueError("Lattitude is NaN")
    if math.isnan(lon):
        raise ValueError("Longitude is NaN")
    if math.isnan(weight):
        raise ValueError("Weight is NaN")
    if math.isnan(scale):
        raise ValueError("Scale is NaN")

    return {
        'lat': lat,
        'lon': lon,
        'style': style,
        'weight': weight,
        'scale': scale,
        'title': name,
        'globe': globe,
        'bad': bad,
        'type': type,
        'heading': heading
    }

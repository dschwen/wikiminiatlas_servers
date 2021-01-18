# geolink parsing module

import re
from urllib import parse as urllib_parse

us_states = "Alabama|Alaska|Arizona|Arkansas|California|Colorado|Connecticut|Delaware|Florida|Georgia|Hawaii|Idaho|Illinois|Indiana|Iowa|Kansas|Kentucky|Louisiana|Maine|Maryland|Massachusetts|Michigan|Minnesota|Mississippi|Missouri|Montana|Nebraska|Nevada|New Hampshire|New Jersey|New Mexico|New York|North Carolina|North Dakota|Ohio|Oklahoma|Oregon|Pennsylvania|Rhode Island|South Carolina|South Dakota|Tennessee|Texas|Utah|Vermont|Virginia|Washington|West Virginia|Wisconsin|Wyoming"
au_territories = "New South Wales|Victoria|South Australia|Queensland|Western Australia|Northern Territory|Tasmania|Australian Capital Territory"
cdn_terrprov = "Ontario|Quebec|Nova Scotia|New Brunswick|Manitoba|British Columbia|Prince Edward Island|Saskatchewan|Alberta|Newfoundland and Labrador|Northwest Territories|Yukon|Nunavut"

us1_re = re.compile('^(.*) Township, .* County, (' + us_states + ')$')
us2_re = re.compile('^(.*) Township, (' + us_states + ')$')
us3_re = re.compile('^(.*) \((' + us_states + ')\)$')
us4_re = re.compile('^(.*) \(.*County, (' + us_states + ')\)$')

all_prov_re = re.compile("^(.*), (" + us_states + '|' + au_territories + '|' + cdn_terrprov + ')$')

globe_re = re.compile('^(Mercury|Ariel|Phobos|Deimos|Mars|Rhea|Oberon|Europa|Tethys|Pluto|Miranda|Titania|Phoebe|Enceladus|Venus|Moon|Hyperion|Triton|Ceres|Dione|Titan|Ganymede|Umbriel|Callisto|Jupiter|Io|Earth|Mimas|Iapetus)$')
city_re = re.compile('^city\((.*)\)$')

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

#
# parse link and default page name
#
def parse(link, name, weight):
    qs = urllib_parse.parse_qs(link)

    if not 'params' in qs:
        raise ValueError("No 'params' parameter found", qs)

    # parse params
    params = qs['params'][0].split('_')
    if params[1] in list_n:
        lat = float(params[0])
        offset = 2

    elif params[1] in list_s:
        lat = -float(params[0])
        offset = 2

    elif params[2] in list_n:
        lat = float(params[0]) + float(params[1] or '0') / 60.0
        offset = 3

    elif params[2] in list_s:
        lat = -float(params[0]) - float(params[1] or '0') / 60.0
        offset = 3

    elif params[3] in list_n:
        lat = float(params[0]) + float(params[1] or '0') / 60.0 + float(params[2] or '0') / 3600.0
        offset = 4

    elif params[3] in list_s:
        lat = -float(params[0]) - float(params[1] or '0') / 60.0 - float(params[2] or '0') / 3600.0
        offset = 4

    else:
        raise ValueError("NS parse error", params)

    if params[offset + 1] in list_e:
        lon = float(params[offset + 0])
        offset += 2

    elif params[offset + 1] in list_w:
        lon = -float(params[offset + 0])
        offset += 2

    elif params[offset + 2] in list_e:
        lon = float(params[offset + 0]) + float(params[offset + 1] or '0') / 60.0
        offset += 3

    elif params[offset + 2] in list_w:
        lon = -float(params[offset + 0]) - float(params[offset + 1] or '0') / 60.0
        offset += 3

    elif params[offset + 3] in list_e:
        lon = float(params[offset + 0]) + float(params[offset + 1] or '0') / 60.0 + float(params[offset + 2] or '0') / 3600.0
        offset += 4

    elif params[offset + 3] in list_w:
        lon = -float(params[offset + 0]) - float(params[offset + 1] or '0') / 60.0 - float(params[offset + 2] or '0') / 3600.0
        offset += 4

    else:
        raise ValueError("EW parse error", params)

    try:
        aux = {i[0]: i[1] for i in [p.split(':') for p in params[offset:]]}
    except:
        aux = {}

    # determine style index
    style = 0
    pop = 0
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
                pop = int(match.group(1).replace(',','').replace('.',''))

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

    if 'globe' in aux and globe_re.match(aux['globe']):
        globe = aux['globe']
    else:
        globe = ''

    # deal with scale
    scale = 0
    if 'scale' in aux:
        scale = int(aux['scale'])

    # process page name
    name = shortenName(name)

    # calculate final weight
    weight = (weight + pop/20 + scale - len(name)**2)

    return {
        'lat': lat,
        'lon': lon,
        'style': style,
        'weight': weight,
        'scale': scale,
        'title': name,
        'globe': globe
    }

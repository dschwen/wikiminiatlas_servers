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


#
# parse link and default page name
#
def parse(link, name, weight):
    qs = urllib_parse.parse_qs(link)

    if not 'params' in qs:
        raise "No 'params' parameter found"

    # parse params
    params = qs['params'][0].split('_')

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
        raise "NS parse error"


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
        raise "EW parse error"

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

    if 'globe' in aux and globe_re.match(aux['globe']):
        globe = aux['globe']
    else
        globe = ''

    # process page name
    name = shortenName(name)

    # calculate final weight
    weight = (weight + pop/20 - len(name)**2)

    return {
        'lat': lat,
        'lon': lon,
        'style': style,
        'weight': weight,
        'title': name,
        'globe': globe
    }

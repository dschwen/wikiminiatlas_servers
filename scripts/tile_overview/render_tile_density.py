#!/usr/bin/env python3

import grp
import pwd
import os

# change to group www-data
gid = grp.getgrnam('www-data').gr_gid
os.setgid(gid)

# change to user www-data
pw  = pwd.getpwnam('www-data')
os.setuid(pw.pw_uid)

import sys
import matplotlib.pyplot as plt
import numpy as np

if len(sys.argv) < 2 :
    print("Usage ", sys.argv[0], " zoom_level")
    sys.exit(1)

z = int(sys.argv[1])
if z < 1 or z > 12:
    print("valid zoom levels are 1-12")

# do binning above zoom level 8
z2 = z if z <= 8 else 8
n = 1 << (z - z2)

h = 3 * (1 << z2)
w = 2*h

print(n,w,h,z,z2)

# counting buffer
count = np.zeros((h,w)) 

# walk mapnik tree at zoom_level
rootdir ='/volume/mapnik/%d' % z
for root, subdirs, files in os.walk(rootdir) :
    for f in files :
        c = f[:-4].split("_")
        try:
            x = int(c[2]) // n
            y = int(c[1]) // n
            count[y][x] += 1
        except:
            print(f)

plt.imsave("overview_%d.png" % z, count)

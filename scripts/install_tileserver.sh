#!/bin/bash

sudo mkdir -p /var/run/wma
sudo chown www-data:www-data /var/run/wma

mkdir ~/bin
cp -a service ~/bin

for LEVEL in 8 9 10 11 12
do
  svc=wma-mapnik-${LEVEL}.service
  export LEVEL
  envsubst < wma-mapnik.service > $svc
  sudo cp $svc /lib/systemd/system
  pushd /etc/systemd/system
  sudo ln -sf /lib/systemd/system/$svc .
  popd
  sudo systemctl daemon-reload
  sudo systemctl start $svc

  echo check with: sudo journalctl -e -u $svc
done


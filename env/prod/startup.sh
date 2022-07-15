#!/bin/bash

sudo apt-get update
sudo apt -y install apache2
sudo cat <<EOF > /var/www/html/index.html
<html><body><p>Hello World!</p></body></html>
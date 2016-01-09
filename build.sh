#!/bin/sh

OUTPUT_DIR=$(cd ../output; pwd)

docker build \
    -t stuaxo/ubuntu-cairogl-debs .

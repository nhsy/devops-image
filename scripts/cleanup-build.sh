#!/bin/sh
set -e

rm -rf /tmp/* /var/tmp/*
find / -regex ".*/__pycache__" -exec rm -rf '{}' \; || true
rm -rf ~/.wget-hsts

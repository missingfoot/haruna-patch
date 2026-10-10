#!/bin/bash
# Follow the rebuild log live (Ctrl+C to stop).
journalctl -u haruna-repatch -f -n 30

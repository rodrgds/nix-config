#!/usr/bin/env bash

# Set stretched resolution before game starts
stretched

# Launch CS2 with all arguments passed through
gamemoderun "$@"

# Restore full resolution after game closes
fullres

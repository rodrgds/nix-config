#!/usr/bin/env bash

# The desktop uses NVIDIA's full composition pipeline to avoid tearing. Do not
# carry it into latency-sensitive fullscreen play: it adds another composed
# frame and makes the GPU do unnecessary work. ViewPortOut still provides the
# desired 4:3 stretched scaling.
nvidia-settings -a CurrentMetaMode="DP-0: 1920x1080_144 @1280x960 +0+0 {ViewPortIn=1280x960, ViewPortOut=1920x1080+0+0, ForceCompositionPipeline=Off, ForceFullCompositionPipeline=Off}"

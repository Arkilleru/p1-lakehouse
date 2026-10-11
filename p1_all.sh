#!/usr/bin/env bash
cd "$(dirname "$0")"
bash p1_codec_test.sh && bash p1_build.sh ZSTD

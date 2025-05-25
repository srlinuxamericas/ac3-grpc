# Copyright 2020 Nokia
# Licensed under the BSD 3-Clause License.
# SPDX-License-Identifier: BSD-3-Clause

# Start iperf3 server in the background
# with 8 parallel tcp streams, each 200 Kbit/s == 1.6Mbit/s
# using ipv6 interfaces
pkill iperf3
iperf3 -c 172.16.10.50 -t 10000 -i 1 -p 5201 -B 172.16.10.60 -P 8 -b 125K -M 1400 &

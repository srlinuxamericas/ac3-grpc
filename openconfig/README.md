# gNMI with Openconfig models

Openconfig is a standards based vendor neutral way for configuring and retrieving state from Network Operating Systems (NOS). Openconfig is standardized by [Openconfig.net](https://www.openconfig.net/). Openconfig communication is based on yang models.

Openconfig yang models are published at [GitHub](https://github.com/openconfig/public).

Nokia SR Linux supports Openconfig.

In this section, we will explore openconfig yang configuration and state using CLI and gNMI.

## Openconfig in SR Linux

Openconfig models can be used via CLI, Netconf, gRPC or JSON-RPC interfaces in SR Linux.

SR Linux openconfig CLI interface is similar to the native interface with all CLI features like commit, rollback, discard, commit confirm also supported in openconfig.

Here's quick reference table to switch between SRL and OC modes in CLI.

|Model | From Mode | To Mode | Command |
|-----|-----------|---------|---------|
|SRL|running|candidate|enter candidate|
|SRL|candidate|running|enter running|
|SRL|candidate|state|enter state|
|SRL|running|state|enter state|
|SRL to OC|SRL running|OC running|enter oc|
|SRL to OC|SRL running|OC candidate|enter oc candidate|
|SRL to OC|SRL running|OC state|enter oc state|
|OC to SRL|OC running|SRL running|enter srl|
|OC to SRL|OC running|SRL candidate|enter srl candidate|
|OC to SRL|OC running|SRL state|enter srl state|

In short, if you want to switch between the same mode on SRL and OC, use `enter srl` or `enter oc`.

If you want to switch to a different mode, then use the mode name (running/candidate/state) with the above command.

The current mode is displayed on the first line of the CLI prompt.

For example:

```bash
--{ + oc state }--[  ]--
A:g15-spine11#
```

Openconfig is enabled on all 3 devices. This can be verified using:

```bash
info flat from state system management openconfig
```

### gNMI Get with Openconfig

All interfaces were configured using SR Linux commands when the lab was deployed. With SR Linux Openconfig implementation, it is possible to see this config in Openconfig format.

Let's start with checking this in CLI.

Login to leaf1 and change to OC running mode using:

```bash
enter oc
```

Then run the below command to see interface ethernet-1/1 configuration in Openconfig format.

```bash
info flat interfaces interface ethernet-1/1
```

Expected output:

```bash
set / interfaces interface ethernet-1/1 config name ethernet-1/1
set / interfaces interface ethernet-1/1 config type ethernetCsmacd
set / interfaces interface ethernet-1/1 config description To-Spine
set / interfaces interface ethernet-1/1 config enabled true
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 config index 0
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 ipv4 addresses address 192.168.10.2 config ip 192.168.10.2
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 ipv4 addresses address 192.168.10.2 config prefix-length 31
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 ipv4 config enabled true
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 ipv6 addresses address 192:168:10::2 config ip 192:168:10::2
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 ipv6 addresses address 192:168:10::2 config prefix-length 127
set / interfaces interface ethernet-1/1 subinterfaces subinterface 0 ipv6 config enabled true
```

Now let's try to get this using gNMI Get RPC.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path openconfig:/interfaces/interface[name=ethernet-1/1] --encoding json_ietf -t config
```

Expected output:

```bash
[
  {
    "source": "leaf1:57401",
    "timestamp": 1747470480245781747,
    "time": "2025-05-17T04:28:00.245781747-04:00",
    "updates": [
      {
        "Path": "openconfig:interfaces/interface[name=ethernet-1/1]",
        "values": {
          "interfaces/interface": {
            "config": {
              "description": "To-Spine",
              "enabled": true,
              "name": "ethernet-1/1",
              "type": "iana-if-type:ethernetCsmacd"
            },
            "subinterfaces": {
              "subinterface": [
                {
                  "config": {
                    "index": 0
                  },
                  "index": 0,
                  "openconfig-if-ip:ipv4": {
                    "addresses": {
                      "address": [
                        {
                          "config": {
                            "ip": "192.168.10.2",
                            "prefix-length": 31
                          },
                          "ip": "192.168.10.2"
                        }
                      ]
                    },
                    "config": {
                      "enabled": true
                    }
                  },
                  "openconfig-if-ip:ipv6": {
                    "addresses": {
                      "address": [
                        {
                          "config": {
                            "ip": "192:168:10::2",
                            "prefix-length": 127
                          },
                          "ip": "192:168:10::2"
                        }
                      ]
                    },
                    "config": {
                      "enabled": true
                    }
                  }
                }
              ]
            }
          }
        }
      }
    ]
  }
]
```

Next let's get an Openconfig counter  - out packets for interface `ethernet-1/1`.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path openconfig:/interfaces/interface[name=ethernet-1/1]/state/counters/out-pkts --encoding json_ietf
```

Expected output:

```bash
[
  {
    "source": "leaf1:57401",
    "timestamp": 1747470650512684538,
    "time": "2025-05-17T04:30:50.512684538-04:00",
    "updates": [
      {
        "Path": "openconfig:interfaces/interface[name=ethernet-1/1]/state/counters/out-pkts",
        "values": {
          "interfaces/interface/state/counters/out-pkts": "658"
        }
      }
    ]
  }
]
```

### gNMI Set with Openconfig

All the gNMI Set methods we tried previously with SR Linux models are also valid with Openconfig models.

Due to time constraints, we will not repeat them here.

When Openconfig is not fully supported for every config element within a context, a mix of vendor specific (also called native) and openconfig models are used to complete the configuration.

As part of our fabric deployment, the following should be configured next:

- BGP for underlay
- BGP for overlay between leafs
- Layer 2 EVPN-VXLAN between clients 1 and 3

Not all objects for these configurations are supported in Openconfig. So we will use Nokia models to cover the gaps.

We will use the gNMI Get RPC with the `--update-path` and `--update-file` options.

Openconfig configuration file for all 3 devices are inside [oc](../configs/oc/).

SR Linux configuration files are inside [srl](srl/).

Before we push the configuration, verify that BGP is not configured in default network-instance using gNMI Get.

For example, to check on leaf1:

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path openconfig:/network-instances/network-instance[name=default] --encoding json_ietf
```


Now, we are ready to push the configuration using a mix of Openconfig and SR Linux models.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure set --update-path openconfig:/ --update-file configs/oc/leaf1-oc.cfg --update-path srl_nokia:/ --update-file srl/leaf1-srl.cfg --encoding=json_ietf
```

Expected output:

```bash
{
  "source": "leaf1:57401",
  "timestamp": 1747472611260898005,
  "time": "2025-05-17T05:03:31.260898005-04:00",
  "results": [
    {
      "operation": "UPDATE",
      "path": "openconfig:"
    },
    {
      "operation": "UPDATE",
      "path": "srl_nokia:"
    }
  ]
}
```

Run the Get RPC used above to verify that BGP and MAC-VRF are now configured.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path openconfig:/network-instances/network-instance[name=default] --encoding json_ietf
```

Complete configuration on leaf2 and spine.

```bash
gnmic -a leaf2:57401 -u admin -p admin --insecure set --update-path openconfig:/ --update-file configs/oc/leaf2-oc.cfg --update-path srl_nokia:/ --update-file srl/leaf2-srl.cfg --encoding=json_ietf

gnmic -a spine:57401 -u admin -p admin --insecure set --update-path openconfig:/ --update-file configs/oc/spine-oc.cfg --update-path srl_nokia:/ --update-file srl/spine-srl.cfg --encoding=json_ietf
```

With the configuration that we pushed, the BGP neighbor sessions should come UP and start advertising the routes.

Let's verify this using gNMI Get.

As an example, let's verify the status of BGP neighbor `2.2.2.2` on leaf1 using SR Linux model.

To reduce the output, we will use the `depth` option supported in gnmic.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path /network-instance[name=default]/protocols/bgp/neighbor[peer-address=2.2.2.2] --encoding json_ietf --depth 1
```

Expected output:

```bash
[
  {
    "source": "leaf1:57401",
    "timestamp": 1747629677667519827,
    "time": "2025-05-19T00:41:17.667519827-04:00",
    "updates": [
      {
        "Path": "srl_nokia-network-instance:network-instance[name=default]/protocols/srl_nokia-bgp:bgp/neighbor[peer-address=2.2.2.2]",
        "values": {
          "srl_nokia-network-instance:network-instance/protocols/srl_nokia-bgp:bgp/neighbor": {
            "admin-state": "enable",
            "advertised-capabilities": [
              "ROUTE_REFRESH",
              "4-OCTET_ASN",
              "MP_BGP",
              "GRACEFUL_RESTART"
            ],
            "established-transitions": "1",
            "last-established": "2025-05-19T04:28:59.500Z",
            "last-event": "recvOpen",
            "last-state": "active",
            "local-preference": 100,
            "maintenance-group": "",
            "next-hop-self": false,
            "peer-as": 65500,
            "peer-group": "evpn",
            "peer-router-id": "2.2.2.2",
            "peer-type": "ibgp",
            "received-afi-safi": [
              "srl_nokia-common:evpn"
            ],
            "received-capabilities": [
              "ROUTE_REFRESH",
              "4-OCTET_ASN",
              "MP_BGP",
              "GRACEFUL_RESTART"
            ],
            "received-end-of-rib": [
              "srl_nokia-common:evpn"
            ],
            "route-flap-damping": false,
            "sent-end-of-rib": [
              "srl_nokia-common:evpn"
            ],
            "session-state": "established",
            "under-maintenance": false
          }
        }
      }
    ]
  }
]
```

The Layer 2 EVPN should be UP and we should be able to ping from Client 1 to Client 3.

Login to Client 1:

```bash
docker exec -it client1 bash
```

and run a ping to Client 3

```bash
ping -c 3 172.16.10.60
```

### gNMI Subscribe with Openconfig

gNMI Subscribe for Openconfig Streaming Telemetry works in the same manner as the SR Linux models.

We will try the ON-CHANGE option in this section with Openconfig models.

Let us stream the out packets counter on `leaf1` using on-change option.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure sub --path openconfig:/interfaces/interface[name=ethernet-1/1]/state/counters/out-pkts --mode stream --stream-mode on-change
```

Because we are using the on-change option, we will only see an output when the counter value changes.

On another window, run the ping from Client 1 to Client 3 as shown in previous section.

Verify that the streaming session is now showing outputs for each counter increment.

Stop the ping and the streaming session using `CTRL+c`.

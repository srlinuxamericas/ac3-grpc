# gNMI Use Cases

## gNMI Capabilities

We will start by verifying gNMI capabilities on the SR Linux device using the gNMI Capabilities RPC.

This is also a test to confirm whether gNMI is enabled on the device.

```bash
gnmic -a leaf1:57401 -u gnmic1 -p gnmic1 --insecure cap
```

Expected output:

```bash
gNMI version: 0.10.0
supported models:
  - urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring:ietf-netconf-monitoring, IETF NETCONF (Network Configuration) Working Group, 2010-10-04
  - urn:ietf:params:xml:ns:yang:ietf-yang-library:ietf-yang-library, IETF NETCONF (Network Configuration) Working Group, 2019-01-04
  - urn:nokia.com:srlinux:aaa:aaa:srl_nokia-aaa, Nokia, 2025-03-31
  - urn:nokia.com:srlinux:aaa:aaa-password:srl_nokia-aaa-password, Nokia, 2025-03-31
  <---truncated--->
  supported encodings:
  - JSON_IETF
  - PROTO
  - ASCII
  <---truncated--->
```

## gNMI Get

gNMI Get RPC is used to retrieve the running configuration or operational state on the device.

The lab startup configuration included all interfaces. Let's verify the configuration of the interface on leaf1 facing spine.

To get the gNMI Xpath of an object, refer to the [SR Linux yang explorer](https://yang.srlinux.dev/) page. Search for the configuration or state object you are looking for.

Alternatively, you can also get the gNMI Xpath of an object from SR Linux CLI. Navigate to that object's context in SR LInux CLI.

For example, on leaf1:


```bash
interface ethernet-1/1
```

Then run below command to get the gNMI path to be used in the gNMI request.

```bash
pwc xpath
```

Expected output:

```bash
/interface[name=ethernet-1/1]
```


Now that we have the path, let's get the configuration of this interface using gNMI.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure --encoding json_ietf get --path /interface[name=ethernet-1/1] --type config
```

Expected output:

```bash
[
  {
    "source": "leaf1:57401",
    "timestamp": 1747456760340484174,
    "time": "2025-05-17T00:39:20.340484174-04:00",
    "updates": [
      {
        "Path": "srl_nokia-interfaces:interface[name=ethernet-1/1]",
        "values": {
          "srl_nokia-interfaces:interface": {
            "admin-state": "enable",
            "description": "To-Spine",
            "subinterface": [
              {
                "index": 0,
                "ipv4": {
                  "address": [
                    {
                      "ip-prefix": "192.168.10.2/31"
                    }
                  ],
                  "admin-state": "enable"
                },
                "ipv6": {
                  "address": [
                    {
                      "ip-prefix": "192:168:10::2/127"
                    }
                  ],
                  "admin-state": "enable"
                }
              }
            ]
          }
        }
      }
    ]
  }
]
```

Next let's get only the operational state of the client facing interface using gNMI. This comes from the state datastore.

To get the state gNMI Xpath, search for the leafs under interface context in the SR Linux yang explorer.

```
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path /interface[name=ethernet-1/10]/oper-state --encoding json_ietf
```

Expected output:

```
[
  {
    "source": "leaf1",
    "timestamp": 1738338440926776288,
    "time": "2025-01-31T17:47:20.926776288+02:00",
    "updates": [
      {
        "Path": "srl_nokia-interfaces:interface[name=ethernet-1/10]/oper-state",
        "values": {
          "srl_nokia-interfaces:interface/oper-state": "up"
        }
      }
    ]
  }
]
```

## gNMI Set

gNMI Set RPC is used to make configuration changes on the device.

There are multiple ways to update the configuration and we will explore a few of them in this workshop.

### Update

The `Update` option is to used to configure one leaf at a time.

We will start by configuring the interface MTU on the client facing `ethernet-1/10` interface on leaf1.

Before we set the MTU, verify the current MTU from the state datastore using gNMI.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path /interface[name=ethernet-1/10]/mtu --encoding json_ietf
```

The current MTU value should be 9232. Let's change this to 4000.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure set --update /interface[name=ethernet-1/10]/mtu:::json:::4000
```

Expected output:

```bash
{
  "source": "leaf1",
  "timestamp": 1747459840732939059,
  "time": "2025-05-17T01:30:40.732939059-04:00",
  "results": [
    {
      "operation": "UPDATE",
      "path": "interface[name=ethernet-1/10]/mtu"
    }
  ]
}
```

Verify the new MTU value using the Get request used above.

### Update Path

Another way to specify a path and value is using `--update-path` and `--update-value` options.

Modify the MTU of `ethernet-1/10` on leaf1 to 3600 using these keywords.

```bash
gnmic -a leaf1 -u admin -p admin --skip-verify set --update-path /interface[name=ethernet-1/10]/mtu --update-value 3600 --encoding json_ietf
```

Verify the current MTU using the Get request shown above.

### Update File

When multiple config objects are required to be updated, the configuration can be included in a file and sent to the device using the `--update-path` and `--update-file` options.

We will configure the `system0` loopback interface on all 3 devices using this method.

|Device|System IP|
|--|--|
|leaf1|1.1.1.1/32|
|leaf2|2.2.2.2/32|
|spine|3.3.3.3/32|

The config files are located on your repo under [gnmi](gnmi/) are in `json` format.

Note:
If you are wondering how to prepare the configuration in `json` format, SR Linux CLI has an option to display the configuration in `json` format. After an interface is configured, run the below command to display the interface configuration in `json` format. This can be copied to a file and used in the gNMI Set request.

```bash
info interface system0 | as json
```

Let's push the system interface configuration on all 3 devices.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure set --update-path /interface[name=system0] --update-file gnmi/leaf1-system.cfg --encoding json_ietf
gnmic -a leaf2:57401 -u admin -p admin --insecure set --update-path /interface[name=system0] --update-file gnmi/leaf2-system.cfg --encoding json_ietf
gnmic -a spine:57401 -u admin -p admin --insecure set --update-path /interface[name=system0] --update-file gnmi/spine-system.cfg --encoding json_ietf
```

Expected output for leaf1:

```bash
{
  "source": "leaf1:57401",
  "timestamp": 1747461147038798924,
  "time": "2025-05-17T01:52:27.038798924-04:00",
  "results": [
    {
      "operation": "UPDATE",
      "path": "interface[name=system0]"
    }
  ]
}
```

Verify the `system0` interface configuration using the Get RPC used earlier.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure --encoding json_ietf get --path /interface[name=system0] --type config
```

### Replace File

When replacing or overwriting an entire section of the config, the new config to be applied can be specified in a file along with the `--replace-path` and `--replace-file` options.

This is equivalent to deleting the existing SNMP community and then configuring the new community value in 2 separate operations.

To try this, we will replace the SNMP section with a new config that has a different community value.

Verify the current SNMP configuration on leaf1:

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path /system/snmp --encoding json_ietf -t config
```

Expected output:

```bash
[
  {
    "source": "leaf1:57401",
    "timestamp": 1747463297504455730,
    "time": "2025-05-17T02:28:17.50445573-04:00",
    "updates": [
      {
        "Path": "srl_nokia-system:system/srl_nokia-system-snmp:snmp",
        "values": {
          "srl_nokia-system:system/srl_nokia-system-snmp:snmp": {
            "access-group": [
              {
                "community-entry": [
                  {
                    "community": "$aes1$AWBE6lIUmkA5sm8=$4iIHX6bSJuhf2Eqhbjb9QA==",
                    "name": "RO-Community"
                  }
                ],
                "name": "SNMPv2-RO-Community",
                "security-level": "no-auth-no-priv"
              }
            ],
            "network-instance": [
              {
                "admin-state": "enable",
                "name": "mgmt"
              }
            ]
          }
        }
      }
    ]
  }
]
```

We will replace this section with the configuration in [leaf1-snmp.cfg](leaf1-snmp.cfg) that replaces the above community with a new community string.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure set --replace-path /system/snmp --replace-file gnmi/leaf1-snmp.cfg --encoding json_ietf
```

Expected output:


```bash
{
  "source": "leaf1:57401",
  "timestamp": 1747463796136833293,
  "time": "2025-05-17T02:36:36.136833293-04:00",
  "results": [
    {
      "operation": "REPLACE",
      "path": "system/snmp"
    }
  ]
}
```

Now verify the SNMP config using the Get method.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path /system/snmp --encoding json_ietf -t config
```

Expected output:

```bash
[
  {
    "source": "leaf1:57401",
    "timestamp": 1747463861177086072,
    "time": "2025-05-17T02:37:41.177086072-04:00",
    "updates": [
      {
        "Path": "srl_nokia-system:system/srl_nokia-system-snmp:snmp",
        "values": {
          "srl_nokia-system:system/srl_nokia-system-snmp:snmp": {
            "access-group": [
              {
                "community-entry": [
                  {
                    "community": "$aes1$AWAdu4eU6gBcGG8=$5e7xP9EPZNMu4yweZDHwXA==",
                    "name": "ac3"
                  }
                ],
                "name": "ac3-snmpv2-community",
                "security-level": "no-auth-no-priv"
              }
            ],
            "network-instance": [
              {
                "admin-state": "enable",
                "name": "mgmt"
              }
            ]
          }
        }
      }
    ]
  }
]
```

### Update CLI File

Unlike SR Linux, some systems may not have 100% yang coverage for all configuration objects.

And if gNMI is to be used as the only configuration tool, it is beneficial to have gNMI support config push using raw CLI commands. This is the purpose of the `--update-cli-file` option.

Let's add a SNMP community but this time pushed using raw CLI.

The SNMP community configuration in CLI format is in [leaf1-cli.cfg](leaf1-cli.cfg).

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure set --update-cli-file gnmi/leaf1-cli.cfg
```

Expected output:

```bash
{
  "source": "leaf1:57401",
  "timestamp": 1747464582047688395,
  "time": "2025-05-17T02:49:42.047688395-04:00",
  "results": [
    {
      "operation": "UPDATE",
      "path": "cli:"
    }
  ]
}
```

Verify the updated SNMP communities using Get RPC.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path /system/snmp --encoding json_ietf -t config
```

### Commit confirm

Commit confirm is a useful CLI feature when making critical changes. Using this feature allows the system to do an automatic rollback if the user does not accept or cancel a commit confirm before the timeout.

This feature is also supported on gNMIc.

To try this, we will change the MTU value of `ethernet-1/10` on leaf1 from current value of 3600 to 8000.

Verify the current value using Get method:

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path /interface[name=ethernet-1/10]/mtu --encoding json_ietf
```

Update the value to 8000 along with enabling commit confirm with a rollback duration of 5 minutes.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure set --update /interface[name=ethernet-1/10]/mtu:::json:::8000 --commit-id mtu-8000 --commit-request --rollback-duration 5m
```

Expected output:

```bash
{
  "source": "leaf1:57401",
  "timestamp": 1747465449869488290,
  "time": "2025-05-17T03:04:09.86948829-04:00",
  "results": [
    {
      "operation": "UPDATE",
      "path": "interface[name=ethernet-1/10]/mtu"
    }
  ]
}
```

Verify the new MTU value:

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path /interface[name=ethernet-1/10]/mtu --encoding json_ietf
```

We can see that the MTU value is now updated to 8000.

When there is a commit confirm in progress, the system will not allow any new configuration changes via any management interface (CLI, Netconf, gRPC, JSON-RPC) until the active commit confirm is confirmed, cancelled or the rollback timer expires.

The following error will be displayed when trying to commit a new change while a commit confirm is ongoing.

```bash
target "leaf1:57401" set request failed: target "leaf1:57401" SetRequest failed: rpc error: code = Aborted desc = Cannot commit transaction (commit confirmed in progress)
```

Details of an active commit confirm can be see from CLI using the following command:

```bash
info flat from state system configuration commit * | tail
```

Wait for 5 minutes and then verify the MTU again.

Since we did not accept the commit confirm, the system will do an automatic rollback when the rollback timer expires.

We can see from the latest Get result that the MTU is back at the original value of 3600.

Let's do another MTU update to 7500 and this time we will accept the commit confirm.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure set --update /interface[name=ethernet-1/10]/mtu:::json:::7500 --commit-id mtu-7500 --commit-request --rollback-duration 5m
```

Verify the new MTU value using Get:

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path /interface[name=ethernet-1/10]/mtu --encoding json_ietf
```

Confirm the commit before the rollback timer expires.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure set --commit-id mtu-7500 --commit-confirm
```

Expected output:

```bash
{
  "source": "leaf1:57401",
  "time": "1969-12-31T19:00:00-05:00"
}
```

The MTU change is now permanently applied.

### Delete

Our last option with the Set method is to delete a configuration element.

Let us delete the MTU from `ethernet-1/10` on leaf1 so it will revert back to the default MTU value.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure set --delete /interface[name=ethernet-1/10]/mtu
```

Expected output:

```bash
{
  "source": "leaf1:57401",
  "timestamp": 1747466906469111959,
  "time": "2025-05-17T03:28:26.469111959-04:00",
  "results": [
    {
      "operation": "DELETE",
      "path": "interface[name=ethernet-1/10]/mtu"
    }
  ]
}
```

Verify the current MTU value after the delete operation. It should now be set to the default MTU which is 9232.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path /interface[name=ethernet-1/10]/mtu --encoding json_ietf
```

## gNMI Subscribe

The Subscribe RPC is the most commonly used gNMI RPC under the disguise of Streaming Telemetry.

We will try 3 different telemetry options during this workshop.

### Once

Just like SNMP polling, it is possible to poll a specific object using gNMI with the `ONCE` option in the Subscribe RPC.

Let us get the out packets of interface `ethernet-1/1` on leaf1 using this method.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure sub --path /interface[name=ethernet-1/1]/statistics/out-packets --mode once
```

Expected output:

```bash
{
  "source": "leaf1:57401",
  "subscription-name": "default-1747467756",
  "timestamp": 1747467756599186463,
  "time": "2025-05-17T03:42:36.599186463-04:00",
  "updates": [
    {
      "Path": "interface[name=ethernet-1/1]/statistics/out-packets",
      "values": {
        "interface/statistics/out-packets": "552"
      }
    }
  ]
}
```

### Sample

If we need a continous stream of this stat, we will use the `SAMPLE` option along with a specific interval.

The following command streams the out packets value every 15 seconds.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure sub --path /interface[name=ethernet-1/1]/statistics/out-packets --mode stream --stream-mode sample --sample-interval 15s
```

The streaming session can be stopped using `CTRL+c`.


### On change

In some cases, we only want a counter when the value has changed. For example, after a new interface is configured, the out packets will be 0 until a protocol and neighbor are established. There is benefit in streaming continous 0.

This is where the `ON-CHANGE` option comes to the rescue.

When this option is enabled, the system will only stream data when the value of the object has changed.

Let us stream the same out packets counter using this method.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure sub --path /interface[name=ethernet-1/1]/statistics/out-packets --mode stream --stream-mode on-change
```

You will notice that the system is not streaming this counter as there is no change in the counter value.

Keep the streaming session going and open another window to leaf1. Start a ping from leaf1 to the spine interface.

```bash
ping 192.168.10.3 network-instance default
```

While ping is in progress, check the streaming output. There should be a continous stream of the counter for every increment in the packet count.

Stop the ping using `CTRL+c` and check the streaming output again. The stream has slowed down or is not streaming any more as there is no change in the counter value.

Stop the streaming session using `CTRL+c`.

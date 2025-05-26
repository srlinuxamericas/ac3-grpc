# Bonus Challenges

## Securing gNMI service

When setting up streaming telemetry to an external system, by default the system allows gNMI Get, Set and Subscribe from the external system.

Configure a new user `grclient1` on `leaf1` that will be used for streaming telemetry.

Login to `leaf1` and run the following commands:

```bash
enter candidate private
set / system aaa authorization role gnmi-clients services [ gnmi ]
set / system aaa authentication user grclient1 password grclient1 role [ gnmi-clients ]
set / system configuration role gnmi-clients rule / action write
commit now
```

Configure a gNSI Authz policy to allow gNMI Get, Subscribe  and deny gNMI Set.

Here are the commands for Get, Set and Subscribe to be run from the VM.

gNMI Get:

```bash
gnmic -a leaf1 -u grclient1 -p grclient1 --skip-verify get --path /interface[name=ethernet-1/10]/mtu --encoding json_ietf
```

gNMI Set:

```bash
gnmic -a leaf1 -u grclient1 -p grclient1 --skip-verify set --update /interface[name=ethernet-1/10]/mtu:::json:::4000
```

gNMI Subscribe:

```bash
gnmic -a leaf1 -u grclient1 -p grclient1 --skip-verify sub --path /interface[name=ethernet-1/1]/statistics/out-packets --mode once
```

### Solution

Here's the gNSI Authz policy for reference:

<details>
<summary>Authz Solution</summary>
<br>
<pre>
{
  "name": "ac3-gnmi",
  "allow_rules": [
    {
      "name": "gnmi-access",
      "source": {
        "principals": [
          "grclient1","gnmi-clients"
        ]
      },
      "request": {
        "paths": [
          "/gnmi.gNMI/Get",
          "/gnmi.gNMI/Subscribe"
        ]
      }
    }
  ],
  "deny_rules": [
    {
      "name": "gnmi-access",
      "source": {
        "principals": [
          "grclient1","gnmi-clients"
        ]
      },
      "request": {
        "paths": [
          "/gnmi.gNMI/Set"
        ]
      }
    }
  ]
}
</pre>
</details>

Here's the command to push this policy:

```bash
gnsic -a leaf1 -u admin -p admin --skip-verify authz rotate --policy "{\"name\":\"ac3-gnmi\",\"allow_rules\":[{\"name\":\"gnmi-access\",\"source\":{\"principals\":[\"grclient1\",\"gnmi-clients\"]},\"request\":{\"paths\":[\"/gnmi.gNMI/Get\",\"/gnmi.gNMI/Subscribe\"]}}],\"deny_rules\":[{\"name\":\"gnmi-access\",\"source\":{\"principals\":[\"grclient1\",\"gnmi-clients\"]},\"request\":{\"paths\":[\"/gnmi.gNMI/Set\"]}}]}"
```

Verify the new policy is installed:

```bash
gnmic -a leaf1 -u admin -p admin --skip-verify get --path /system/aaa/authorization/authz-policy --encoding json_ietf
```

Note - as gnsic is beta, you may have to run the policy install command multiple times until you see the policy in the verification output above.

After the policy is installed, try gNMI Set:

```bash
gnmic -a leaf1 -u grclient1 -p grclient1 --skip-verify set --update /interface[name=ethernet-1/10]/mtu:::json:::4000
```

and the following error should be displayed:

```bash
target "leaf1" set request failed: target "leaf1" SetRequest failed: rpc error: code = PermissionDenied desc = User 'grclient1' is not authorized to use rpc '/gnmi.gNMI/Set'
Error: one or more requests failed
```

## Default route using gRIBI

Install a default route using gRIBI on `leaf1` with next-hop pointing to the direct interface to `leaf2`.

Get the list of current routes using gNMI Get:

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path "/network-instance[name=default]/route-table/ipv4-unicast" --encoding=JSON_IETF --depth 2 | grep -E "prefix|active|type"
```

Make sure that there is no default route.

Install the default route using gRIBI.

### Solution

Here's the gRIBI payload for the default route.

```yaml
default-network-instance: default

params:
  redundancy: single-primary
  persistence: preserve
  ack-type: rib-fib

operations:
  - op: add
    election-id: 1:0
    nh:
      index: 1
      ip-address: 172.16.10.1

  - op: add
    election-id: 1:0
    nhg:
      id: 1
      next-hop:
        - index: 1

  - op: add
    election-id: 1:0
    ipv4:
      prefix: 0.0.0.0/0
      nhg: 1
```

Copy the payload to a file and use gribic to inject this route.

```bash
gribic -a leaf1:57401 -u admin -p admin --insecure modify --input-file file-name.yml
```

Verify using gNMI Get that the default route is installed.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path "/network-instance[name=default]/route-table/ipv4-unicast" --encoding=JSON_IETF --depth 2 | grep -E "prefix|active|type"
```

Expected output:

```bash
"active": true,
"ipv4-prefix": "0.0.0.0/0",
"route-type": "srl_nokia-common:gribi"
```

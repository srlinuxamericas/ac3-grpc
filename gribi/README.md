The lab is deployed with the full configuration along with a loopback interface on leaf2 and spine. A static route is added on leaf2 to reach the loopback on spine.

We will use gRIBIc to install a route on spine to reach the loopback on leaf2.

Here's the payload that we will push.

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
      ip-address: 192.168.20.2

  - op: add
    election-id: 1:0
    nhg:
      id: 1
      next-hop:
        - index: 1

  - op: add
    election-id: 1:0
    ipv4:
      prefix: 10.10.10.2/32
      nhg: 1
```

Before we install the route, let's verify that ping does not work between the leaf2 and spine loopbacks.

Use gNOI to initiate a ping from spine to leaf2 loopback.

```
gnoic -a spine -u admin -p admin --skip-verify system ping --destination 10.10.10.2 --ns default --count 1 --wait 1s
```

Expected output:

```
--- 10.10.10.2 ping statistics ---
1 packets sent, 0 packets received, 100.00% packet loss
round-trip min/avg/max/stddev = 0.000/0.000/0.000/0.000 ms
```

Now let's verify the route table entries on spine and check if there is a route for `10.10.10.2/32` which is the loopback IP on leaf2.

We will be using gNMI to get this state information.

```
gnmic -a spine -u admin -p admin --skip-verify get --path "/network-instance[name=default]/route-table/ipv4-unicast" --encoding=JSON_IETF --depth 2 | grep -E "prefix|active|type"
```

<details>
<summary>Expected Output</summary>
<br>
<pre>
  "active": true,
  "ipv4-prefix": "3.3.3.3/32",
  "route-type": "srl_nokia-common:host"
  "active": true,
  "ipv4-prefix": "10.10.10.0/24",
  "route-type": "srl_nokia-common:local"
  "active": true,
  "ipv4-prefix": "10.10.10.3/32",
  "route-type": "srl_nokia-common:host"
  "active": true,
  "ipv4-prefix": "10.10.10.255/32",
  "route-type": "srl_nokia-common:host"
  "active": true,
  "ipv4-prefix": "192.168.10.2/31",
  "route-type": "srl_nokia-common:local"
  "active": true,
  "ipv4-prefix": "192.168.10.3/32",
  "route-type": "srl_nokia-common:host"
  "active": true,
  "ipv4-prefix": "192.168.20.2/31",
  "route-type": "srl_nokia-common:local"
  "active": true,
  "ipv4-prefix": "192.168.20.3/32",
  "route-type": "srl_nokia-common:host"
  "active-routes": 8,
  "active-routes-with-ecmp": 0,
</pre>
</details>

If you would like to see the full output, try running the above command without the grep.

We are using a new user `grclient1` for the gRIBI operation. This user is created as part of the lab deployment.

We will use gNSI Authz to restrict this user to get and modify gRIBI operations and block the flush operation.

```
gnsic -a spine -u admin -p admin --skip-verify authz rotate --policy "{\"name\":\"grib-clients\",\"allow_rules\":[{\"name\":\"rib-access\",\"source\":{\"principals\":[\"grclient1\",\"gribi-clients\"]},\"request\":{\"paths\":[\"/gribi.gRIBI/Get\",\"/gribi.gRIBI/Modify\"]}}],\"deny_rules\":[{\"name\":\"rib-access\",\"source\":{\"principals\":[\"grclient1\",\"gribi-clients\"]},\"request\":{\"paths\":[\"/gribi.gRIBI/Flush\"]}}]}"
```

Expected output:

```
INFO[0000] targets: map[spine:57400:0xc000356260]       
INFO[0000] "spine:57400": got UploadResponse            
INFO[0001] "spine:57400": sending finalize request      
INFO[0001] "spine:57400": closing stream 
```

Before we push the route, let's get the current installed gRIBI routes.

```
gribic -a spine:57400 -u grclient1 -p grclient1 --skip-verify get --ns default --aft ipv4
```

Expected output:

```
INFO[0000] target spine:57400: final get response:      
INFO[0000] got 1 results                                
INFO[0000] "spine:57400":   
```

There are no gRIBI routes at this time.

Now, let's push the gRIBI route. The route [instructions](#L436) are saved in a file [grib-input.yml](grib-input.yml)

```
gribic -a spine:57400 -u grclient1 -p grclient1 --skip-verify modify --input-file grib-input.yml
```

<details>
<summary>Expected Output</summary>
<br>
<pre>
INFO[0000] sending request=params:{redundancy:SINGLE_PRIMARY persistence:PRESERVE ack_type:RIB_AND_FIB_ACK} to "spine:57400" 
INFO[0000] sending request=election_id:{high:1} to "spine:57400" 
INFO[0000] spine:57400
response: session_params_result: {} 
INFO[0000] spine:57400
response: election_id: {
  high: 1
} 
INFO[0000] target spine:57400 modify request:
operation: {
  id: 1
  network_instance: "default"
  op: ADD
  next_hop: {
    index: 1
    next_hop: {
      ip_address: {
        value: "192.168.20.2"
      }
    }
  }
  election_id: {
    high: 1
  }
} 
INFO[0010] spine:57400
response: result: {
  id: 1
  status: FIB_PROGRAMMED
  timestamp: 1738344091821829371
} 
INFO[0010] target spine:57400 modify request:
operation: {
  id: 2
  network_instance: "default"
  op: ADD
  next_hop_group: {
    id: 1
    next_hop_group: {
      next_hop: {
        index: 1
      }
    }
  }
  election_id: {
    high: 1
  }
} 
INFO[0010] spine:57400
response: result: {
  id: 2
  status: FIB_PROGRAMMED
  timestamp: 1738344091829188505
} 
INFO[0010] target spine:57400 modify request:
operation: {
  id: 3
  network_instance: "default"
  op: ADD
  ipv4: {
    prefix: "10.10.10.2/32"
    ipv4_entry: {
      next_hop_group: {
        value: 1
      }
    }
  }
  election_id: {
    high: 1
  }
} 
INFO[0010] target spine:57400 modify stream done        
INFO[0010] spine:57400
response: result: {
  id: 3
  status: FIB_PROGRAMMED
  timestamp: 1738344091835778815
} 
</pre>
</details>

The operation is successful. Let's get the gRIBI installed route.

```
gribic -a spine:57400 -u grclient1 -p grclient1 --skip-verify get --ns default --aft ipv4
```

Expected output:

```
INFO[0000] target spine:57400: final get response: entry:{network_instance:"default" ipv4:{prefix:"10.10.10.2/32" ipv4_entry:{next_hop_group:{value:1}}} rib_status:PROGRAMMED fib_status:PROGRAMMED} 
INFO[0000] got 1 results                                
INFO[0000] "spine:57400":
entry: {
  network_instance: "default"
  ipv4: {
    prefix: "10.10.10.2/32"
    ipv4_entry: {
      next_hop_group: {
        value: 1
      }
    }
  }
  rib_status: PROGRAMMED
  fib_status: PROGRAMMED
}
```

Get the gRIBI installed next hop group:

```
gribic -a spine:57400 -u grclient1 -p grclient1 --skip-verify get --ns default --aft nhg
```

Expected output:

```
INFO[0000] target spine:57400: final get response: entry:{network_instance:"default" next_hop_group:{id:1 next_hop_group:{next_hop:{index:1}}} rib_status:PROGRAMMED fib_status:PROGRAMMED} 
INFO[0000] got 1 results                                
INFO[0000] "spine:57400":
entry: {
  network_instance: "default"
  next_hop_group: {
    id: 1
    next_hop_group: {
      next_hop: {
        index: 1
      }
    }
  }
  rib_status: PROGRAMMED
  fib_status: PROGRAMMED
}
```

Get the gRIBI installed next hop:

```
gribic -a spine:57400 -u grclient1 -p grclient1 --skip-verify get --ns default --aft nh
```

Expected output:

```
INFO[0000] target spine:57400: final get response: entry:{network_instance:"default" next_hop:{index:1 next_hop:{ip_address:{value:"192.168.20.2"}}} rib_status:PROGRAMMED fib_status:PROGRAMMED} 
INFO[0000] got 1 results                                
INFO[0000] "spine:57400":
entry: {
  network_instance: "default"
  next_hop: {
    index: 1
    next_hop: {
      ip_address: {
        value: "192.168.20.2"
      }
    }
  }
  rib_status: PROGRAMMED
  fib_status: PROGRAMMED
} 
```

Now let's verify the route table on spine and confirm that there is a route for `10.10.10.2/32` which is the loopback IP on leaf2.

```
gnmic -a spine -u admin -p admin --skip-verify get --path "/network-instance[name=default]/route-table/ipv4-unicast" --encoding=JSON_IETF --depth 2 | grep -E "prefix|active|type"
```

<details>
<summary>Expected Output</summary>
<br>
<pre>
        "active": true,
        "ipv4-prefix": "1.1.1.1/32",
        "route-type": "srl_nokia-common:bgp"
        "active": true,
        "ipv4-prefix": "2.2.2.2/32",
        "route-type": "srl_nokia-common:bgp"
        "active": true,
        "ipv4-prefix": "3.3.3.3/32",
        "route-type": "srl_nokia-common:host"
        "active": true,
        "ipv4-prefix": "10.10.10.0/24",
        "route-type": "srl_nokia-common:local"
        "active": true,
        "ipv4-prefix": "10.10.10.2/32",
        "route-type": "srl_nokia-common:gribi"
        "active": true,
        "ipv4-prefix": "10.10.10.3/32",
        "route-type": "srl_nokia-common:host"
        "active": true,
        "ipv4-prefix": "10.10.10.255/32",
        "route-type": "srl_nokia-common:host"
        "active": true,
        "ipv4-prefix": "192.168.10.2/31",
        "route-type": "srl_nokia-common:local"
        "active": true,
        "ipv4-prefix": "192.168.10.3/32",
        "route-type": "srl_nokia-common:host"
        "active": true,
        "ipv4-prefix": "192.168.20.2/31",
        "route-type": "srl_nokia-common:local"
        "active": true,
        "ipv4-prefix": "192.168.20.3/32",
        "route-type": "srl_nokia-common:host"
      "active-routes": 11,
      "active-routes-with-ecmp": 0,
</pre> 
</details>

There is an active route with `gRIBI` as the owner.

Now it's time to check if ping works.

```
gnoic -a spine -u admin -p admin --skip-verify system ping --destination 10.10.10.2 --ns default --count 1 --wait 1s
```

Expected output:

```
56 bytes from 10.10.10.2: icmp_seq=1 ttl=64 time=3.636684ms
--- 10.10.10.2 ping statistics ---
1 packets sent, 1 packets received, 0.00% packet loss
round-trip min/avg/max/stddev = 3.637/3.637/3.637/0.000 ms
```

Ping is successful.

To destroy the lab, run `sudo clab des -a`.

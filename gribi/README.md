# gRIBI Use Case

gRIBI can be used for route injection in to the FIB/RIB for real time traffic steering.

In this workshop, we will demonstrate traffic re-routing with a simple use case.

Save and then destroy existing lab:

```bash
sudo clab save
sudo clab des -a
```

Change to the `gribi` directory

```bash
cd ~/ac3-grpc/gribi
```

Deploy gRIBI lab

```bash
sudo clab dep -c
```

The new lab that will be deployed is similar to the previous lab but without any clients and an additional link between the 2 leafs.

![image](../images/gribi-topo.jpg)

Lab is deployed with all required configuration.

Check the path taken from `leaf1` to reach `2.2.2.2` on `leaf2`. Perform a traceroute using gNOI System RPC.

```bash
gnoic -a leaf1:57401 -u gnoic1 -p gnoic1 --insecure system traceroute --destination 2.2.2.2 --ns default --wait 1s
```

Expected output:

```bash
traceroute to 2.2.2.2 (2.2.2.2), 30 max hops, 56 byte packets
1 192.168.10.3 (192.168.10.3) 326.604525ms
2 2.2.2.2 (2.2.2.2) 347.010499ms
```

We can see that the next-hop from `leaf1` to reach `2.2.2.2` is via Spine. This is because the direct link between the 2 leafs is not advertised in any routing protocol.

Next, we will inject a route on `leaf1` to redirect traffic going to `2.2.2.2` to use the direct link to `leaf2`.

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
      prefix: 2.2.2.2/32
      nhg: 1
```

Before we push this route, let's verify the route table entries on `leaf1`.

We will be using gNMI to get this state information.

```
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path "/network-instance[name=default]/route-table/ipv4-unicast" --encoding=JSON_IETF --depth 2 | grep -E "prefix|active|type"
```

<details>
<summary>Expected Output</summary>
<br>
<pre>
"active": true,
"ipv4-prefix": "1.1.1.1/32",
"route-type": "srl_nokia-common:host"
"active": true,
"ipv4-prefix": "2.2.2.2/32",
"route-type": "srl_nokia-common:bgp"
"active": true,
"ipv4-prefix": "172.16.10.0/31",
"route-type": "srl_nokia-common:local"
"active": true,
"ipv4-prefix": "172.16.10.0/32",
"route-type": "srl_nokia-common:host"
"active": true,
"ipv4-prefix": "192.168.10.2/31",
"route-type": "srl_nokia-common:local"
"active": true,
"ipv4-prefix": "192.168.10.2/32",
"route-type": "srl_nokia-common:host"
"active-routes": 6,
"active-routes-with-ecmp": 0,
</pre>
</details>

If you would like to see the full output, try running the above command without the grep.

Before we push the route, let's get the current installed gRIBI routes.

```
gribic -a leaf1:57401 -u admin -p admin --insecure get --ns default --aft ipv4
```

Expected output:

```
INFO[0000] target leaf1:57401: final get response:      
INFO[0000] got 1 results                                
INFO[0000] "leaf1:57401":   
```

There are no gRIBI routes at this time.

Now, let's push the gRIBI route. The route [instructions](#L436) are saved in a file [grib-input.yml](grib-input.yml)

```
gribic -a leaf1:57401 -u admin -p admin --insecure modify --input-file grib-input.yml
```

<details>
<summary>Expected Output</summary>
<br>
<pre>
INFO[0000] trying to find variable file "grib-input_vars.yml" 
INFO[0000] sending request=params:{redundancy:SINGLE_PRIMARY persistence:PRESERVE ack_type:RIB_AND_FIB_ACK} to "leaf1:57401" 
INFO[0000] sending request=election_id:{high:1} to "leaf1:57401" 
INFO[0000] leaf1:57401
response: session_params_result: {} 
INFO[0000] target leaf1:57401 modify request:
operation: {
  id: 1
  network_instance: "default"
  op: ADD
  next_hop: {
    index: 1
    next_hop: {
      ip_address: {
        value: "172.16.10.1"
      }
    }
  }
  election_id: {
    high: 1
  }
} 
INFO[0000] leaf1:57401
response: election_id: {
  high: 1
} 
INFO[0010] target leaf1:57401 modify request:
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
INFO[0010] leaf1:57401
response: result: {
  id: 1
  status: FIB_PROGRAMMED
  timestamp: 1747763142835240782
} 
INFO[0010] target leaf1:57401 modify request:
operation: {
  id: 3
  network_instance: "default"
  op: ADD
  ipv4: {
    prefix: "2.2.2.2/32"
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
INFO[0010] leaf1:57401
response: result: {
  id: 2
  status: FIB_PROGRAMMED
  timestamp: 1747763142897447495
} 
INFO[0010] target leaf1:57401 modify stream done        
INFO[0010] leaf1:57401
response: result: {
  id: 3
  status: FIB_PROGRAMMED
  timestamp: 1747763142947521598
} 
</pre>
</details>

The operation is successful. Let's get the gRIBI installed route.

```
gribic -a leaf1:57401 -u admin -p admin --insecure get --ns default --aft ipv4
```

Expected output:

```
INFO[0000] target leaf1:57401: final get response: entry:{network_instance:"default" ipv4:{prefix:"2.2.2.2/32" ipv4_entry:{next_hop_group:{value:1}}} rib_status:PROGRAMMED fib_status:PROGRAMMED} 
INFO[0000] got 1 results                                
INFO[0000] "leaf1:57401":
entry: {
  network_instance: "default"
  ipv4: {
    prefix: "2.2.2.2/32"
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
gribic -a leaf1:57401 -u admin -p admin --insecure get --ns default --aft nhg
```

Expected output:

```
INFO[0000] target leaf1:57401: final get response: entry:{network_instance:"default" next_hop_group:{id:1 next_hop_group:{next_hop:{index:1}}} rib_status:PROGRAMMED fib_status:PROGRAMMED} 
INFO[0000] got 1 results                                
INFO[0000] "leaf1:57401":
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
gribic -a leaf1:57401 -u admin -p admin --insecure get --ns default --aft nh
```

Expected output:

```
INFO[0000] target leaf1:57401: final get response: entry:{network_instance:"default" next_hop:{index:1 next_hop:{ip_address:{value:"172.16.10.1"}}} rib_status:PROGRAMMED fib_status:PROGRAMMED} 
INFO[0000] got 1 results                                
INFO[0000] "leaf1:57401":
entry: {
  network_instance: "default"
  next_hop: {
    index: 1
    next_hop: {
      ip_address: {
        value: "172.16.10.1"
      }
    }
  }
  rib_status: PROGRAMMED
  fib_status: PROGRAMMED
} 
```

Now let's verify the route table on spine and confirm that there is a route for `10.10.10.2/32` which is the loopback IP on leaf2.

```
gnmic -a leaf1:57401 -u admin -p admin --insecure get --path "/network-instance[name=default]/route-table/ipv4-unicast" --encoding=JSON_IETF --depth 2 | grep -E "prefix|active|type"
```

<details>
<summary>Expected Output</summary>
<br>
<pre>
"active": true,
"ipv4-prefix": "1.1.1.1/32",
"route-type": "srl_nokia-common:host"
"active": true,
"ipv4-prefix": "2.2.2.2/32",
"route-type": "srl_nokia-common:gribi"
"active": true,
"ipv4-prefix": "172.16.10.0/31",
"route-type": "srl_nokia-common:local"
"active": true,
"ipv4-prefix": "172.16.10.0/32",
"route-type": "srl_nokia-common:host"
"active": true,
"ipv4-prefix": "192.168.10.2/31",
"route-type": "srl_nokia-common:local"
"active": true,
"ipv4-prefix": "192.168.10.2/32",
"route-type": "srl_nokia-common:host"
"active-routes": 6,
"active-routes-with-ecmp": 0,
</pre> 
</details>

We can see that the route for `2.2.2.2` is now owned by gRIBI.

Now it's time to check the path taken from `leaf1` to reach `2.2.2.2`. Repeat the traceroute command performed at the beginning of this activity and compare the next hops between the 2 outputs.

```
gnoic -a leaf1:57401 -u gnoic1 -p gnoic1 --insecure system traceroute --destination 2.2.2.2 --ns default --wait 1s
```

Expected output:

```
traceroute to 2.2.2.2 (2.2.2.2), 30 max hops, 56 byte packets
1 2.2.2.2 (2.2.2.2) 331.369923ms
```

We can see that `2.2.2.2` is now reachable over the direct link to `leaf2`.

Flush all gRIBI routes:

```bash
gribic -a leaf1:57401 -u admin -p admin --insecure flush --ns default --override
```

Expected output:

```bash
INFO[0000] got 1 results                                
INFO[0000] "leaf1:57401": timestamp: 1747763792059403059
result: OK 
```

To destroy the lab, run `sudo clab des -a`.

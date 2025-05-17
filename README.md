# Mastering gRPC-Based Services for Network Automation

Welcome to the workshop on *Mastering gRPC-based services for network auotmation* at Network Automation Forum's Autocon3.

This README is your starting point into the hands on section.

Pre-requisite: A laptop with SSH client

If you need help, please raise your hand and a Nokia team member will be happy to assist.

Shortcut links to major sections in this README:

| --- | --- |
| [Lab Topology]() | [Deploying the lab]() |
| [BGP Underay]() | [BGP Overlay]() |
| [Layer 2 EPVN]() | [Layer 3 EVPN]() |

## Lab Environment

A Nokia team member will provide you with a card that contains:
- your VM hostname
- SSH credentials to the VM instance
- URL of this repo

> <p style="color:red">!!! Make sure to backup any code, config, ... <u> offline (e.g on your laptop)</u>. 
> The VM instances will be destroyed once the Workshop is concluded.</p>

## Workshop
The objective of the hands on section of this workshop is the following:
- Configuring, retrieving state, streaming telemetry using gNMI
- File backup, restore and software upgrade prep using gNOI
- gRPC service authorization and certificate management using gNSI
- Traffic steering using gRIBI

## Lab Topology

Each workshop participant will be provided with the below topology consisting of 2 leaf and 1 spine nodes along with 2 clients. The Leaf-Spine architecture is typical in a Data Center environment and clients are simulating workloads or VMs.

![image](images/lab-topology.jpg)

## NOS (Network Operating System)

Both leafs and Spine nodes will be running the latest release (25.3.1) of Nokia [SR Linux](https://www.nokia.com/networks/ip-networks/service-router-linux-NOS/).

Both clients will be running a light version of [Alpine Linux](https://alpinelinux.org/).

See the [topology](ac3-grpc.clab.yml) file for more details.

## Deploying the lab

Login to the VM using the credentials on your sheet.

This Git repo is already cloned to your VM.

But in case you need it, use the below command to clone this repo to your VM.

```
git clone https://github.com/srlinuxamericas/ac3-grpc.git
```

Verify that the git repo files are now available on your VM.

```
ls -lrt ac3-grpc/
```

To deploy the lab, run the following:

```
cd ac3-grpc
sudo clab deploy -t ac3-grpc.clab.yml
```

[Containerlab](https://containerlab.dev/) will deploy the lab and display a table with the list of nodes and their IPs.

```
╭─────────┬────────────────────────────────────┬─────────┬────────────────────╮
│   Name  │             Kind/Image             │  State  │   IPv4/6 Address   │
├─────────┼────────────────────────────────────┼─────────┼────────────────────┤
│ client1 │ linux                              │ running │ 172.20.20.10       │
│         │ ghcr.io/srl-labs/network-multitool │         │ 2001:172:20:20::10 │
├─────────┼────────────────────────────────────┼─────────┼────────────────────┤
│ client3 │ linux                              │ running │ 172.20.20.12       │
│         │ ghcr.io/srl-labs/network-multitool │         │ 2001:172:20:20::12 │
├─────────┼────────────────────────────────────┼─────────┼────────────────────┤
│ leaf1   │ nokia_srlinux                      │ running │ 172.20.20.2        │
│         │ ghcr.io/nokia/srlinux:25.3.1       │         │ 2001:172:20:20::2  │
├─────────┼────────────────────────────────────┼─────────┼────────────────────┤
│ leaf2   │ nokia_srlinux                      │ running │ 172.20.20.4        │
│         │ ghcr.io/nokia/srlinux:25.3.1       │         │ 2001:172:20:20::4  │
├─────────┼────────────────────────────────────┼─────────┼────────────────────┤
│ spine   │ nokia_srlinux                      │ running │ 172.20.20.3        │
│         │ ghcr.io/nokia/srlinux:25.3.1       │         │ 2001:172:20:20::3  │
╰─────────┴────────────────────────────────────┴─────────┴────────────────────╯
```

To display all deployed labs on your VM at any time, use:

```
sudo clab inspect --all
```

### Using Codespaces

This lab can be deployed using GitHub Codespaces. Once you are logged into GitHub, click the below icon and wait for 2 minutes for codespaces to be ready. During this initialization, codespace will install containerlab and gRPC clients so that you are all set to run the use cases immediately.

---
<div align=center>
<a href="https://codespaces.new/srlinuxamericas/ac3-grpc?quickstart=1">
<img src="https://gitlab.com/rdodin/pics/-/wikis/uploads/d78a6f9f6869b3ac3c286928dd52fa08/run_in_codespaces-v1.svg?sanitize=true" style="width:50%"/></a>

**[Run](https://codespaces.new/srlinuxamericas/ac3-grpc?quickstart=1) this lab in GitHub Codespaces for free**.  
[Learn more](https://containerlab.dev/manual/codespaces/) about Containerlab for Codespaces.

</div>

---

## Connecting to the devices

Find the nodename or IP address of the device from the above output and then use SSH.

Username: `admin`

Password: Refer to the provided sheet

Note: Password less authentication is enabled by Containerlab using SSH keys.

```
ssh leaf1
```

To login to the client, identify the client hostname using the `sudo clab inspect --all` command above and then:

```
sudo docker exec –it client3 sh
```

### IPv4 Link Addressing

![image](images/lab-ipv4.jpg)

### IPv6 Link Addressing

![image](images/lab-ipv4.jpg)

### Verify reachability between devices

After the lab is deployed, check reachability between leaf and spine devices using ping.

Example on spine to Leaf1 for IPv4:

```
ping -c 3 192.168.10.2 network-instance default
```

Example on spine to Leaf1 for IPv6:

```
ping6 -c 3 192:168:10::2 network-instance default
```

## gRPC Clients

We will be using the following gRPC clients:

- [gNMIc](https://gnmic.openconfig.net/)
- [gNOIc](https://gnoic.kmrd.dev/)
- [gNSIc](https://github.com/karimra/gnsic)
- [gRIBIc](https://gribic.kmrd.dev/)

All 4 clients are installed when initializing the VM or codespace.

Verify that clients are installed on your VM:

```
gnmic version
gnoic version
gnsic version
gribic version
```

If for any reason, one of the above clients needs to be re-installed or updated, refer to the client pages referenced above.

All gnmic, gnoic, gnsic and gribic commands will be executed from the VM.

![image](lab-setup.jpg)

## Enabling gRPC services

Before we get on with the use cases, let's verify the gRPC server configuration and confirm whether all required gRPC services are enabled.

There are 2 gRPC servers created on all 3 SR Linux devices - mgmt (secure using TLS) and insecure-mgmt (not using TLS).

On either leafs or spine, run the following command to display the gRPC configuration for both servers.

```bash
info flat system grpc-server mgmt
info flat system grpc-server insecure-mgmt
```

Expected output for secure gRPC server:

```bash
set / system grpc-server mgmt admin-state enable
set / system grpc-server mgmt rate-limit 65000
set / system grpc-server mgmt tls-profile clab-profile
set / system grpc-server mgmt network-instance mgmt
set / system grpc-server mgmt trace-options [ request response common ]
set / system grpc-server mgmt services [ gnmi gnoi gnsi gribi p4rt ]
set / system grpc-server mgmt unix-socket admin-state enable
```

Expected output for insecure gRPC server:

```bash
set / system grpc-server insecure-mgmt admin-state enable
set / system grpc-server insecure-mgmt rate-limit 65000
set / system grpc-server insecure-mgmt network-instance mgmt
set / system grpc-server insecure-mgmt port 57401
set / system grpc-server insecure-mgmt trace-options [ request response common ]
set / system grpc-server insecure-mgmt services [ gnmi gnoi gnsi gribi p4rt ]
set / system grpc-server insecure-mgmt unix-socket admin-state enable
```

We can see that all 4 gRPC services for this workshop are enabled on both gRPC servers.

Secure gRPC server is listening on the default gRPC port (57400) while the insecure gRPC server is listening on port 57401.

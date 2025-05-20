# gNSI Use Cases

gNSI services and RPCs are used for securing the switch. This includes Authorization policies for gRPC service access, Certificate management and Accounting.

In this section, we will learn about some of them.

## gNSI Authz

Authz RPC can be used to configure an Authorization policy for access to gRPC services.

In the previous section on gNOI, we used a user `gnoic1` to get the configuration file backup to the host VM. Because there are no authorization policies in place, this user can also transfer files to the switch.

If an authorized 3rd party gets access to the host VM, they can use the same user to push corrupted files or images to the switch.

We will be using gNSI to configure an authorization policy on leaf1 that will prevent the user called `gnoic1` (used for config file backup) from writing files on the switch.

Let's start by verifying that the user `gnoic1` has access to list, get and put files on leaf1.

We will switch to using secure gRPC communication for this section as gNSI policies apply to secure requests only.

List file:

```
gnoic -a leaf1 -u gnoic1 -p gnoic1 --skip-verify file stat --path /etc/opt/srlinux/config.json
```

Expected output:

```bash
+-------------+------------------------------+---------------------------+------------+------------+--------+
| Target Name |             Path             |       LastModified        |    Perm    |   Umask    |  Size  |
+-------------+------------------------------+---------------------------+------------+------------+--------+
| leaf1:57400 | /etc/opt/srlinux/config.json | 2025-05-20T02:50:43-04:00 | -rw-rw-r-- | -----w--w- | 105988 |
+-------------+------------------------------+---------------------------+------------+------------+--------+
```

Get file:

```
gnoic -a leaf1 -u gnoic1 -p gnoic1 --skip-verify file get --file /etc/opt/srlinux/config.json --dst .
```

Expected output:

```bash
INFO[0000] "leaf1:57400" received 64000 bytes           
INFO[0000] "leaf1:57400" received 41988 bytes           
INFO[0000] "leaf1:57400" file "/etc/opt/srlinux/config.json" saved 
```

Put file:

Create a file on your host VM:

```bash
echo "this is a corrupted image file" > corrupt.img
```

Now transfer this file to the switch.

```
gnoic -a leaf1 -u gnoic1 -p gnoic1 --skip-verify file put --file corrupt.img --dst /var/log/srlinux/corrupt.img
```

Expected output for Put file:

```
INFO[0000] "leaf1:57400" sending file="corrupt.img" hash 
INFO[0000] "leaf1:57400" file "corrupt.img" written successfully 
```

Verify on leaf1 that the file transferred exists.

```
gnoic -a leaf1 -u gnoic1 -p gnoic1 --skip-verify file stat --path /var/log/srlinux/corrupt.img
```

Expected output:

```
+-------------+------------------------------+---------------------------+------------+------------+------+
| Target Name |             Path             |       LastModified        |    Perm    |   Umask    | Size |
+-------------+------------------------------+---------------------------+------------+------------+------+
| leaf1:57401 | /var/log/srlinux/corrupt.img | 2025-05-20T03:06:16-04:00 | -rwxrwxrwx | -----w--w- | 31   |
+-------------+------------------------------+---------------------------+------------+------------+------+
```

Delete the transferred file from the device using `File Remove` RPC.

```bash
gnoic -a leaf1 -u gnoic1 -p gnoic1 --skip-verify file remove --path /var/log/srlinux/corrupt.img
```

Expected output:

```bash
INFO[0000] "leaf1:57400" file "/var/log/srlinux/corrupt.img" removed successfully 
```

At this time, the user `gnoic1` has permissions to transfer a file over to leaf1.

Let's block that by pushing an authorization policy using gNSI Authz service.

This is the Authz policy payload that we will push. This gives access to gNOI File Get & Stat to user `gnoic1` and will deny gNOI File Put for this user.

<details>
<summary>Authz Payload</summary>
<br>
<pre>
{
  "name": "Ext-clients",
  "allow_rules": [
    {
      "name": "backup-access",
      "source": {
        "principals": [
          "gnoic1", 
		  "gnoi-clients"
		  
        ]
      },
      "request": {
        "paths": [
          "/gnoi.file.File/Get",
          "/gnoi.file.File/Stat"
        ]
      }
    }
  ],
  "deny_rules": [
    {
      "name": "backup-access",
      "source": {
        "principals": [
          "gnoic1", 
		  "gnoi-clients"
        ]
      },
      "request": {
        "paths": [
          "/gnoi.file.File/Put"
        ]
      }
    }
  ]
}
</pre>
</details>

Let's push the policy using gNSIc.

```
gnsic -a leaf1 -u admin -p admin --skip-verify authz rotate --policy "{\"name\":\"Ext-clients\",\"allow_rules\":[{\"name\":\"backup-access\",\"source\":{\"principals\":[\"gnoic1\",\"gnoi-clients\"]},\"request\":{\"paths\":[\"/gnoi.file.File/Get\",\"/gnoi.file.File/Stat\"]}}],\"deny_rules\":[{\"name\":\"backup-access\",\"source\":{\"principals\":[\"gnoic1\",\"gnoi-clients\"]},\"request\":{\"paths\":[\"/gnoi.file.File/Put\"]}}]}"
```

Expected output:

```
INFO[0000] targets: map[leaf1:57400:0xc0002c6040]       
INFO[0000] "leaf1:57400": got UploadResponse            
INFO[0001] "leaf1:57400": sending finalize request      
INFO[0001] "leaf1:57400": closing stream 
```

Verify that the authz policy was applied on the system. We will use gNMI Get RPC for this purpose.

```bash
gnmic -a leaf1 -u admin -p admin --skip-verify get --path /system/aaa/authorization/authz-policy --encoding json_ietf
```

Expected output:

```bash
[
  {
    "source": "leaf1",
    "timestamp": 1747726096665629489,
    "time": "2025-05-20T03:28:16.665629489-04:00",
    "updates": [
      {
        "Path": "srl_nokia-system:system/srl_nokia-aaa:aaa/authorization/srl_nokia-gnsi-authz:authz-policy",
        "values": {
          "srl_nokia-system:system/srl_nokia-aaa:aaa/authorization/srl_nokia-gnsi-authz:authz-policy": {
            "counters": {
              "rpc": [
                {
                  "access-accepts": "4",
                  "access-rejects": "0",
                  "last-access-accept": "2025-05-20T07:28:16.661Z",
                  "name": "/gnmi.gNMI/Get"
                },
                {
                  "access-accepts": "1",
                  "access-rejects": "0",
                  "last-access-accept": "2025-05-20T07:23:00.183Z",
                  "name": "/gnoi.file.File/Get"
                },
                {
                  "access-accepts": "0",
                  "access-rejects": "2",
                  "last-access-reject": "2025-05-20T07:23:35.004Z",
                  "name": "/gnoi.file.File/Put"
                },
                {
                  "access-accepts": "1",
                  "access-rejects": "1",
                  "last-access-accept": "2025-05-20T07:25:09.619Z",
                  "last-access-reject": "2025-05-20T07:24:36.303Z",
                  "name": "/gnoi.file.File/Remove"
                },
                {
                  "access-accepts": "7",
                  "access-rejects": "0",
                  "last-access-accept": "2025-05-20T07:25:09.538Z",
                  "name": "/gnoi.file.File/Stat"
                },
                {
                  "access-accepts": "5",
                  "access-rejects": "0",
                  "last-access-accept": "2025-05-20T07:28:13.277Z",
                  "name": "/gnsi.authz.v1.Authz/Rotate"
                }
              ]
            },
            "created-on": "2179-09-19T07:42:44.972Z",
            "policy": "{\"name\":\"Ext-clients\",\"allow_rules\":[{\"name\":\"backup-access\",\"source\":{\"principals\":[\"gnoic1\",\"gnoi-clients\"]},\"request\":{\"paths\":[\"/gnoi.file.File/Get\",\"/gnoi.file.File/Stat\"]}}],\"deny_rules\":[{\"name\":\"backup-access\",\"source\":{\"principals\":[\"gnoic1\",\"gnoi-clients\"]},\"request\":{\"paths\":[\"/gnoi.file.File/Put\"]}}]}",
            "version": ""
          }
        }
      }
    ]
  }
]
```

Note - As gNSIc client is in beta phase, it might not push the policy in the first attempt. If gNMI Get is still showing the default policy, repeat the gNSIc Authz command to push the policy again.

Now, test the list, get, put file operations again.

Refer to the steps above.

Put operation will be denied with the below output.

```
INFO[0000] "leaf1:57400" sending file="corrupt.img" hash 
ERRO[0000] "leaf1:57400" File Put failed: rpc error: code = PermissionDenied desc = User 'gnoic1' is not authorized to use rpc '/gnoi.file.File/Put' 
Error: there was 1 error(s)
```

Clear the Authz policy by logging into `leaf1` CLI and executing the following command:

```bash
tools system aaa authorization authz-policy remove
```

## TLS Certificate Management

Another use case of gNSI is to configure and manage TLS profile and certificates on the switch.

gNSI Certz RPCs are used for this purpose.

Assuming our starting point is an insecure connection, we will build a TLS profile with certificates and use it on a gRPC server to make our connection secure.

Create a new TLS profile on the router:

```bash
gnsic -a leaf1:57401 -u admin -p admin --insecure certz add-profile --id Corp-Sec-A
```

Expected output:

```bash
INFO[0000] leaf1:57401: added profile "Corp-Sec-A"
```

Verify the TLS profiles on the switch and confirm that the new profile exists on the switch.

```bash
gnsic -a leaf1:57401 -u admin -p admin --insecure certz get-profile-list
```

Expected output:

```bash
+-------------+-------------------+
| Target Name | SSL Profile ID(s) |
+-------------+-------------------+
| leaf1:57401 | Corp-Sec-A        |
|             | __default__       |
+-------------+-------------------+
```

Next, check if the switch can generate a Certificate Signing Request (CSR). If the switch can generate one, then we can avoid generating certificates outside the switch and transferring them over to the switch. Our certificate common name (CN) will be `containerlab.dev`.

```bash
gnsic -a leaf1:57401 -u admin -p admin --insecure certz can-gen-csr --cn containerlab.dev
```

Expected output:

```bash
+-------------+------------------+
| Target Name | Can Generate CSR |
+-------------+------------------+
| leaf1:57401 | true             |
+-------------+------------------+
```

We confirmed that the switch can generate a CSR.

Now we are ready to generate the CSR. Before we do that, create the CA certificate and key to sign the CSR. We will use Containerlab tools for this purpose. In a real environment, the CSR is sent to an external CA for signing.

On your host VM, run:

```bash
containerlab tools cert ca create
```

This will create 2 files - `ca.key` and `ca.pem` to sign the switch CSR.

Next we will request the switch to generate a CSR, get it signed and install it back on the switch. All this using a single command.

We will add the `leaf1` management IP into the SAN field of the certificate.

```bash
gnsic -a leaf1:57401 -u admin -p admin --insecure certz rotate --cn containerlab.dev --ca-cert ca.pem --ca-key ca.key --id Corp-Sec-A --version 2 --san-ip-address "172.20.20.2"
```

Expected output:

```bash
INFO[0001] leaf1:57401: can generate CSR                
INFO[0001] leaf1:57401: sending Generate CSR: ssl_profile_id:"Corp-Sec-A"  generate_csr:{params:{common_name:"containerlab.dev"  san:{ips:"172.20.20.2"}}} 
INFO[0002] leaf1:57401: got CSR back: generated_csr:{certificate_signing_request:{type:CERTIFICATE_TYPE_X509  encoding:CERTIFICATE_ENCODING_PEM  certificate_signing_request:"-----BEGIN CERTIFICATE REQUEST-----\nMIIEgjCCAmoCAQAwGzEZMBcGA1UEAwwQY29udGFpbmVybGFiLmRldjCCAiI
<---snip---->
INFO[0002] leaf1:57401: returned CSR:
Certificate Request:
    Data:
        Version: 0 (0x0)
        Subject: CN=containerlab.dev
        Subject Public Key Info:
<---snip---->
-----BEGIN CERTIFICATE REQUEST-----
MIIEYDCCAkgCAQAwGzEZMBcGA1UEAwwQY29udGFpbmVybGFiLmRldjCCAiIwDQYJ
<---snip---->
-----END CERTIFICATE REQUEST----- 
INFO[0002] read local CA certs                          
INFO[0002] leaf1:57401: sending upload request: ssl_profile_id:"Corp-Sec-A"  certificates:{entities:{version:"1"  created_on:1747727317  certificate_chain:{certificate:{type:CERTIFICATE_TYPE_X509  encoding:CERTIFICATE_ENCODING_PEM  certificate:"-----BEGIN CERTIFICATE-----\nMIIEpjCCA46gAwIBAgIRAMXIQyDtYj9sbAqDDjSS7qYwDQYJKoZIhvcNAQELBQAw\nczERMA8GA1UEBhMISW50
<---snip---->
lmmMG9Mo13AQ/1lmQV+oMfAo\n-----END CERTIFICATE-----\n"}}}} 
INFO[0002] leaf1:57401: upload Response certificates:{} 
```

The above output is shortened to show only the relevant parts. We can see the CSR that is generated by the switch, the signed certificate and a confirmation that the certificate was successfully installed on the switch.

Verify that the new TLS profile is configured with these signed certificates. We will use gNMI Get RPC for this purpose.

```bash
gnmic -a leaf1 -u admin -p admin --skip-verify get --path /system/tls/server-profile[name=Corp-Sec-A] --encoding json_ietf
```

Expected output:

```bash
[
  {
    "source": "leaf1",
    "timestamp": 1747727524779497602,
    "time": "2025-05-20T03:52:04.779497602-04:00",
    "updates": [
      {
        "Path": "srl_nokia-system:system/srl_nokia-tls:tls/server-profile[name=Corp-Sec-A]",
        "values": {
          "srl_nokia-system:system/srl_nokia-tls:tls/server-profile": {
            "authenticate-client": false,
            "certificate": "-----BEGIN CERTIFICATE-----\nMIIEpjCCA46gAwIBAgIRAMXIQyDtYj9sb
<---snip---->
3AQ/1lmQV+oMfAo\n-----END CERTIFICATE-----\n",
            "cipher-list": [
              "srl_nokia-tls:ecdhe-ecdsa-aes256-gcm-sha384",
              "srl_nokia-tls:ecdhe-ecdsa-aes128-gcm-sha256",
              "srl_nokia-tls:ecdhe-rsa-aes256-gcm-sha384",
              "srl_nokia-tls:ecdhe-rsa-aes128-gcm-sha256"
            ],
            "dynamic": true,
            "key": "$aes1$AW4vXNfViwpbiG8=$QW4WuZ3iG5rTowIuCBjwSv7bQxSZm8YV78r3tZEi5nqVBh8
<---snip---->
ho3M8EdNOJ1wRaTVfAgktpzKwV38eev7Skg==",
            "srl_nokia-gnsi-certz:certz": {
              "certificate": {
                "created-on": "2025-05-20T07:48:37.000Z",
                "version": "1"
              },
              "ssl-profile-id": "Corp-Sec-A"
            }
          }
        }
      }
    ]
  }
]
```

The new TLS profile is now ready to be used. Let's update the secure gRPC server `mgmt` TLS profile to the new profle.

We will use gNMI Set RPC for this purpose.

```bash
gnmic -a leaf1:57401 -u admin -p admin --insecure set --update-path /system/grpc-server[name=mgmt]/tls-profile --update-value Corp-Sec-A
```

Expected output:

```bash
{
  "source": "leaf1:57401",
  "timestamp": 1747727840174349515,
  "time": "2025-05-20T03:57:20.174349515-04:00",
  "results": [
    {
      "operation": "UPDATE",
      "path": "system/grpc-server[name=mgmt]/tls-profile"
    }
  ]
}
```

To verify that the new TLS profile is working, let's get the Management port statistics using gNMI Get RPC and a secure TLS connection. Because the SAN field had the IP address, we will use the `leaf1` IP as the destination.

```bash
gnmic -a 172.20.20.2 -u admin -p admin --tls-ca ca.pem  get --path /interface[name=mgmt0]/statistics --encoding json_ietf
```

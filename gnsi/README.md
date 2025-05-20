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

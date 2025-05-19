# gNSI Use Case

We will be using gNSI to configure an authorization policy on leaf1 that will prevent the user called `client1` (used for config file backup) from writing files on the switch.

## Testing gNOI List, Get and Put

Let's start by verifying that the user `client1` has access to list, get and put files on leaf1.

List file:

```
gnoic -a leaf1 -u client1 -p client1 --skip-verify file stat --path /etc/opt/srlinux/config.json
```

Expected output:

Get file:

```
gnoic -a leaf1 -u client1 -p client1 --skip-verify file get --file /etc/opt/srlinux/config.json --dst .
```

Expected output:

Put file:

```
gnoic -a leaf1 -u client1 -p client1 --skip-verify file put --file configs/spine-gnmi-config.json --dst /var/log/srlinux/spine-gnmi-config.json
```

Expected output for Put file:

```
INFO[0000] "leaf1:57400" sending file="configs/spine-gnmi-config.json" hash 
INFO[0000] "leaf1:57400" file "configs/spine-gnmi-config.json" written successfully 
```

Verify on leaf1 that the file transferred exists.

```
gnoic -a leaf1 -u client1 -p client1 --skip-verify file stat --path /var/log/srlinux/spine-gnmi-config.json
```

Expected output:

```
+-------------+-----------------------------------------+---------------------------+------------+------------+------+
| Target Name |                  Path                   |       LastModified        |    Perm    |   Umask    | Size |
+-------------+-----------------------------------------+---------------------------+------------+------------+------+
| leaf1:57400 | /var/log/srlinux/spine-gnmi-config.json | 2025-01-31T17:51:39+02:00 | -rwxrwxrwx | -----w--w- | 5949 |
+-------------+-----------------------------------------+---------------------------+------------+------------+------+
```

At this time, the user `client1` has permissions to transfer a file over to leaf1.

## gNSI Authz

Let's block that by pushing an authorization policy using gNSI Authz service.

This is the Authz policy payload that we will push. This gives access to gNOI File Get & Set to user `client1` and will deny gNOI File Put for this user.

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
          "client1"
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
          "client1"
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
gnsic -a leaf1 -u admin -p admin --skip-verify authz rotate --policy "{\"name\":\"Ext-clients\",\"allow_rules\":[{\"name\":\"backup-access\",\"source\":{\"principals\":[\"client1\"]},\"request\":{\"paths\":[\"/gnoi.file.File/Get\",\"/gnoi.file.File/Stat\"]}}],\"deny_rules\":[{\"name\":\"backup-access\",\"source\":{\"principals\":[\"client1\"]},\"request\":{\"paths\":[\"/gnoi.file.File/Put\"]}}]}"
```

Expected output:

```
INFO[0000] targets: map[leaf1:57400:0xc000456260]       
INFO[0000] "leaf1:57400": got UploadResponse            
INFO[0001] "leaf1:57400": sending finalize request      
INFO[0001] "leaf1:57400": closing stream  
```

Now, test the list, get, put file operations again.

Refer to the steps [above](#testing-gnoi-list-get-and-put).

Put operation will be denied with the below output.

```
INFO[0000] "leaf1:57400" sending file="configs/spine-gnmi-config.json" hash 
ERRO[0000] "leaf1:57400" File Put failed: rpc error: code = PermissionDenied desc = User 'client1' is not authorized to use rpc '/gnoi.file.File/Put' 
Error: there was 1 error(s)
```

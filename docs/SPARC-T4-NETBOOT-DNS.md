# SPARC T4 Netboot Configuration (dns)

## Scope
Working network boot configuration for OpenIndiana SPARC text installer on T4 using:
- DHCP: ISC dhcpd on `dns`
- TFTP: `/tftpboot` on `dns`
- NFS export: `/data/oi_sparc/Solaris_11` on `dns`

Validated on May 20, 2026.

## Host Facts
- Netboot server host: `dns`
- Netboot server IP: `10.0.0.4`
- T4 MAC: `00:10:e0:3d:a0:40`
- T4 fixed IP: `10.0.0.51`

## Required Files
TFTP root (`/tftpboot`):
- `inetboot.sun4v`

NFS tree (`/data/oi_sparc/Solaris_11`) must include at top level:
- `solaris.zlib`
- `solarismisc.zlib`

## DHCP Configuration
File: `/opt/local/etc/dhcp/dhcpd.conf`

Key global settings:
- `next-server 10.0.0.4;`
- `filename "inetboot.sun4v";`
- `option root-path "10.0.0.4:/data/oi_sparc/Solaris_11";`

SUNW options in use:
- `SUNW.SrootIP4 10.0.0.4`
- `SUNW.SrootNM "10.0.0.4"`
- `SUNW.SrootPTH "/data/oi_sparc/Solaris_11"`
- `SUNW.SinstIP4 10.0.0.4`
- `SUNW.SinstPTH "/data/oi_sparc/Solaris_11"`

Host stanza:

```conf
host sparc-t4 {
  hardware ethernet 00:10:e0:3d:a0:40;
  fixed-address 10.0.0.51;
  next-server 10.0.0.4;
  filename "inetboot.sun4v";
  vendor-option-space SUNW;
  option SUNW.SrootIP4 10.0.0.4;
  option SUNW.SrootNM  "10.0.0.4";
  option SUNW.SrootPTH "/data/oi_sparc/Solaris_11";
  option SUNW.SrootOpt "rsize=8192";
  option SUNW.SbootRS  8192;
  option SUNW.SinstIP4 10.0.0.4;
  option SUNW.SinstPTH "/data/oi_sparc/Solaris_11";
}
```

## NFS Export
Command used:

```sh
share -F nfs -o ro,anon=0,sec=sys /data/oi_sparc/Solaris_11
```

Verify:

```sh
showmount -e 10.0.0.4
```

Expected:
- `/data/oi_sparc/Solaris_11 (everyone)`

## Service State
Expected online services on `dns`:
- `svc:/pkgsrc/isc-dhcpd:default`
- `svc:/network/tftp-hpa:default`
- `svc:/network/nfs/server:default`

## Known Good Boot Path
1. OBP boot uses `net:dhcp`.
2. DHCP provides `next-server` + `inetboot.sun4v`.
3. TFTP fully transfers `inetboot.sun4v`.
4. Client mounts NFS path `/data/oi_sparc/Solaris_11`.
5. Installer accesses `/solaris.zlib` and `/solarismisc.zlib` from mounted media.

## Failure Signatures and Meaning
- `TFTP server not specified`: DHCP reply missing `next-server`/siaddr for client context.
- `panic - boot: Could not mount filesystem`: typically NFS export/mount permissions or wrong root path.
- Packet trace `MOUNT1 R Mount Permission denied`: export ACL/options mismatch.
- `lofiadm of /usr FAILED!` with `cp: cannot access /solaris.zlib`: media-fs-root path derivation failed or mounted source missing expected zlib files.
- `ERROR: ... Fast Data Access MMU Miss` when direct `sparc.miniroot`: avoid direct miniroot path on this T4 flow; use `inetboot.sun4v` + NFS tree.

## Operational Notes
- `/tmp` on `dns` is tmpfs-backed and small. Long packet captures can fill it and break edits/tests.
- Remove stale capture files before repeated debugging:

```sh
rm -f /tmp/t4-*.cap /tmp/t4-*.out /tmp/*snoop*.out
```

## Quick Verification Commands
```sh
svcs -xv isc-dhcpd tftp-hpa nfs/server
/opt/local/sbin/dhcpd -t -cf /opt/local/etc/dhcp/dhcpd.conf
share
showmount -e 10.0.0.4
ls -lh /tftpboot/inetboot.sun4v
ls -lh /data/oi_sparc/Solaris_11/solaris.zlib /data/oi_sparc/Solaris_11/solarismisc.zlib
```

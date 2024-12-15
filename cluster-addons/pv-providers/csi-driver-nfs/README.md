# Configure QNAP

To be able to use the QNAP as NFS server, it has to be configured.

1. Enable NFS service under Control panel -> 
   Network and file services -> 
   Win/Mac/NFS/WebDAV -> 
   NFS.
   Enable NFSv2/NFSv3, NFS4 and NFS4.1
2. Enable under Control panel -> 
   Shared folders -> 
   On the shared folder `kube-volumes`, edit rights ->
   Choose type of rights = NFS host access -> 
   Add network for your hosts (192.168.60.0/24) with read/write access and all squash alternatives
3. Make sure the shared folder has free write rights, for example 777.

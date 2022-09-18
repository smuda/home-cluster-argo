# OKD-config
This helm chart contains configuration of OKD itself, such as configuration of machine config pools.

It uses the patch operator to change existing configuration of OKD, which obviously need
rights. Those rights are added to the cluster role
# Running in kind

## Pre-loadimg images

Create the list of images to pre-load.
```
oc get pod -A -o json \
  | jq -r '.items[].spec.containers[].image' \
  | uniq \
  | sort \
  | grep -v registry.k8s.io \
  | grep -v docker.io/kindest \
  > ./hack/preload.txt
```


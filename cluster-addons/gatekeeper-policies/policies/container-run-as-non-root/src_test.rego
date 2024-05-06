package container_warn_run_as_non_root

# "not violation" doesn't work because deny is a set.
# Instead we need to define "no_violations" to be true when `deny` is empty.
empty(value) {
  count(value) == 0
}

no_violations {
  empty(deny)
}

test_root_not_set {
  cfg := {
    "apiVersion": "apps/v1",
    "kind": "Deployment",
    "metadata": {
      "name": "gurka"
    },
    "spec":{
      "template":{
        "spec":{
          "containers":[
            {
              "name": "c1",
              "image": "docker.io/redis"
            }
          ]
        }
      }
    }
  }

  warn["Deployment/gurka/c1: Containers must not run as root"] with input as cfg
}

test_root_set_false {
  cfg := {
    "apiVersion": "apps/v1",
    "kind": "Deployment",
    "metadata": {
      "name": "gurka"
    },
    "spec":{
      "template":{
        "spec":{
          "securityContext": {
            "runAsNonRoot": false
          },
          "containers":[
            {
              "name": "c1",
              "image": "docker.io/redis"
            }
          ]
        }
      }
    }
  }

  warn["TBD"] with input as cfg
}

test_root_set_true {
  cfg := {
    "apiVersion": "apps/v1",
    "kind": "Deployment",
    "metadata": {
      "name": "gurka"
    },
    "spec":{
      "template":{
        "spec":{
          "securityContext": {
            "runAsNonRoot": true
          },
          "containers":[
            {
              "name": "c1",
              "image": "docker.io/redis"
            }
          ]
        }
      }
    }
  }

  no_violations with input as cfg
}

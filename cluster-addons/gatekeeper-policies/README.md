# OPA Policies

The idea here is to use the same policies in CI as in Gatekeeper. Unfortunatly,
the format of the rego policies in OPA and conftest are a wee bit different,
which means they need to be migrated back and forth.

For this I use the tool [konstraint](https://github.com/plexsystems/konstraint/) so
the workflow is the following:

1. Develop the rego rules with conftest under ./policies
2. Convert using konstraint with `make policies`

# 0011. Autosign agent certificates that carry a shared secret

- **Status:** Accepted
- **Date:** 2026-10-19
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** `140f5b0`, `9e17701`

## Context

Every new ASG node sends a certificate signing request to the master. Nodes appear at any time, including during scale-out at night, so signing by hand does not work. Signing everything would let any machine that reaches port 8140 enrol.

## Decision

Policy-based autosigning: each node puts a shared secret in its CSR as the `challengePassword` attribute (`csr_attributes.yaml`), and the master's autosign script accepts only CSRs carrying it. Where the secret is stored changed later: first a Terraform variable ([0012](0012-autosign-secret-as-terraform-variable.md)), now SSM ([0020](0020-autosign-secret-in-ssm-via-bootstrap.md)).

## Considered options

- **Shared secret in the CSR**: works with any number of nodes and limits enrolment to nodes launched from this template.
- **Manual signing**: does not scale with an ASG.
- **Naive autosign (`autosign = true`)**: anyone who can reach port 8140 is signed.

## Consequences

### Good

- Nodes enrol with no human step.

### Bad

- Anyone who obtains the secret, for example from a compromised node, and can reach port 8140 can enrol a machine. Checking that the certname is a real instance of the ASG is planned in [TODO.md](../TODO.md).

## Links

- [ARCHITECTURE.md](../ARCHITECTURE.md) (security notes), [DEPLOYMENT.md](../DEPLOYMENT.md) (autosign secret)

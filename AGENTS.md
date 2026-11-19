# Agent instructions: Vendy builder

- Read the shared rules in `../vendy/AGENTS.md` and the image and SSH contracts in
  `../vendy/CONTRACTS.md`. Update the platform definitions and shared docs when the supported image
  matrix or guest contract changes. Keep human setup and verification steps in `README.md`.
- Treat changes to Packer, Ansible, the matrix, requirements, or the bake workflow as potential
  automatic bakes on `main`. Check the POC maintenance gate before publishing such changes.
- Bake only the CA public key. Keep user-selected packages in the platform's fry stages. Preserve
  image provenance, CA fingerprint and ownership tags; never delete resources by name alone.
- Run full `packer validate` and exercise all changed in-guest steps on an authorized disposable
  guest of the same OS/cloud before dispatching a bake. Syntax-only checks are not a substitute.
  Keep waits bounded and surface the real failure. No new unit-test scaffolding.
- Do not dispatch or prune images for docs changes. `./poc up --images-only` is a mutating bake and
  cleanup command, not a test command.

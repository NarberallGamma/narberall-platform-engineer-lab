# SSH pubkeys for guest init

`authorized_keys` is read by `guest_init.tf` and written to `ubuntu` plus extra users.

Private keys stay off git. Production keys stay in the private tree.

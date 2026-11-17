# Sirius: the Sunshine Nix profile and the default profile are on the PATH
for d in /nix/var/nix/profiles/sunshine/bin "$HOME/.nix-profile/bin"; do [ -d "$d" ] && case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH";; esac; done
export PATH

{pkgs ? import <nixpkgs> {}}: let
  rev = "ee355d50a38e489e722fcbc7a7e6e45f7c74ce95";
  pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
    sha256 = "18wixs4xvnsnfsj48d29ryvvh2jdqadqnnd05kvjkqdmgmllqbky";
  }) {};

  postgresql = pinned.postgresql_11;
in
  pkgs.mkShell {
    nativeBuildInputs = [postgresql];
  }


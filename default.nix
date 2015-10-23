{ system ? builtins.currentSystem }:
let
  nixpkgs = import <nixpkgs> { inherit system; };
  typhon = nixpkgs.callPackage ~/typhon/default.nix {};
  jobs = with nixpkgs; {
    airbrus = callPackage ./airbrus.nix {
      typhonVm = typhon.typhonVm;
      mast = typhon.mast;
    };
  };
in
  jobs

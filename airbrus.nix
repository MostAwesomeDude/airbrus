{stdenv, lib, typhonVm, mast}:

stdenv.mkDerivation {
    name = "airbrus";
    buildInputs = [ typhonVm mast ];
    buildPhase = ''
      ${typhonVm}/mt-typhon -l ${mast}/mast ${mast}/mast/montec -mix $src/airbrus.mt airbrus.ty
      '';
    installPhase = ''
      mkdir -p $out/bin
      cp airbrus.ty $out/
      echo "${typhonVm}/mt-typhon -l ${mast}/mast $out/airbrus" > $out/bin/airbrus
      chmod +x $out/bin/airbrus
      '';
    doCheck = false;
    # Cargo-culted.
    src = builtins.filterSource (path: type: baseNameOf path == "airbrus.mt") ./.;
}

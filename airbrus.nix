{stdenv, lib, typhonVm, mast}:

stdenv.mkDerivation {
    name = "airbrus";
    buildInputs = [ typhonVm mast ];
    buildPhase = ''
      ${typhonVm}/mt-typhon -l ${mast}/mast ${mast}/mast/montec -mix -format mast $src/airbrus.mt airbrus.mast
      '';
    installPhase = ''
      mkdir -p $out/bin
      cp airbrus.mast $out/
      echo "${typhonVm}/mt-typhon -l ${mast}/mast -l ${out}  ${mast}/loader airbrus \"\$@\"" > $out/bin/airbrus
      chmod +x $out/bin/airbrus
      '';
    doCheck = false;
    # Cargo-culted.
    src = builtins.filterSource (path: type: baseNameOf path == "airbrus.mt") ./.;
}

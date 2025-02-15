{
  description = "A simple flake template";

  inputs.zig.url = "github:mitchellh/zig-overlay";
  inputs.zig.inputs.nixpkgs.follows = "nixpkgs";
  inputs.zls.url = "github:zigtools/zls";
  inputs.zls.inputs.zig-overlay.follows = "zig";
  inputs.zls.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, zig, zls, ... }:

    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      zigpkg = zig.packages.x86_64-linux.master;
      zlspkg = zls.packages.x86_64-linux.zls;
      buildInputs = [ zigpkg zlspkg ] ++ (with pkgs; [ qemu_full llvm ]);
    in {
      devShells.${system}.default = pkgs.mkShell {
          inherit buildInputs;
      };

      formatter.${system} = pkgs.nixfmt;
    };
}

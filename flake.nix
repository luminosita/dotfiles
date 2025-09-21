{
  description = "Shell using nixpkgs-unstable with external overlay";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-darwin"; # adjust to your system (e.g., x86_64-linux)
      
      devshellOverlay = import "${toString (builtins.getEnv "HOME")}/.config/nixpkgs/overlays/devshell.nix";

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ devshellOverlay ];
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          gum
          stow
        ];

        shellHook = ''
          export SHELL=/bin/zsh
          exec /bin/zsh
        '';
      };
    };
}

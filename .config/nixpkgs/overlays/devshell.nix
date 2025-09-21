self: super: {
  mkShell = args: super.mkShell (args // {
      buildInputs = (args.buildInputs or []) ++ [
        super.gh
        super.kubectl
        super.kubecolor
        super.starship
        super.bat
        super.zoxide
        super.fzf
        super.eza
        super.zellij
        super.yq
        super.fabric-ai
    ];
  });
}
curl -sL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.tar.xz | tar -xvf - -C ~/Library/Fonts

# https://github.com/zdharma-continuum/zinit?tab=readme-ov-file#install
bash -c "$(curl --fail --show-error --silent \
    --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"

# https://www.jetify.com/devbox/docs/installing_devbox/
curl -fsSL https://get.jetify.com/devbox | bash

# https://www.kcl-lang.io/docs/user_docs/getting-started/install#homebrew-macos-1
#curl -fsSL https://kcl-lang.io/script/install-kcl-lsp.sh | /bin/bash

# https://github.com/hidetatz/kubecolor
#devbox global add kubecolor

# https://github.com/sharkdp/bat
#devbox global add bat
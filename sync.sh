# gcloud auth login

# teller env >.config/fabric/.env

refresh-global

rm ~/.zshrc

stow .

echo "## Follow the instructions at https://github.com/tonsky/FiraCode/wiki/VS-Code-Instructions to enable Fira Code in VS Code" \
    | gum format

echo '## Execute `source ~/.zshrc`.' | gum format

bw login

chmod +x shh.sh
./shh.sh -o .config/fabric/.env'

rm ~/.zshrc

stow .

ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa.luminosita -N ""

cd ~/dotfiles

git remote remove origin
git remote add origin git@gh-luminosita:luminosita/dotfiles.git

git config --global user.email "milosh@emisia.net"
git config --global user.name "Milos Milosavljevic"

echo "## Follow the instructions at https://github.com/tonsky/FiraCode/wiki/VS-Code-Instructions to enable Fira Code in VS Code" \
    | gum format

echo '## Execute `source ~/.zshrc`.' | gum format


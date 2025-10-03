## BUGs:
- [X] "command not found" when opening fresh iTerm window
- [X] test symlinks on macOS
- [X] test local nix PATH
- [X] test bat PATH
- [X] LOCALE errors on Linux
- [X] podman in starship line in shell
- [X] test kubecolor linux hack

## TODO:
- [ ] zellij on Linux (bash <(curl -L https://zellij.dev/launch))
- [ ] Floccus via Git (browser bookmark sync)

## Shell:
- [ ] torsocks

## GCloud + SHH

```sh          
echo "Logging in to GCloud..."
gcloud auth login

#Pull secrets for Fabric AI
chmod +x ./lib/shh.sh
./lib/shh.sh -o .env && if [ -f ".env" ] && [ -s ".env" ]; then export $(grep -v '^#' .env | xargs) && rm .env; fi

pbpaste | fabric --pattern summarize
```


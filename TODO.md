## ISSUES:

## TASKS:
- [ ] zellij on Linux (https://zellij.dev/, bash <(curl -L https://zellij.dev/launch))
- [ ] Floccus via Git (browser bookmark sync, use GitHub personal access token for password)
- [ ] torsocks (alternative is thru external router)
- [ ] Vault

- [ ] GCloud + SHH in nixd
```sh          
echo "Logging in to GCloud..."
gcloud auth login

#Pull secrets for Fabric AI
chmod +x ./lib/shh.sh
./lib/shh.sh -o .env && if [ -f ".env" ] && [ -s ".env" ]; then export $(grep -v '^#' .env | xargs) && rm .env; fi

pbpaste | fabric --pattern summarize
```


# Master Your New Laptop Setup: Tools, Configs, and Secrets!

## Setup

```sh
cd ~/

git clone https://github.com/luminosita/dotfiles.git

cd dotfiles

git pull

git fetch

git checkout dotfiles

chmod +x install.sh install-dev.sh install-optional.sh sync.sh
```

> [!IMPORTANT]
> The commands that follow will copy a few dot files that you might have in your home directory. After the demo you should be able to restore them if you’d like to go back to the initial state.

> [!TIP]
> If one of the commands that follow throw an error, it’s most likely because you do not have the corresponding dot file in your home directory. That’s fine. Just ignore the error and move to the next command.

```sh
mv ~/.zshrc ~/.zshrc-orig

mv ~/.config/starship.toml ~/.config/starship.toml-orig

mv ~/.config/fabric ~/.config/fabric-orig
```

Execute the install script.

```sh
./install.sh
./install-dev.sh
```

```sh
nix develop --impure
```

Now that we have the tools, both those installed globally and those we need in relataion to the repo we’re working on, we can, finally, take a look at the script that does that.

```sh
./sync.sh
```

Stow created the symbolic links so now _.zshrc_ from this repo is available through the link in the home directory (`~/.zshrc`) as well and we can, for example, `source` it.

```sh
source ~/.zshrc
```

The output is as follows.

```
dotfiles [📝] via ❄️  impure
➜ 
```

> Exit nix shell. Close the terminal session. Start a new terminal session.

The output is as follows.

```
~/code
➜
```

We can see that the prompt is just as it should be and the tools are configured properly. To demonstrate that, we can use Zoxide which is a replacement of _cd_ command that allows us to navigate directories more easily. So, if we type `cd dot` and press `tab`, we’ll be taken to the `dotfiles` directory automatically.

```sh
cd dot 
```

> Ensure that there is `space` at the end of the previous command and press the `tab` key to go directly to the `dotfiles` using `zoxide`.

The output is as follows.

```sh
dotfiles 
➜ 
```

## Optional Applications

```sh
chmod +x install-optional.sh
./install-optional.sh
```

## Fabric

Run Setup and configure all the required components.

For Custom Patterns use `~/.config/fabric/patterns` path. Default values for the rest of required options.

```sh
fabric --setup
```

## Browser Extensions

floccus bookmarks sync (floccus.org)
Webpage to Markdown (chr0mekitdev)
Dark Reader (darkreader.org)
Medium Unlock (code4you.net)

AI Grammar Checker & Paraphraser – LanguageTool (languagetool.org)
Grammarly: AI Writing Assistant and Grammar Checker App (grammarly.com)
Google Translate (Google)

Save my Chatbot - AI Conversation Exporter (hugocollin.com)
AI Exporter: Save ChatGPT to PDF/MD/Notion.Supports Gemini,Deepseek,Claude (saveai.net)

Markdown Viewer (simov.github.io)

## Destroy

> Run nixd (alias) from ~/dotfiles folder

```sh
./uninstall.sh
```

> Ignore errors in the commands that follow.

```sh
mv ~/.zshrc-orig ~/.zshrc

mv ~/.config/starship.toml-orig ~/.config/starship.toml

mv ~/.config/fabric-orig ~/.config/fabric
```
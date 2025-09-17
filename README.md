# Master Your New Laptop Setup: Tools, Configs, and Secrets!

## Setup

```sh
cd ~/

git clone https://github.com/luminosita/dotfiles.git

cd dotfiles

git pull

git fetch

git checkout dotfiles

chmod +x install.sh
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
```

The output is as follows (truncated for brevity).

```
...
Downloading and Installing
✓ Downloading devbox binary... [DONE]
→ Installing in /usr/local/bin/devbox (requires sudo)...
✓ Installing in /usr/local/bin/devbox... [DONE]
✓ Successfully installed devbox 🚀

Next Steps
  1. Learn how to use devbox
     Run devbox help or read the docs at https://github.com/jetify-com/devbox
  2. Get help and give feedback
     Join our community at https://discord.gg/jetify
```

A few moments later…

Everything was installed, and that was the boring part that you already know how to do. The only important thing to note is that when I say “everything is installed”, I am lying. I’m a lying liar that lies. The truth is that only global apps or, to be more precise, global CLIs were installed. There aren’t many of them, simply because most of the tools I need are project-specific, including the project to configure everything. Those project specific tools will be installed through Devbox.


```sh
devbox shell
```

Now that we have the tools, both those installed globally and those we need in relataion to the repo we’re working on, we can, finally, take a look at the script that does that.

```sh
chmod +x sync.sh

./sync.sh
```

The output is as follows.

```
Your browser has been opened to visit:

    https://accounts.google.com/o/oauth2/auth?response_type=code&client_id=32555940559.apps.googleusercontent.com&redirect_uri=http%3A%2F%2Flocalhost%3A8085%2F&scope=openid+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fuserinfo.email+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcloud-platform+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fappengine.admin+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fsqlservice.login+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcompute+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Faccounts.reauth&state=1ytC82p0kSBpyBt3jGPjEFqsm7tjXg&access_type=offline&code_challenge=Kl3lqOMWJqHWIBoTVFp3AEZXdXN_Fi7OgsrxEAFk9Q8&code_challenge_method=S256


You are now logged in as [...].
Your current project is [dot-20210822142533].  You can change this setting by running:
  $ gcloud config set project PROJECT_ID
  ▌ Follow the instructions at https://github.com/tonsky/FiraCode/wiki/VS-Code-Instructions to enable Fira Code in VS Code
  ▌ Execute  source ~/.zshrc .
```

Stow created the symbolic links so now _.zshrc_ from this repo is available through the link in the home directory (`~/.zshrc`) as well and we can, for example, `source` it.

```sh
source ~/.zshrc
```

The output is as follows.

```
dotfiles [📝] via ❄️  devbox
➜ 
```

> Exit devbox shell. Close the terminal session. Start a new terminal session.

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

> Enter devbox shell from ~/dotfiles folder

```sh
./uninstall.sh
```

> Ignore errors in the commands that follow.

```sh
mv ~/.zshrc-orig ~/.zshrc

mv ~/.config/starship.toml-orig ~/.config/starship.toml

mv ~/.config/fabric-orig ~/.config/fabric
```
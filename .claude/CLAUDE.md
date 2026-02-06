# File Organization
```
.
├── config
│   ├── general
│   │   └── starship.toml
│   ├── karabiner
│   ├── kitty
│   ├── nvim
│   ├── tmux
│   ├── claude (global, this is not you currently.)
│   └── zsh
│       ├── aliases
│       │   ├── alias-tips.zsh
│       │   └── general.zsh
│       ├── lib
│       │   ├── completion.zsh
│       │   ├── cursor.zsh
│       │   ├── expansions.zsh
│       │   └── history.zsh
│       ├── setup-antigen.zsh
│       └── setup-antigen.zsh.zwc
├── install.sh # This is an installation entrypoint that is called by RUNME.sh
├── lib
├── README.md
├── RUNME.sh # This is called through curl and ensures host system has prerequisites before install.sh
├── scripts
│   ├── installs
│   │   ├── Brewfile
│   │   └── prerequisites.sh
│   └── macos
│       ├── install.sh
│       └── macos-dock.sh
├── symlinks.yaml
└── userChrome.css

26 directories, 58 files
```

# Installation Method
- Explained in ./README.md

# Where we are going.
I still use this for MacOS laptop. I've underspecified it on the linux side cause im planning to migrate from ubuntu to arch anyways.



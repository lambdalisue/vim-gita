Contributing
===============================================================================
Please read the rules listed below before contributing to the plugin.


Reporting an issue
-------------------------------------------------------------------------------
I'm welcome to hear issues to improve the quality, but please read the followings to save time of yours and mines ;-)

- Create a minimal vimrc explained the bottom of this document
- Create a minimal procedure to reproduce the issue from Vim starting
- Fill issue templates


Correcting documents
-------------------------------------------------------------------------------
**YOU ARE VERY WELCOME !!!**

While I'm not a native English speaker, I will be happy if you correct the documents ;-)


Fixing issues or improve behaviors
-------------------------------------------------------------------------------
vim-gita is currently in a beta release so API has not settled yet, mean that your changes will be lost in the future.
If you understand that and still want to contribute, please follow the coding rules below:

- No fold comments are acceptable (e.g. `" {{{` block)
    - Use `set foldmethod=syntax` instead
- No harmonic codes are acceptable
    - Create a harmonic plugin to glue plugins (e.g. Create a vim-gita-unite which provides unite sources of vim-gita)
    - Exception: [vim-jp/vital.vim](https://github.com/vim-jp/vital.vim) modules which is bundled in `autoload/vital.vim` directory
- Names should be snake case (e.g. `gita#define_variables`)
    - Exception: names of autocmd should be camel case (e.g. `GitaStatusModifiedPre`)
- Any files in `autoload/vital` should not be modified
    - Contribute to [vim-jp/vital.vim](https://github.com/vim-jp/vital.vim) directly

Then PR to `develop` branch which stands for preparing a next release.


Minimal vimrc
-------------------------------------------------------------------------------
While Vim has a lot of options and everyone use different configurations, a minimal vimrc to reproduce an issue is required to make debugging possible.
A minimal vimrc should:

- Reproduce the issue by using it (Start Vim with `vim -u {minimal vimrc}`)
- Be built from a template below, not from your vimrc
- Not have lines which does not contribute to the issue (except for comment lines)
- Not use any plugin managers unless the issue is a combination issue (e.g. A lazy loading by dein.vim cause the issue)
- Not include any other plugins unless the issue is a combination issue (e.g. With lightline.vim cause the issue)

You can use your minimal vimrc (say, `~/.vimrc.min`) by using `-u {scriptfile}` option like:

```
$ vim -u ~/.vimrc.min
```

Then confirm if the issue could be reproduced by the minimal vimrc.
You should create a minimal procedure from Vim starting to reproduce the issue as well.

### Template of a minimal vimrc
Use the following template to create your minimal vimrc

#### Without plugin managers
```vim
if has('vim_starting')
  set nocompatible
  " Add vim-gita repository to the runtimepath
  set runtimepath+=~/.vim/bundle/vim-gita
endif

```

#### With a plugin manager (dein.vim)
```vim
if has('vim_starting')
  set nocompatible
  set runtimepath+=~/.vim/bundle/dein.vim
endif

call dein#begin(expand('~/.vim/bundle'))
call dein#add('lambdalisue/vim-gita')
"call dein#add('lambdalisue/vim-gita', { 'lazy': 1 })
call dein#end()
filetype plugin indent on

```

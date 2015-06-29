<p align="center"><strong align="center">WARNING</strong></p>
<p align="center">vim-gita is under development status (alpha version), mean that there would be critical bugs for daily usage.<br>
Any features, options, mechanisms, etc. might be replaced/removed without any announcements, mean that you should wait to contribute.</p>

vim-gita
===============================================================================
![Screencast (status to commit)](./doc/status-commit.gif)

*vim-gita* is a git manipulation plugin which was strongly inspired by [tpope/vim-fugitive][], [thinca/vim-vcs][], [Shougo/vim-vcs][], and [lambdalisue/vim-gista][].

Core functions and features are powerd by [vim-jp/vital.vim][] and its external modules ([lambdalisue/vital-ArgumentParser][], [lambdalisue/vital-VCS-Git][]), mean that the fundemental functions are well tested in unittest level and vim-gita can focus to provide a user-friendly interface.

vim-gita use a git repository which a current buffer belongs (not like vim-fugitive which use a current working directory and that leads a wrong git repository recognition). You may notice it is quite useful when you temporary open a file which belongs to a different git repository.

Additionally, vim-gita aggressively use cache mechanisms, mean that the response speed of your Vim might be improved, especially if you are using vim-fugitive or a raw git command (`system()`) to show a current status in
the statusline.

[tpope/vim-fugitive]:    https://github.com/tpope/vim-fugitive
[thinca/vim-vcs]:        https://github.com/thinca/vim-vcs
[Shougo/vim-vcs]:        https://github.com/Shougo/vim-vcs
[lambdalisue/vim-gista]: https://github.com/lambdalisue/vim-gista

[vim-jp/vital.vim]:                 https://github.com/vim-jp/vital.vim
[lambdalisue/vital-ArgumentParser]: https://github.com/lambdalisue/vital-ArgumentParser
[lambdalisue/vital-VCS-Git]:        https://github.com/lambdalisue/vital-VCS-Git


ToDo
-------------------------------------------------------------------------------

- [x] Release a prototype version (1st alpha) to get the image
- [x] Release a 2nd alpha version to settle the fundamental mechanisms
  - [x] Do aggressive refactoring to simplify
  - [x] Improve the user interface
  - [x] Fix several known issues
- [ ] Release a 3rd alpha version to add useful features
  - [ ] Add behaviour tests? How?
  - [ ] Add more options to feature commands
  - [ ] Add hints mechanisms to tell features
  - [ ] Add git init feature or disable it
  - [ ] Add git checkout interface (to change, merge, rebase, etc.)
  - [ ] Add git add -p interface
  - [ ] Add git reset -p interface
  - [ ] Add git blame interface or create an external harmonic plugin
- [ ] Release a beta version to find/fix bugs
  - [ ] Write a better document
  - [ ] Write a CONTRIBUTE.md
  - [ ] Add Unite.vim integrations or create an external harmonic plugin
- [ ] Release a product version to help the world!
  - [ ] Write a complete document for user
  - [ ] Write a API document for developer
   
  
Install
-------------------------------------------------------------------------------
The repository follow a standard directory structure thus you can use [gmarik/Vundle.vim], [Shougo/neobundle.vim], or other vim plugin manager to install vim-gita like:

```vim
" Vundle.vim
Plugin 'lambdalisue/vim-gita'

" neobundle.vim
NeoBundle 'lambdalisue/vim-gita'

" neobundle.vim (Lazy)
NeoBundleLazy 'lambdalisue/vim-gita', {
        \ 'autoload': {
        \   'commands': ['Gita'],
        \}}
```

If you are not using any vim plugin manager, you can copy the repository to your $VIM directory to enable the plugin.

[Shougo/neobundle.vim]: https://github.com/Shougo/neobundle.vim
[gmarik/Vundle.vim]:    https://github.com/gmarik/Vundle.vim


Usage
-------------------------------------------------------------------------------

First of all, all commands which vim-gita provides start from `:Gita` and all commands (including `:Gita`) provide `--help/-h` option to show a help message of the command. Like below

```
:Gita -h
:Gita[!] [action] [--help]

An awesome git handling plugin for Vim

Positional arguments:
action      An action of the Gita or git command.
	If a non Gita command is specified or a command is called...
	it call a raw git command instead of a Gita command.

Optional arguments:
-h, --help  show this help
```

To stage/commit changes, follow the steps below:

	1. Hit `:Gita stage` to open a `gita:status` window
	2. Hit `--` to stage/unstage file(s) under the cursor
	3. Hit `cc` to swithc to a `gita:commit` window
	4. Write a commit message and hit `:wq`
	5. Answer `y` to commit changes


To list files changed from a master (like 'Files changed' in GitHub PR), follow the steps below:

	1. Hit `:Gita diff-ls` to open a `gita:diff-ls` window
	2. Answer `master...` to list files changed from a common ancestor
	3. Hit `ee`, `oo` or whatever to open the file


To solve conflicts in merge mode, follow the steps below:

	1. Hit `:Gita stage` to open a `gita:status` window
	2. Hit `ss`, `sS`, or 'SS' to open `vimdiff`
	3. Compare difference and write a correct version
	4. Hit `:Gita add` on a MERGE buffer
	5. Hit `:Gita commit` to open a `gita:commit` window
	6. Write a commit message and hit `:wq` to commit the changes

WIP

### Statusline

vim-gita provides a statusline component (`gita#statusline#format()`) which cache a current status aggressively to enhance the performance. It would improve the performance a lot if you are using `system()` to call a raw git command currently.

Use `gita#statusline#preset()` to get a preset or `gita#statusline#format()` to create your own component.

```vim
" Example usage of gita#statusline#preset()
echo gita#statusline#preset('branch')
" vim-gita/master <> origin/master
echo gita#statusline#preset('status')
" !5 +2 "4 *4
echo gita#statusline#preset('traffic')
" <5 >4

" Example usage of gita#statusline#format()
echo gita#statusline#format('%ln/%lb # %rn/%rb')
" vim-gita/master # origin/master
```

The following is my tabline setting via [itchyny/lightline.vim](https://github.com/itchyny/lightline.vim)

```vim
let g:lightline = {
      \ 'colorscheme': 'hybrid',
      \ 'active': {
      \   'left': [
      \     [ 'mode', 'paste' ],
      \     [ 'filename' ],
      \   ],
      \   'right': [
      \     [ 'lineinfo' ],
      \     [ 'fileformat', 'fileencoding', 'filetype' ],
      \   ],
      \ },
      \ 'inactive': {
      \   'left': [
      \     [ 'filename' ],
      \   ],
      \   'right': [
      \     [ 'fileformat', 'fileencoding', 'filetype' ],
      \   ],
      \ },
      \ 'tabline': {
      \   'left': [
      \     [ 'tabs' ],
      \   ],
      \   'right': [
      \     [ 'close' ],
      \     [ 'git_branch', 'git_traffic', 'git_status', 'cwd' ],
      \   ],
      \ },
      \ 'component_visible_condition': {
      \   'lineinfo': '(winwidth(0) >= 70)',
      \ },
      \ 'component_function': {
      \   'git_branch': 'g:lightline.my.git_branch',
      \   'git_traffic': 'g:lightline.my.git_traffic',
      \   'git_status': 'g:lightline.my.git_status',
      \ },
      \}
let g:lightline.my = {}
function! g:lightline.my.git_branch() " {{{
  return winwidth(0) > 70 ? gita#statusline#preset('branch') : ''
endfunction " }}}
function! g:lightline.my.git_traffic() " {{{
  return winwidth(0) > 70 ? gita#statusline#preset('traffic') : ''
endfunction " }}}
function! g:lightline.my.git_status() " {{{
  return winwidth(0) > 70 ? gita#statusline#preset('status') : ''
endfunction " }}}
```


Documents
-------------------------------------------------------------------------------

See more documents on [vim-gita.txt](./doc/vim-gita.txt) or execute `:help vim-gita`




License
-------------------------------------------------------------------------------
The MIT License (MIT)

Copyright (c) 2015 Alisue, hashnote.net

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

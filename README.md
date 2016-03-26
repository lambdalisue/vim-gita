<div align="center" style="text-align: center">
    <p><img align="center" src="res/vim-gita.256x256.png" alt="vim-gita"></p>
</div>

[![Travis CI](https://img.shields.io/travis/lambdalisue/vim-gita/master.svg?style=flat-square&label=Travis%20CI)](https://travis-ci.org/lambdalisue/vim-gita) [![AppVeyor](https://img.shields.io/appveyor/ci/lambdalisue/vim-gita/master.svg?style=flat-square&label=AppVeyor)](https://ci.appveyor.com/project/lambdalisue/vim-gita/branch/master) ![Version 0.2.0](https://img.shields.io/badge/version-0.2.0-yellow.svg?style=flat-square) ![Support Vim 7.4 or above](https://img.shields.io/badge/support-Vim%207.4%20or%20above-yellowgreen.svg?style=flat-square) [![MIT License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE) [![Doc](https://img.shields.io/badge/doc-%3Ah%20vim--gita-orange.svg?style=flat-square)](doc/vim-gita.txt) [![Powered by vital.vim](https://img.shields.io/badge/powered%20by-vital.vim-80273f.svg)](https://github.com/vim-jp/vital.vim)

*vim-gita* is a git manipulation plugin which allow users to perform daily git operation within Vim's live session.

With vim-gita, users can:

- Manipulate the index of the git repository
  - Stage content changes into the index
  - Unstage content changes from the index
  - Partially stage content changes into the index (like `git add -p`)
  - Partially unstage content changes from the index (like `git reset -p`)
  - Solve conflictions by using 1, 2, or 3-way diff
- Edit a commit message and commit the index into HEAD
- Edit, show, diff files in
  - A working tree of the git repository
  - A index of the git repository
  - A specified commit, branch, etc. of the git repository
- List
  - Files in the working tree of the git repository
  - Files in the index of the git repository
  - Files in a specified commit, branch, etc. of the git repository
  - Files contains specified patterns
  - Files changes between commits
- Blame a file content

And lot more.

vim-gita uses a git repository which

- A current file-like buffer belongs
- A current working directory belongs
- An original file of the pseudo file-like buffer belongs

You may notice that this behavior is quite useful when you temporary open a file in a different git repository or in a non file-like buffer such as help or quickfix.

Additionally, vim-gita aggressively uses cache mechanisms to improve its' performance. You would notice huge performance improvement if you are currently using `system()` to show git repository informations in statusline such as a current branch name or the number of modified files.


Install
-------------------------------------------------------------------------------
Use your favorite Vim plugin manager such as [junegunn/vim-plug] or [Shougo/dein.vim] like:

```vim
" Vundle.vim
Plug 'lambdalisue/vim-gita'

" dein.vim
call dein#add('lambdalisue/vim-gita')

" dein.vim (lazy)
call dein#add('lambdalisue/vim-gita', {
      \ 'on_cmd': 'Gita',
      \})
```

Or copy contents of the repository into your runtimepath manually.

[junegunn/vim-plug.vim]: https://github.com/junegunn/vim-plug
[Shougo/dein.vim]: https://github.com/Shougo/dein.vim


Usage
-------------------------------------------------------------------------------

First of all, all commands which vim-gita provides start from `:Gita` and all commands (including `:Gita`) provide `-h/--help` option to show a help message of the command.

### Status

To check or modify current statuses of a git repository, use `:Gita status` command.

It opens a `gita-status` window which users can confirm or manipulate the current status.

**WIP**

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

**WIP**


Bundle libraries and build statuses
-------------------------------------------------------------------------------

vim-gita rely on the following bundled libraries. (Note: users don't need to install them while these are bundled.)

Status   | Name    | Description
---------|---------|--------------
[![Build Status](https://travis-ci.org/vim-jp/vital.vim.svg)](https://travis-ci.org/vim-jp/vital.vim) | [vim-jp/vital.vim][] | A core library
[![Build Status](https://travis-ci.org/lambdalisue/vital-Vim-Buffer-Anchor.svg)](https://travis-ci.org/lambdalisue/vital-Vim-Buffer-Anchor) | [lambdalisue/vital-Vim-Buffer-Anchor][] | An anchor buffer library
[![Build Status](https://travis-ci.org/lambdalisue/vital-ArgumentParser.svg)](https://travis-ci.org/lambdalisue/vital-ArgumentParser) | [lambdalisue/vital-ArgumentParser][] | An argument parser library
[![Build Status](https://travis-ci.org/lambdalisue/vital-ProgressBar.svg)](https://travis-ci.org/lambdalisue/vital-ProgressBar) | [lambdalisue/vital-ProgressBar][] | A progress bar library
[![Build Status](https://travis-ci.org/lambdalisue/vital-Vim-Prompt.svg)](https://travis-ci.org/lambdalisue/vital-Vim-Prompt) | [lambdalisue/vital-Vim-Prompt][] | A prompt library

[vim-jp/vital.vim]:                    https://github.com/vim-jp/vital.vim
[lambdalisue/vital-Vim-Buffer-Anchor]: https://github.com/lambdalisue/vital-Vim-Buffer-Anchor
[lambdalisue/vital-ArgumentParser]:    https://github.com/lambdalisue/vital-ArgumentParser
[lambdalisue/vital-ProgressBar]:       https://github.com/lambdalisue/vital-ProgressBar
[lambdalisue/vital-Vim-Prompt]:        https://github.com/lambdalisue/vital-Vim-Prompt


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

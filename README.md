<div align="center" style="text-align: center">
    <p><img align="center" src="res/vim-gita.256x256.png" alt="gita"></p>
</div>

[![Travis CI](https://img.shields.io/travis/lambdalisue/vim-gita/master.svg?style=flat-square&label=Travis%20CI)](https://travis-ci.org/lambdalisue/vim-gita)
[![AppVeyor](https://img.shields.io/appveyor/ci/lambdalisue/vim-gita/master.svg?style=flat-square&label=AppVeyor)](https://ci.appveyor.com/project/lambdalisue/vim-gita/branch/master)
![Version 0.1.5](https://img.shields.io/badge/version-0.1.5-yellow.svg?style=flat-square)
![Support Vim 7.4 or above](https://img.shields.io/badge/support-Vim%207.4%20or%20above-yellowgreen.svg?style=flat-square)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)
[![Doc](https://img.shields.io/badge/doc-%3Ah%20gita-orange.svg?style=flat-square)](doc/gita.txt)
[![Powered by vital.vim](https://img.shields.io/badge/powered%20by-vital.vim-80273f.svg?style=flat-square)](https://github.com/vim-jp/vital.vim)

**The development of vim-gita has closed. Users should check [lambdalisue/gina.vim](https://github.com/lambdalisue/gina.vim) which is a new impleomentation of vim-gita by using `job` features of Vim 8 or Neovim**

*gita* is a git manipulation plugin which allow users to perform daily git operation within Vim's live session.


With gita, users can:


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

gita uses a git repository which

- A current file-like buffer belongs
- A current working directory belongs
- An original file of the pseudo file-like buffer belongs

You may notice that this behavior is quite useful when you temporary open a file in a different git repository or in a non file-like buffer such as help or quickfix.

Additionally, gita aggressively uses cache mechanisms to improve its' performance. You would notice huge performance improvement if you are currently using `system()` to show git repository informations in statusline such as a current branch name or the number of modified files.

Install
-------------------------------------------------------------------------------
Use your favorite Vim plugin manager such as [junegunn/vim-plug] or [Shougo/dein.vim] like:

```vim
" Plug.vim
Plug 'lambdalisue/vim-gita'

"Plug.vim (lazy)
Plug 'lambdalisue/vim-gita', {'on': ['Gita']}

" dein.vim
call dein#add('lambdalisue/vim-gita')

" dein.vim (lazy)
call dein#add('lambdalisue/vim-gita', {
      \ 'on_cmd': 'Gita',
      \})
```

Or copy contents of the repository into your runtimepath manually.

[junegunn/vim-plug]: https://github.com/junegunn/vim-plug
[Shougo/dein.vim]: https://github.com/Shougo/dein.vim


Usage
-------------------------------------------------------------------------------

First of all, all commands which gita provides start from `:Gita` and all commands (including `:Gita` itself) provide `-h/-help` option to show a help message of the command.

Additionally, hitting `?` in manipulation windows (e.g. `gita-status`) shows action and mapping helps.

See `:help gita-usage` for more detail.

### Status

To check or modify current statuses of a git repository, use `:Gita status` command like below.

The status of each modified files are shown a short format.
If you are not familiar with short format, see `:help gita-usage-status-cheetsheet` or a manpage of git-status.

[![asciicast](https://asciinema.org/a/41576.png)](https://asciinema.org/a/41576)

### Patch

To partially stage or unstage changes (like `git add -p` or `git reset -p`), use `:Gita patch` command on a corresponding file buffer like below.
It opens three vimdiff windows which indicates a contents of

1. HEAD (`gita://<refname>:show/HEAD:<filename>`)
2. Index (`gita://<refname>:show:patch/:<filename>`)
3. Working tree (`<filename>`)

In INDEX window, all changes saved is patched to the index of the repository.
See `:help gita-usage-patch` for more detail.

[![asciicast](https://asciinema.org/a/41579.png)](https://asciinema.org/a/41579)

### Conflict

To solve conflicts, use `:Gita chaperone` command on a conflicted file buffer like below.
It opens three buffers which indicate a content of

1. OURS (`gita://<refname>:show/:2:<filename>`)
2. WORKTREE (`<filename>`)
3. THEIRS (`gita://<refname>:show/:3:<filename>`)

See `:help gita-usage-chaperone` for more detail.

[![asciicast](https://asciinema.org/a/12436gcrwmuf169s2ze6eedpi.png)](https://asciinema.org/a/12436gcrwmuf169s2ze6eedpi)

### Changes

[![asciicast](https://asciinema.org/a/41583.png)](https://asciinema.org/a/41583)

### Search (grep)

[![asciicast](https://asciinema.org/a/51mvst9wu3s411bb2ahjvhyk8.png)](https://asciinema.org/a/51mvst9wu3s411bb2ahjvhyk8)

### Blame

[![asciicast](https://asciinema.org/a/41585.png)](https://asciinema.org/a/41585)

Bundle libraries and build statuses
-------------------------------------------------------------------------------

gita rely on the following bundled libraries. (Note: users don't need to install them while these are bundled.)

Status   | Name    | Description
---------|---------|--------------
[![Build Status](https://travis-ci.org/vim-jp/vital.vim.svg)](https://travis-ci.org/vim-jp/vital.vim) | [vim-jp/vital.vim][] | A core library
[![Build Status](https://travis-ci.org/lambdalisue/vital-Vim-Buffer-Anchor.svg)](https://travis-ci.org/lambdalisue/vital-Vim-Buffer-Anchor) | [lambdalisue/vital-Vim-Buffer-Anchor][] | An anchor buffer library
[![Build Status](https://travis-ci.org/lambdalisue/vital-ArgumentParser.svg)](https://travis-ci.org/lambdalisue/vital-ArgumentParser) | [lambdalisue/vital-ArgumentParser][] | An argument parser library
[![Build Status](https://travis-ci.org/lambdalisue/vital-ProgressBar.svg)](https://travis-ci.org/lambdalisue/vital-ProgressBar) | [lambdalisue/vital-ProgressBar][] | A progress bar library
[![Build Status](https://travis-ci.org/lambdalisue/vital-Vim-Console.svg)](https://travis-ci.org/lambdalisue/vital-Vim-Console) | [lambdalisue/vital-Vim-Console][] | A console library

[vim-jp/vital.vim]:                    https://github.com/vim-jp/vital.vim
[lambdalisue/vital-Vim-Buffer-Anchor]: https://github.com/lambdalisue/vital-Vim-Buffer-Anchor
[lambdalisue/vital-ArgumentParser]:    https://github.com/lambdalisue/vital-ArgumentParser
[lambdalisue/vital-ProgressBar]:       https://github.com/lambdalisue/vital-ProgressBar
[lambdalisue/vital-Vim-Console]:       https://github.com/lambdalisue/vital-Vim-Console


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

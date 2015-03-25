"******************************************************************************
" vim-gita ui diff
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


function! s:diffthis(commit, ...) abort " {{{
  let gita = gita#get()
  if !gita.is_enable
    return
  endif

  let commit = a:commit
  if strlen(commit) == 0
    let commit = gita#util#ask('Which commit do you want to compare with? ', 'HEAD')
    if strlen(commit) == 0
      call gita#util#warn('Operation has canceled by user.')
      return
    endif
  endif

  let opts = extend({
        \ 'no_prefix': 1,
        \ 'no_color': 1,
        \ 'unified': '0',
        \ 'R': 1,
        \ 'histogram': 1,
        \}, get(a:000, 0, {}))

  let result = gita.git.diff(opts, commit, expand('%'))
  if result.status == 0
    if strlen(result.stdout) == 0
      call gita#util#warn(
            \ printf('No changes exists from %s on %s', commit, expand('%')),
            \)
      return
    endif
    " nodiff all
    let winnum = winnr()
    diffoff!
    windo if &diff | setlocal nodiff noscb fdc& | endif
    for i in range(1, bufnr('$'))
      if bufexists(i) && getbufvar(i, "&diff")
        call setbufvar(i, '&diff', 0)
        call setbufvar(i, '&scb', 0)
        call setbufvar(i, '&fdc', '&fdc')
      endif
    endfor
    silent execute winnum . 'wincmd w'
    let bufnum = bufnr('')
    let filetype = &filetype
    let fname_out = tempname()
    let fname_new = printf("%s [%s]", bufname('%'), commit)
    if bufexists(bufnr(fname_new))
      silent execute bufwinnr(bufnr(fname_new)) . 'wincmd w'
    else
      call writefile(split(result.stdout, '\v\r?\n'), fname_out)
      silent execute 'vert diffpatch' fname_out
      setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
      setlocal foldmethod=diff
      silent execute 'file' fname_new
      call delete(fname_out)
      setl nomodifiable

      augroup vim_gita_diff
        autocmd! * <buffer>
        autocmd BufWinLeave <buffer> diffoff
      augroup END
    endif

    let winnum = bufwinnr(bufnum)
    silent execute winnum . 'wincmd w'

    augroup vim_gita_diff
      autocmd! * <buffer>
      autocmd BufWinLeave <buffer> diffoff
    augroup END
  endif
endfunction " }}}

function! gita#ui#diff#diffthis(...) abort " {{{
  if a:0 > 0 && gita#util#is_dict(a:1)
    let commit = ''
    let options = get(a:000, 0)
  else
    let commit = get(a:000, 0, '')
    let options = get(a:000, 1, {})
  endif
  call s:diffthis(commit, options)
endfunction " }}}
let &cpo = s:save_cpo
unlet! s:save_cpo
"vim: stts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

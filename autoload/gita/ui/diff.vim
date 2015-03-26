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

  let opts = extend({
        \ 'no_prefix': 1,
        \ 'no_color': 1,
        \ 'unified': '0',
        \ 'R': 1,
        \ 'histogram': 1,
        \ 'vertical': 1,
        \}, get(a:000, 0, {}))

  let result = gita.git.diff(opts, a:commit, expand('%'))
  if result.status != 0
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
    return
  elseif strlen(result.stdout) == 0
    call gita#util#warn(
          \ printf('No changes exists from %s on %s', a:commit, expand('%')),
          \)
    return
  endif
  " construct diff
  diffoff!
  let bufnum = bufnr('')
  let filetype = &filetype
  let fname_out = tempname()
  let fname_new = printf("%s.%s", bufname('%'), a:commit)
  if bufexists(fname_new)
    silent bwipeout fname_new
  endif
  call writefile(split(result.stdout, '\v\r?\n'), fname_out)
  if opts.vertical
    silent execute 'vert diffpatch' fname_out
  else
    silent execute 'diffpatch' fname_out
  endif
  call delete(fname_out)
  silent execute 'file' fname_new
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal foldmethod=diff
  setl nomodifiable
  let b:_gita_diff_bufnum = bufnum
  augroup vim_gita_diff
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:diff_leave_ac()
  augroup END

  let bufnum = bufnr('')
  silent execute 'wincmd p'
  let b:_gita_diff_bufnum = bufnum
  augroup vim_gita_diff
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:orig_leave_ac()
  augroup END
endfunction " }}}
function! s:diff_leave_ac() abort " {{{
  diffoff
  if bufexists(b:_gita_diff_bufnum)
    let winnum = bufwinnr(b:_gita_diff_bufnum)
    if winnum != -1
      silent execute winnum . 'wincmd w'
      diffoff
      silent execute 'wincmd p'
    endif
  endif
  unlet b:_gita_diff_bufnum
  augroup vim_gita_diff
    autocmd! * <buffer>
  augroup END
endfunction " }}}
function! s:orig_leave_ac() abort " {{{
  diffoff
  if bufexists(b:_gita_diff_bufnum)
    silent execute 'bwipeout' b:_gita_diff_bufnum
  endif
  unlet b:_gita_diff_bufnum
  augroup vim_gita_diff
    autocmd! * <buffer>
  augroup END
endfunction " }}}

function! gita#ui#diff#diffthis(...) abort " {{{
  if a:0 > 0 && gita#util#is_dict(a:1)
    let commit = ''
    let options = get(a:000, 0)
  else
    let commit = get(a:000, 0, '')
    let options = get(a:000, 1, {})
  endif

  if strlen(commit) == 0
    let commit = gita#util#ask('Which commit do you want to compare with? ', 'HEAD')
    if strlen(commit) == 0
      call gita#util#warn('Operation has canceled by user.')
      return
    endif
  endif
  call s:diffthis(commit, options)
endfunction " }}}
let &cpo = s:save_cpo
unlet! s:save_cpo
"vim: stts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

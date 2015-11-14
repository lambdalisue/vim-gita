let s:save_cpo = &cpo
set cpo&vim

function! s:Gita(...) abort " {{{
  call call('gita#features#command', a:000)
endfunction " }}}
function! s:GitaComplete(...) abort " {{{
  return call('gita#features#complete', a:000)
endfunction " }}}

command! -nargs=? -range -bang
      \ -complete=customlist,s:GitaComplete
      \ Gita
      \ :call s:Gita(<q-bang>, [<line1>, <line2>], <f-args>)

command! GitaClearCache :call gita#clear_cache()


let s:default_config = {
      \ 'debug': 0,
      \ 'develop': 1,
      \ 'monitor#opener': 'topleft 15 split',
      \ 'monitor#range': 'tabpage',
      \ 'utils#anchor#unsuitable_bufname_pattern': '',
      \ 'utils#anchor#unsuitable_filetype_pattern': printf(
      \   '^\%%(%s\)', join([
      \     'gita-status',
      \     'gita-commit',
      \     'gita-diff-ls',
      \     'unite',
      \     'vimfiler',
      \     'nerdtree',
      \     'gundo',
      \     'tagbar',
      \   ], '\|')
      \ ),
      \ 'utils#buffer#separator': has('unix') ? ':' : '_',
      \ 'features#add#default_options': {},
      \ 'features#browse#default_options': {},
      \ 'features#browse#translation_patterns': {
      \   'github.com': [
      \     [
      \       '\vhttps?://(%domain)/(.{-})/(.{-})%(\.git)?$',
      \       '\vgit://(%domain)/(.{-})/(.{-})%(\.git)?$',
      \       '\vgit\@(%domain):(.{-})/(.{-})%(\.git)?$',
      \       '\vssh://git\@(%domain)/(.{-})/(.{-})%(\.git)?$',
      \     ], {
      \       '_':     'https://\1/\2/\3/blob/%c1/%pt%{#L|}ls%{-L|}le',
      \       'exact': 'https://\1/\2/\3/blob/%r1/%pt%{#L|}ls%{-L|}le',
      \       'blame': 'https://\1/\2/\3/blame/%c1/%pt%{#L|}ls%{-L|}le',
      \     },
      \   ],
      \   'bitbucket.org': [
      \     [
      \       '\vhttps?://(%domain)/(.{-})/(.{-})%(\.git)?$',
      \       '\vgit://(%domain)/(.{-})/(.{-})%(\.git)?$',
      \       '\vgit\@(%domain):(.{-})/(.{-})%(\.git)?$',
      \       '\vssh://git\@(%domain)/(.{-})/(.{-})%(\.git)?$',
      \     ], {
      \       '_':     'https://\1/\2/\3/src/%c1/%pt%{#cl-|}ls',
      \       'exact': 'https://\1/\2/\3/src/%r1/%pt%{#cl-|}ls',
      \       'blame': 'https://\1/\2/\3/annotate/%c1/%pt',
      \       'diff':  'https://\1/\2/\3/diff/%pt?diff1=%c1&diff2=%c2',
      \     },
      \   ],
      \ },
      \ 'features#browse#extra_translation_patterns': {},
      \ 'features#checkout#default_options': {},
      \ 'features#commit#default_options': {
      \   'untracked-files': 1,
      \ },
      \ 'features#commit#monitor_opener': '',
      \ 'features#commit#monitor_range': '',
      \ 'features#commit#enable_default_mappings': 1,
      \ 'features#conflict#default_options': {},
      \ 'features#diff#default_options': {
      \   'split': 1,
      \   'vertical': 1,
      \ },
      \ 'features#diff_ls#default_options': {},
      \ 'features#diff_ls#monitor_opener': '',
      \ 'features#diff_ls#monitor_range': '',
      \ 'features#diff_ls#enable_default_mappings': 1,
      \ 'features#file#default_options': {},
      \ 'features#reset#default_options': {},
      \ 'features#rm#default_options': {},
      \ 'features#status#default_options': {
      \   'untracked-files': 1,
      \ },
      \ 'features#status#monitor_opener': '',
      \ 'features#status#monitor_range': '',
      \ 'features#status#enable_default_mappings': 1,
      \ 'features#status#prefer_unstage_in_toggle': 0,
      \ 'features#blame#default_options': {},
      \ 'features#blame#enable_pseudo_separator': 1,
      \ 'features#blame#enable_default_mappings': 1,
      \ 'features#blame#enable_default_navi_mappings': 0,
      \ 'features#blame#enable_default_view_mappings': 0,
      \}
function! s:assign_config() abort " {{{
  for [key, value] in items(s:default_config)
    let key = printf('g:gita#%s', key)
    if !exists(key)
      silent execute printf('let %s = %s', key, string(value))
    endif
    unlet! value
  endfor
endfunction " }}}
call s:assign_config()


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

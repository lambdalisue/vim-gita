let s:save_cpo = &cpo
set cpo&vim


function! gita#init_variables() abort " {{{
  let g:gita#debug = 0
  " features/status
  let g:gita#features#status#enable_default_mappings = 1
  let g:gita#features#status#prefer_unstage_in_toggle = 0
  let g:gita#features#commit#enable_default_mappings = 1
  let g:gita#features#diff_ls#enable_default_mappings = 1
  let g:gita#features#browse#translation_patterns =
        \ [
        \  ['\vssh://git\@(github\.com)/([^/]+)/(.+)%(\.git|)',
        \   'https://\1/\2/\3/blob/%br/%pt%{#L|}ls%{-L|}le'],
        \  ['\vgit\@(github\.com):([^/]+)/(.+)%(\.git|)',
        \   'https://\1/\2/\3/blob/%br/%pt%{#L|}ls%{-L|}le'],
        \  ['\vhttps?://(github\.com)/([^/]+)/(.+)',
        \   'https://\1/\2/\3/blob/%br/%pt%{#L|}ls%{-L|}le'],
        \  ['\vgit\@(bitbucket\.org):([^/]+)/(.+)%(\.git|)',
        \   'https://\1/\2/\3/src/%br/%pt%{#cl-|}ls'],
        \  ['\vhttps?://(bitbucket\.org)/([^/]+)/(.+)',
        \   'https://\1/\2/\3/src/%br/%pt%{#cl-|}ls'],
        \ ]
  let g:gita#features#browse#extra_translation_patterns = []
endfunction " }}}


let &cpo = s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

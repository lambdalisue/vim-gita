let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-stage)': 'Stage changes to the index',
      \}

function! s:is_available(candidate) abort
  let necessary_attributes = ['path', 'is_unstaged', 'worktree']
  for attribute in necessary_attributes
    if !has_key(a:candidate, attribute)
      return 0
    endif
  endfor
  return 1
endfunction

function! gita#action#stage#action(candidates, ...) abort
  let options = extend({
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  let rm_candidates = []
  let add_candidates = []
  let candidates = filter(copy(a:candidates), 's:is_available(v:val)')
  for candidate in candidates
    if candidate.is_unstaged && candidate.worktree ==# 'D'
      call add(rm_candidates, candidate)
    else
      call add(add_candidates, candidate)
    endif
  endfor
  noautocmd call gita#action#do('add', add_candidates, options)
  noautocmd call gita#action#do('rm', rm_candidates, options)
  call gita#util#doautocmd('User', 'GitaStatusModified')
endfunction

function! gita#action#stage#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-stage)
        \ :call gita#action#call('stage')<CR>
endfunction

function! gita#action#stage#define_default_mappings() abort
  map <buffer><nowait><expr> << gita#action#smart_map('<<', '<Plug>(gita-stage)')
endfunction

function! gita#action#stage#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#stage', {})


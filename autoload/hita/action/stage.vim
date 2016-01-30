let s:V = hita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-stage)': 'Stage changes to the index',
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

function! hita#action#stage#action(candidates, ...) abort
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
  noautocmd call hita#action#do('add', add_candidates, {})
  noautocmd call hita#action#do('rm', rm_candidates, {})
  call hita#util#doautocmd('StatusModified')
endfunction

function! hita#action#stage#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-stage)
        \ :call hita#action#call('stage')<CR>
endfunction

function! hita#action#stage#define_default_mappings() abort
  map <buffer> << <Plug>(hita-stage)
endfunction

function! hita#action#stage#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#stage', {})


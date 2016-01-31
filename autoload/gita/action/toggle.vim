let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-toggle)': 'Toggle stage/unstage',
      \}

function! s:is_available(candidate) abort
  let necessary_attributes = [
        \ 'path', 'is_staged', 'is_unstaged',
        \ 'is_untracked', 'is_ignored',
        \]
  for attribute in necessary_attributes
    if !has_key(a:candidate, attribute)
      return 0
    endif
  endfor
  return 1
endfunction

function! gita#action#toggle#action(candidates, ...) abort
  let options = extend({}, get(a:000, 0, {}))
  let stage_candidates = []
  let unstage_candidates = []
  let candidates = filter(copy(a:candidates), 's:is_available(v:val)')
  for candidate in candidates
    if candidate.is_staged && candidate.is_unstaged
      if g:gita#action#toggle#prefer_unstage
        call add(unstage_candidates, candidate)
      else
        call add(stage_candidates, candidate)
      endif
    elseif candidate.is_staged
      call add(unstage_candidates, candidate)
    elseif candidate.is_unstaged || candidate.is_untracked || candidate.is_ignored
      call add(stage_candidates, candidate)
    endif
  endfor
  noautocmd call gita#action#do('stage', stage_candidates, {})
  noautocmd call gita#action#do('unstage', unstage_candidates, {})
  call gita#util#doautocmd('StatusModified')
endfunction

function! gita#action#toggle#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-toggle)
        \ :call gita#action#call('toggle')<CR>
endfunction

function! gita#action#toggle#define_default_mappings() abort
  map <buffer><expr> -- gita#action#smart_map('--', '<Plug>(gita-toggle)')
endfunction

function! gita#action#toggle#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#toggle', {
      \ 'prefer_unstage': 0,
      \})

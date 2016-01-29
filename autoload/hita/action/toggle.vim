let s:V = hita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-toggle)': 'Toggle stage/unstage',
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

function! hita#action#toggle#action(candidates, ...) abort
  let options = extend({}, get(a:000, 0, {}))
  let stage_candidates = []
  let unstage_candidates = []
  let candidates = filter(copy(a:candidates), 's:is_available(v:val)')
  for candidate in candidates
    if candidate.is_staged && candidate.is_unstaged
      if g:hita#action#toggle#prefer_unstage
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
  noautocmd call hita#action#do('stage', stage_candidates, {})
  noautocmd call hita#action#do('unstage', unstage_candidates, {})
  silent call hita#util#doautocmd('StatusModified')
endfunction

function! hita#action#toggle#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-toggle)
        \ :call hita#action#call('toggle')<CR>
endfunction

function! hita#action#toggle#define_default_mappings() abort
  map <buffer> -- <Plug>(hita-toggle)
endfunction

function! hita#action#toggle#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#toggle', {
      \ 'prefer_unstage': 0,
      \})

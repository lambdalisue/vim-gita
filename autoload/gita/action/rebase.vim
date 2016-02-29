let s:V = gita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-rebase)': 'Rebase HEAD from the commit (fast-forward)',
      \ '<Plug>(gita-rebase-merge)': 'Rebase HEAD by merging the commit',
      \}

function! s:is_available(candidate) abort
  let necessary_attributes = [
      \ 'is_remote',
      \ 'is_selected',
      \ 'name',
      \ 'remote',
      \ 'linkto',
      \ 'record',
      \]
  for attribute in necessary_attributes
    if !has_key(a:candidate, attribute)
      return 0
    endif
  endfor
  return 1
endfunction
function! gita#action#rebase#action(candidates, ...) abort
  let options = extend({
        \ 'merge': 0,
        \}, get(a:000, 0, {}))
  let branch_names = []
  for candidate in a:candidates
    if s:is_available(candidate)
      call add(branch_names, candidate.name)
    endif
  endfor
  if !empty(branch_names)
    call gita#command#rebase#call({
          \ 'quiet': 0,
          \ 'commits': branch_names,
          \ 'merge': options.merge,
          \})
  endif
endfunction

function! gita#action#rebase#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-rebase)
        \ :call gita#action#call('rebase')<CR>
  noremap <buffer><silent> <Plug>(gita-rebase-merge)
        \ :call gita#action#call('rebase', { 'merge': 1 })<CR>
endfunction

function! gita#action#rebase#define_default_mappings() abort
endfunction

function! gita#action#rebase#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#rebase', {})


let s:V = gita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-merge)': 'Merge the commit into HEAD (fast-forward)',
      \ '<Plug>(gita-merge-ff-only)': 'Merge the commit into HEAD when fast-forward is available',
      \ '<Plug>(gita-merge-no-ff)': 'Merge the commit into HEAD and create a commit',
      \ '<Plug>(gita-merge-squash)': 'Squash the commit into HEAD',
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
function! gita#action#merge#action(candidates, ...) abort
  let options = extend({
        \ 'no-ff': 0,
        \ 'ff-only': 0,
        \ 'squash': 0,
        \}, get(a:000, 0, {}))
  let branch_names = []
  for candidate in a:candidates
    if s:is_available(candidate)
      call add(branch_names, candidate.name)
    endif
  endfor
  if !empty(branch_names)
    call gita#command#merge#call({
          \ 'quiet': 0,
          \ 'commits': branch_names,
          \ 'no-ff': options['no-ff'],
          \ 'ff-only': options['ff-only'],
          \ 'squash': options.squash,
          \})
  endif
endfunction

function! gita#action#merge#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-merge)
        \ :call gita#action#call('merge')<CR>
  noremap <buffer><silent> <Plug>(gita-merge-ff-only)
        \ :call gita#action#call('merge', { 'ff-only': 1 })<CR>
  noremap <buffer><silent> <Plug>(gita-merge-no-ff)
        \ :call gita#action#call('merge', { 'no-ff': 1 })<CR>
  noremap <buffer><silent> <Plug>(gita-merge-squash)
        \ :call gita#action#call('merge', { 'squash': 1 })<CR>
endfunction

function! gita#action#merge#define_default_mappings() abort
endfunction

function! gita#action#merge#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#merge', {})

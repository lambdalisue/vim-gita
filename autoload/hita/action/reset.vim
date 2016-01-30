let s:V = hita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-reset)': 'Reset changes on an index',
      \}

function! hita#action#reset#action(candidates, ...) abort
  let options = extend({
        \}, get(a:000, 0, {}))
  let git = hita#get_or_fail()
  let filenames = []
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call add(filenames, s:Path.unixpath(
            \ s:Git.get_relative_path(git, candidate.path)
            \))
    endif
  endfor
  if !empty(filenames)
    let result = hita#command#reset#call({
          \ 'filenames': filenames,
          \ 'quiet': 1,
          \})
    " TODO: Show some success mesage?
  endif
endfunction

function! hita#action#reset#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-reset)
        \ :call hita#action#call('reset')<CR>
endfunction

function! hita#action#reset#define_default_mappings() abort
  map <buffer> -r <Plug>(hita-reset)
endfunction

function! hita#action#reset#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#reset', {})

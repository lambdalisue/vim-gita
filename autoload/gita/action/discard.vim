let s:V = gita#vital()
let s:File = s:V.import('System.File')
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-discard)': 'Discard changes on the working tree',
      \ '<Plug>(gita-DISCARD)': 'Discard changes on the working tree (force)',
      \}

function! s:is_available(candidate) abort
  let necessary_attributes = [
      \ 'path', 'is_conflicted',
      \ 'is_staged', 'is_unstaged',
      \ 'is_untracked', 'is_ignored',
      \]
  for attribute in necessary_attributes
    if !has_key(a:candidate, attribute)
      return 0
    endif
  endfor
  return 1
endfunction

function! gita#action#discard#action(candidates, ...) abort
  let options = extend({
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  let delete_candidates = []
  let checkout_candidates = []
  let candidates = filter(copy(a:candidates), 's:is_available(v:val)')
  for candidate in candidates
    if candidate.is_conflicted
      call s:Prompt.warn(printf(
            \ 'A conflicted file "%s" cannot be discarded. Resolve conflict first.',
            \ s:Path.relpath(candidate.path),
            \))
      continue
    elseif candidate.is_untracked || candidate.is_ignored
      call add(delete_candidates, candidate)
    elseif candidate.is_staged || candidate.is_unstaged
      call add(checkout_candidates, candidate)
    endif
  endfor
  if !options.force
    call s:Prompt.attention(
          \ 'A discard action will discard all local changes on the working tree',
          \ 'and the operation is irreversible, mean that you have no chance to',
          \ 'revert the operation.',
          \)
    echo 'This operation will be performed to the following candidates:'
    for candidate in extend(copy(delete_candidates), checkout_candidates)
      echo '- ' . s:Path.relpath(candidate.path)
    endfor
    if !s:Prompt.confirm('Are you sure to discard the changes?')
      call gita#throw('Cancel: The operation has canceled by user')
    endif
  endif
  " delete untracked files
  for candidate in delete_candidates
    if isdirectory(candidate.path)
      call s:File.rmdir(candidate.path, 'r')
    elseif filewritable(candidate.path)
      call delete(candidate.path)
    endif
  endfor
  " checkout tracked files from HEAD
  noautocmd call gita#action#do('checkout', checkout_candidates, {
        \ 'commit': 'HEAD',
        \ 'force': 1,
        \})
  call gita#util#doautocmd('StatusModified')
endfunction

function! gita#action#discard#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-discard)
        \ :call gita#action#call('discard')<CR>
  noremap <buffer><silent> <Plug>(gita-DISCARD)
        \ :call gita#action#call('discard', { 'force': 1 })<CR>
endfunction

function! gita#action#discard#define_default_mappings() abort
  map <buffer><nowait><expr> == gita#action#smart_map('==', '<Plug>(gita-discard)')
endfunction

function! gita#action#discard#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#discard', {})

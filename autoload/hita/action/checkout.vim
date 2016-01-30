let s:V = hita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-checkout)': 'Checkout contents to the working tree',
      \ '<Plug>(hita-CHECKOUT)': 'Checkout contents to the working tree (force)',
      \ '<Plug>(hita-checkout-ours)': 'Checkout contents of "ours" to the working tree',
      \ '<Plug>(hita-CHECKOUT-OURS)': 'Checkout contents or "ours" to the working tree (force)',
      \ '<Plug>(hita-checkout-theirs)': 'Checkout contents of "theirs" to the working tree',
      \ '<Plug>(hita-CHECKOUT-THEIRS)': 'Checkout contents or "theirs" to the working tree (force)',
      \}

function! hita#action#checkout#action(candidates, ...) abort
  let options = extend({
        \ 'force': 0,
        \ 'ours': 0,
        \ 'theirs': 0,
        \}, get(a:000, 0, {}))
  let git = hita#get_or_fail()
  let filenames = []
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call checkout(filenames, s:Path.unixpath(
            \ s:Git.get_relative_path(git, candidate.path)
            \))
    endif
  endfor
  if !empty(filenames)
    let result = hita#command#checkout#call({
          \ 'filenames': filenames,
          \ 'force': options.force,
          \ 'ours': options.ours,
          \ 'theirs': options.theirs,
          \ 'quiet': 1,
          \})
    " TODO: Show some success message?
  endif
endfunction

function! hita#action#checkout#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-checkout)
        \ :call hita#action#call('checkout')<CR>
  noremap <buffer><silent> <Plug>(hita-CHECKOUT)
        \ :call hita#action#call('checkout', { 'force': 1 })<CR>
  noremap <buffer><silent> <Plug>(hita-checkout-ours)
        \ :call hita#action#call('checkout', { 'ours': 1 })<CR>
  noremap <buffer><silent> <Plug>(hita-CHECKOUT-OURS)
        \ :call hita#action#call('checkout', { 'force': 1, 'ours': 1 })<CR>
  noremap <buffer><silent> <Plug>(hita-checkout-theirs)
        \ :call hita#action#call('checkout', { 'theirs': 1 })<CR>
  noremap <buffer><silent> <Plug>(hita-CHECKOUT-THEIRS)
        \ :call hita#action#call('checkout', { 'force': 1, 'theirs': 1 })<CR>
endfunction

function! hita#action#checkout#define_default_mappings() abort
  map <buffer> -c <Plug>(hita-checkout)
  map <buffer> -C <Plug>(hita-CHECKOUT)
  map <buffer> -o <Plug>(hita-checkout-ours)
  map <buffer> -O <Plug>(hita-CHECKOUT-OURS)
  map <buffer> -t <Plug>(hita-checkout-theirs)
  map <buffer> -T <Plug>(hita-CHECKOUT-THEIRS)
endfunction

function! hita#action#checkout#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#checkout', {})


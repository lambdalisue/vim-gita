let s:V = hita#vital()
let s:Dict = s:V.import('Data.Dict')

function! s:define_plugin_mappings() abort
  nnoremap <buffer><silent> <Plug>(hita-quit)
        \ :<C-u>q<CR>
  nnoremap <buffer><silent> <Plug>(hita-redraw)
        \ :call <SID>action('redraw')<CR>
endfunction
function! s:define_default_mappings() abort
  nmap <buffer> q <Plug>(hita-quit)
  nmap <buffer> <C-l> <Plug>(hita-redraw)
endfunction

function! s:get_entry(index) abort
  return {}
endfunction
function! s:action(name, ...) range abort
  let fname = printf('s:action_%s', a:name)
  if !exists('*' . fname)
    call hita#throw(printf('Unknown action name "%s" is called.', a:name))
  endif
  let entries = []
  for n in range(a:firstline, a:lastline)
    call add(entries, s:get_entry(n - 1))
  endfor
  call filter(entries, '!empty(v:val)')
  call call(fname, extend([entries], a:000))
endfunction
function! s:action_redraw(candidates, ...) abort
  call hita#command#blame#navi#redraw()
endfunction

function! hita#command#blame#navi#bufname(...) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}))
  call hita#option#assign_options(options, 'blame-navi')
  let hita = hita#core#get()
  try
    call hita.fail_on_disabled()
    let commit = hita#variable#get_valid_range(options.commit, {
          \ '_allow_empty': 1,
          \})
    let filename = hita#variable#get_valid_filename(options.filename)
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
    return
  endtry
  return printf('hita-blame-navi:%s:%s:%s',
        \ hita.get_repository_name(),
        \ commit, hita.get_relative_path(filename),
        \)
endfunction
function! hita#command#blame#navi#call(...) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}))
  call hita#option#assign_options(options, 'blame-navi')
  let bufname = hita#command#blame#bufname(options)
  if empty(bufname)
    return
  endif
  try
    let bufnum = bufnr(bufname)
    let content_type = hita#core#get_meta('content_type', '', bufnum)
    if bufnum == 0 || content_type !=# 'blame'
      call hita#throw(
            \ 'hita-blame-navi window requires a corresponding hita-blame buffer.',
            \)
      return
    endif
    let commit = hita#core#get_meta('commit', '', bufnum)
    let filename = hita#core#get_meta('filename', '', bufnum)
    let content = hita#core#get_meta('content', [], bufnum)
    let blame = hita#core#get_meta('blame', {}, bufnum)
    if empty(blame)
      call hita#throw(printf('No blame information has found on %s', bufname))
    endif
    let result = {
          \ 'bufname': bufname,
          \ 'bufnum': bufnum,
          \ 'commit': commit,
          \ 'filename': filename,
          \ 'content': content,
          \ 'blame': blame,
          \}
    return result
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
    return {}
  endtry
endfunction
function! hita#command#blame#navi#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let result = hita#command#blame#navi#call(options)
  if empty(result)
    return
  endif
  let opener = empty(options.opener)
        \ ? g:hita#command#blame#default_opener
        \ : options.opener
  let bufname = hita#command#blame#navi#bufname(options)
  call hita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'group': 'blame_navigation_panel',
        \})
  call hita#core#set_meta('content_type', 'blame-navi')
  call hita#core#set_meta('options', s:Dict.omit(options, ['force']))
  call hita#core#set_meta('commit', result.commit)
  call hita#core#set_meta('filename', result.filename)
  call hita#core#set_meta('content', result.content)
  call hita#core#set_meta('blame', result.blame)
  call hita#core#set_meta('winwidth', winwidth(0))
  call s:define_plugin_mappings()
  if g:hita#command#blame#navi#enable_default_mappings
    call s:define_default_mappings()
  endif
  augroup vim_hita_status
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer>
          \ call hita#command#blame#navi#update() |
          \ setlocal filetype=hita-blame-navi
    "autocmd VimResized <buffer> call s:on_VimResized()
    "autocmd WinEnter   <buffer> call s:on_WinEnter()
  augroup END
  setlocal buftype=nowrite noswapfile nobuflisted
  setlocal nowrap nofoldenable foldcolumn=0 colorcolumn=0
  setlocal nonumber nolist
  setlocal nomodifiable
  setlocal scrollopt=ver
  setlocal filetype=hita-blame-navi
  call hita#command#blame#navi#redraw()
endfunction
function! hita#command#blame#navi#update(...) abort
  if &filetype !=# 'hita-blame-navi'
    call hita#throw(
          \ 'update() requires to be called in a hita-blame-navi buffer'
          \)
  endif
  let options = get(a:000, 0, {})
  let result = hita#command#blame#navi#call(options)
  if empty(result)
    return
  endif
  call hita#core#set_meta('content_type', 'blame-navi')
  call hita#core#set_meta('options', s:Dict.omit(options, ['force']))
  call hita#core#set_meta('commit', result.commit)
  call hita#core#set_meta('filename', result.filename)
  call hita#core#set_meta('content', result.content)
  call hita#core#set_meta('blame', result.blame)
  call hita#core#set_meta('winwidth', winwidth(0))
  call hita#command#blame#navi#redraw()
endfunction
function! hita#command#blame#navi#redraw() abort
  if &filetype !=# 'hita-blame-navi'
    call hita#throw(
          \ 'redraw() requires to be called in a hita-status buffer'
          \)
  endif
  let blame = hita#core#get_meta('blame')
  call hita#util#buffer#edit_content(blame.navi_content)
  call hita#command#blame#display_pseudo_separators(blame.separators)
endfunction

function! hita#command#blame#navi#define_highlights() abort
  call hita#command#blame#define_highlights()
  highlight default link HitaHorizontal Comment
  highlight default link HitaSummary    Title
  highlight default link HitaMetaInfo   Comment
  highlight default link HitaAuthor     Identifier
  highlight default link HitaTimeDelta  Comment
  highlight default link HitaRevision   String
  highlight default link HitaPrevious   Special
  highlight default link HitaLineNr     LineNr
endfunction
function! hita#command#blame#navi#define_syntax() abort
  syntax match HitaSummary   /\v.*/ contains=HitaLineNr,HitaMetaInfo,HitaPrevious
  syntax match HitaLineNr    /\v^\s*[0-9]+/
  syntax match HitaMetaInfo  /\v\w+ authored .*$/ contains=HitaAuthor,HitaTimeDelta,HitaRevision
  syntax match HitaAuthor    /\v\w+\ze authored/ contained
  syntax match HitaTimeDelta /\vauthored \zs.*\ze\s+[0-9a-fA-F]{7}$/ contained
  syntax match HitaRevision  /\v[0-9a-fA-F]{7}$/ contained
  syntax match HitaPrevious  /\vPrev: [0-9a-fA-F]{7}$/ contained
endfunction

call hita#define_variables('command#blame#navi', {
      \ 'default_entry_opener': 'edit',
      \ 'entry_openers': {
      \   'edit':    ['edit', 1],
      \   'above':   ['leftabove new', 1],
      \   'below':   ['rightbelow new', 1],
      \   'left':    ['leftabove vnew', 1],
      \   'right':   ['rightbelow vnew', 1],
      \   'tab':     ['tabnew', 0],
      \   'preview': ['pedit', 0],
      \ },
      \ 'enable_default_mappings': 1,
      \})

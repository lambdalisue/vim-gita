let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Console = s:V.import('Vim.Console')

function! gita#util#option#cascade(content_type, options, ...) abort
  let options = get(a:000, 0, {})
  let options = extend(options, gita#meta#get_for(a:content_type, 'options', {}))
  let options = extend(options, a:options)
  return options
endfunction

function! gita#util#option#assign_commit(options) abort
  if has_key(a:options, 'commit')
    return
  elseif gita#action#is_attached()
    let candidates = filter(
          \ gita#action#get_candidates(),
          \ 'gita#action#is_satisfied(v:val, [''commit''])',
          \)
    if !empty(candidates)
      let a:options.commit = candidates[0].commit
    endif
  endif

  if empty(get(a:options, 'commit'))
    let commit = gita#meta#get('commit')
    if !empty(commit)
      let a:options.commit = commit
    endif
  endif
endfunction

function! gita#util#option#assign_filename(options) abort
  if has_key(a:options, 'filename')
    return
  elseif !empty(get(a:options, '__unknown__'))
    let a:options.filename = a:options.__unknown__[0]
  elseif gita#action#is_attached()
    let candidates = filter(
          \ gita#action#get_candidates(),
          \ 'gita#action#is_satisfied(v:val, [''path''])',
          \)
    if !empty(candidates)
      let a:options.filename = candidates[0].path
    endif
  endif

  if empty(get(a:options, 'filename'))
    " NOTE:
    " gita#meta#expand() always return a real absolute path or ''
    let filename = gita#meta#expand('%')
    if !empty(filename)
      let a:options.filename = filename
    endif
  endif
endfunction

function! gita#util#option#assign_filenames(options) abort
  if has_key(a:options, 'filenames')
    return
  elseif !empty(get(a:options, '__unknown__'))
    let a:options.filenames = a:options.__unknown__
    return
  elseif gita#action#is_attached()
    let candidates = filter(
          \ gita#action#get_candidates(),
          \ 'gita#action#is_satisfied(v:val, [''path''])',
          \)
    let a:options.filenames = map(candidates, 'v:val.path')
  endif
endfunction

function! gita#util#option#assign_selection(options) abort
  if !empty(get(a:options, 'selection'))
    if s:Prelude.is_string(a:options.selection)
      let a:options.selection = map(
            \ split(a:options.selection, '-'),
            \ 'str2nr(v:val)',
            \)
    endif
  else
    let a:options.selection = get(
          \ a:options,
          \ '__range__',
          \ mode() =~# '^\c\%(v\|CTRL-V\|s\)$'
          \   ? [line("'<"), line("'>")]
          \   : [line('.'), line('.')],
          \)
  endif

  let content_type = gita#meta#get('content_type')
  if content_type =~# '^blame-\%(navi\|view\)$'
    let ls = get(a:options.selection, 0, 1)
    let le = get(a:options.selection, 1, ls)
    let blamemeta = gita#meta#get_for('^blame-\%(navi\|view\)$', 'blamemeta')
    let a:options.selection = [
          \ gita#content#blame#get_pseudo_linenum(blamemeta, ls),
          \ gita#content#blame#get_pseudo_linenum(blamemeta, le),
          \]
  elseif !empty(content_type)
    " No selection should be available for other manipulation panels
    " Note that candidates of 'grep' has 'selection' so that selection
    " will be used from 'grep' window
    let a:options.selection = []
  endif
endfunction

function! gita#util#option#assign_opener(options, ...) abort
  if !empty(get(a:options, 'opener'))
    return
  endif

  let content_type = gita#meta#get('content_type')
  if content_type =~# '^blame-\%(navi\|view\)$'
    let a:options.opener = 'tabedit'
  endif
endfunction

let s:V = gita#vital()
let s:Prompt = s:V.import('Vim.Prompt')

function! gita#option#init(content_type, options, ...) abort
  let options = deepcopy(a:options)
  let content_type = gita#get_meta('content_type', '')
  if !empty(a:content_type)&& content_type =~# a:content_type
    call extend(options, gita#get_meta('options', {}), 'keep')
  endif
  call extend(options, get(a:000, 0, {}), 'keep')
  return options
endfunction

function! gita#option#assign_commit(options) abort
  if has_key(a:options, 'commit')
    return
  endif
  let commit = gita#get_meta('commit')
  if !empty(commit)
    let a:options.commit = commit
  endif
endfunction

function! gita#option#assign_filename(options) abort
  if has_key(a:options, 'filename')
    return
  endif
  " NOTE:
  " gita#expand() always return a real absolute path or ''
  let filename = gita#expand('%')
  if !empty(filename)
    let a:options.filename = filename
  endif
endfunction

function! gita#option#assign_selection(options) abort
  if has_key(a:options, 'selection')
    let a:options.selection = map(
          \ split(a:options.selection, '-'),
          \ 'str2nr(v:val)',
          \)
  else
    let a:options.selection = a:options.__range__
  endif

  if gita#get_meta('content_type') =~# '^blame-\%(navi\|view\)%'
    let line_start = get(a:options.selection, 0, 0)
    let line_end = get(a:options.selection, 1, line_end)
    let a:options.selection = [
          \ gita#command#blame#get_pseudo_linenum(line_start),
          \ gita#command#blame#get_pseudo_linenum(line_end),
          \]
  endif
endfunction

let s:V = hita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:ArgumentParser = s:V.import('ArgumentParser')

let s:registry = {}

function! hita#command#is_registered(name) abort
  return index(keys(s:registry), a:name) != -1
endfunction
function! hita#command#register(name, command, complete, ...) abort
  if has_key(s:registry, a:name)
    call hita#throw(printf(
          \ 'ValidationError: A command "%s" has already been registered',
          \ a:name,
          \))
  endif
  let s:registry[a:name] = {
        \ 'command': s:Prelude.is_string(a:command)
        \   ? function(a:command)
        \   : a:command,
        \ 'complete': s:Prelude.is_string(a:complete)
        \   ? function(a:complete)
        \   : a:complete,
        \}
endfunction
function! hita#command#unregister(name) abort
  if !has_key(s:registry, a:name)
    call hita#throw(printf(
          \ 'ValidationError: A command "%s" has not been registered yet',
          \ a:name,
          \))
  endif
  unlet s:registry[a:name]
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita',
          \ 'description': [
          \   'A git manipulation command',
          \ ],
          \})
    call s:parser.add_argument(
          \ 'action', [
          \   'An action name of vim-hita. The following actions are available:',
          \ ], {
          \   'required': 1,
          \   'terminal': 1,
          \   'complete': function('s:complete_action'),
          \})
    " TODO: Write available actions
  endif
  return s:parser
endfunction
function! s:complete_action(arglead, cmdline, cursorpos, ...) abort
  let available_commands = keys(s:registry)
  return filter(available_commands, 'v:val =~# "^" . a:arglead')
endfunction
function! hita#command#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if !empty(options)
    let bang  = a:1
    let range = a:2
    let args  = join(options.__unknown__)
    let name  = get(options, 'action', '')
    if hita#command#is_registered(name)
      try
        call s:registry[name].command(bang, range, args)
      catch /^\%(vital: Git[:.]\|vim-hita:\)/
        call hita#util#handle_exception()
      endtry
    else
      echo parser.help()
    endif
  endif
endfunction
function! hita#command#complete(arglead, cmdline, cursorpos, ...) abort
  let bang    = a:cmdline =~# '\v^Hita!'
  let cmdline = substitute(a:cmdline, '\C^Hita!\?\s', '', '')
  let cmdline = substitute(cmdline, '[^ ]\+$', '', '')
  let parser  = s:get_parser()
  let options = call(parser.parse, [bang, [0, 0], cmdline], parser)
  if !empty(options)
    let name = get(options, 'action', '')
    if hita#command#is_registered(name)
      try
        return s:registry[name].complete(a:arglead, cmdline, a:cursorpos)
      catch
        " fail silently
        call s:Prompt.debug(v:exception)
        call s:Prompt.debug(v:throwpoint)
        return []
      endtry
    endif
  endif
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

" Register sub commands
call hita#command#register('add',
      \ 'hita#command#add#command',
      \ 'hita#command#add#complete',
      \)
call hita#command#register('apply',
      \ 'hita#command#apply#command',
      \ 'hita#command#apply#complete',
      \)
call hita#command#register('blame',
      \ 'hita#command#blame#command',
      \ 'hita#command#blame#complete',
      \)
call hita#command#register('browse',
      \ 'hita#command#browse#command',
      \ 'hita#command#browse#complete',
      \)
call hita#command#register('checkout',
      \ 'hita#command#checkout#command',
      \ 'hita#command#checkout#complete',
      \)
call hita#command#register('diff',
      \ 'hita#command#diff#command',
      \ 'hita#command#diff#complete',
      \)
call hita#command#register('reset',
      \ 'hita#command#reset#command',
      \ 'hita#command#reset#complete',
      \)
call hita#command#register('rm',
      \ 'hita#command#rm#command',
      \ 'hita#command#rm#complete',
      \)
call hita#command#register('show',
      \ 'hita#command#show#command',
      \ 'hita#command#show#complete',
      \)
call hita#command#register('status',
      \ 'hita#command#status#command',
      \ 'hita#command#status#complete',
      \)

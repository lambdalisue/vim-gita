let s:V = hita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:ArgumentParser = s:V.import('ArgumentParser')

let s:registry = {}

function! hita#command#is_registered(name) abort
  return index(keys(s:registry), a:name) != -1
endfunction
function! hita#command#register(name, command, complete, ...) abort
  try
    call hita#util#validate#key_not_exists(
          \ a:name, s:registry,
          \ 'A command "%value" has already been registered',
          \)
    let s:registry[a:name] = {
          \ 'command': s:Prelude.is_string(a:command)
          \   ? function(a:command)
          \   : a:command,
          \ 'complete': s:Prelude.is_string(a:complete)
          \   ? function(a:complete)
          \   : a:complete,
          \}
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
  endtry
endfunction
function! hita#command#unregister(name) abort
  try
    call hita#util#validate#key_exists(
          \ a:name, s:registry,
          \ 'A command "%value" has not been registered yet',
          \)
    unlet s:registry[a:name]
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
  endtry
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
      call s:registry[name].command(bang, range, args)
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
      return s:registry[name].complete(a:arglead, cmdline, a:cursorpos)
    endif
  endif
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

" Register sub commands
call hita#command#register('apply',
      \ 'hita#command#apply#command',
      \ 'hita#command#apply#complete',
      \)
call hita#command#register('diff',
      \ 'hita#command#diff#command',
      \ 'hita#command#diff#complete',
      \)
call hita#command#register('show',
      \ 'hita#command#show#command',
      \ 'hita#command#show#complete',
      \)

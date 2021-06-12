function! s:goimpl(...)
  let save_only = a:000[0]
  if !save_only
    if &readonly
      return call("s:goimpl", [1]+a:000[1:])
    end
    let dir = expand('%:p:h')
    if dir =~# '/pkg/mod/\|/vendor/'
      return call("s:goimpl", [1]+a:000[1:])
    end
  end
  noau update
  try
    let lines = call("s:get_impl", a:000[1:])
  catch
    echom v:exception
    return
  endtry
  if empty(lines)
    echo "nothing to add"
    return
  end
  if save_only
    let @" = join(lines, "\n")
    echo "implementation copied!"
  else
    normal %
    call append(line('.'), ['']+lines)
  end
endfunction

function! s:get_current_word()
  let is_struct = v:true
  let word = expand('<cword>')
  if word ==# 'type'
    normal! w
    let word = expand('<cword>')
  elseif word ==# 'struct' || word ==# 'interface'
    normal! B
    let word = expand('<cword>')
  endif
  if getline('.') =~# 'interface'
    let is_struct = v:false
  end
  return [word, is_struct]
endfunction

function! s:get_package_iface(iface, dir)
  let iface = a:iface
  if stridx(iface, "/") == -1 
    if stridx(iface, ".") == -1 
      silent let package = system(printf('cd %s && go list', shellescape(a:dir)))
      if v:shell_error != 0 && stridx(a:dir, '/pkg/mod/') != -1
        let package = substitute(a:dir, '^.*/pkg/mod/', '', '')
        let iface = substitute(package, '@.*/', '/', '') . '.' . iface
      else
        if !empty(package)
          let iface = substitute(package, '[ \t\r\n]', '', 'g') . '.' . iface
        endif
      endif
    else
      let ipkg = split(iface, '\.')[-2]
      silent let packages = systemlist(printf("cd %s && go list -f '{{join .Imports \"\\n\"}}'", shellescape(a:dir)))
      for pkg in packages
        if pkg =~# ipkg . '$'
          let iface = pkg . '.'. split(iface, '\.')[-1]
          break
        end
      endfor
    endif
  endif
  return iface
endfunction

function! s:get_impl(...) abort
  let dir = expand('%:p:h')
  let new = v:false
  " no args
  if empty(a:000)
    let [iface, is_struct] = s:get_current_word()
    if is_struct
      throw "please specify an interface to impl"
    end
    let iface = s:get_package_iface(iface, dir)
    let struct = split(iface, '\.')[-1] ."Impl"
    let new = v:true
  elseif len(a:000) ==# 1
    let [word, is_struct] = s:get_current_word()
    if is_struct
      let struct = word
      let iface = s:get_package_iface(a:000[0], dir)
    else
      let iface = s:get_package_iface(word, dir)
      let struct = a:000[0]
      let new = v:true
    end
  else
    let iface = s:get_package_iface(a:000[0], dir)
    let struct = a:000[1]
    let new = v:true
  endif
  if empty(iface)
    throw "no interface found"
  endif
  let impl = printf('%s *%s', tolower(struct[0]), struct)
  let cmd = printf('impl -dir %s %s %s', shellescape(dir), shellescape(impl), iface)
  let out = system(cmd)
  let lines = split(out, '\n')
  if v:shell_error != 0
    throw join(lines, "\n")
  endif
  if new
    let lines = ['type ' . struct . ' struct {', '}', ''] + lines
  endif
  return lines
endfunction

command! -bang -nargs=* -buffer GoImpl call s:goimpl(<bang>0, <f-args>)

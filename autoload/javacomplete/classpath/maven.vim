let s:pomProperties={}   "maven project properties
let s:pomTags = ['build', 'properties']

function! javacomplete#classpath#maven#IfMaven()
  if executable('mvn') && g:JavaComplete_PomPath != ""
    return 1
  endif
  return 0
endfunction

function! javacomplete#classpath#maven#Generate() abort
  let g:JavaComplete_ProjectKey = substitute(g:JavaComplete_PomPath, '[\\/:;.]', '_', 'g')
  let path = javacomplete#util#GetBase("classpath". g:FILE_SEP). g:JavaComplete_ProjectKey

  if filereadable(path)
    if getftime(path) >= getftime(g:JavaComplete_PomPath)
      return join(readfile(path), '')
    endif
    call javacomplete#util#RemoveFile(javacomplete#util#GetBase('cache'). g:FILE_SEP. 'class_packages_'. g:JavaComplete_ProjectKey. '.dat')
  endif

  if !has_key(s:pomProperties, g:JavaComplete_PomPath)
    let s:mavenPath = path
    let s:mavenPom = g:JavaComplete_PomPath
    let s:mavenSettingsOutput = []
    let mvnCmd = ['mvn', '--file', g:JavaComplete_PomPath, 'help:effective-pom', 'dependency:build-classpath', '-DincludeScope=test']
    call javacomplete#util#RunSystem(mvnCmd, 'maven classpath build process', 'javacomplete#classpath#maven#BuildClasspathHandler')
    return ""
  endif

  return s:GetMavenClasspath(path, g:JavaComplete_PomPath)
endfunction

function! s:GetMavenClasspath(path, pom)
  let mvnProperties = s:pomProperties[a:pom]
  let cp = get(mvnProperties, 'project.dependencybuildclasspath', '.')
  let cp .= g:PATH_SEP . get(mvnProperties, 'project.build.outputDirectory', join([fnamemodify(a:pom, ':h'), 'target', 'classes'], g:FILE_SEP))
  let cp .= g:PATH_SEP . get(mvnProperties, 'project.build.testOutputDirectory', join([fnamemodify(a:pom, ':h'), 'target', 'test-classes'], g:FILE_SEP))
  if cp != '.'
    call writefile([cp], a:path)
  endif
  return cp
endfunction

function! s:ParseMavenOutput()
  let mvnProperties = {}
  let mvnIsManagedTag = 1
  let currentPath = 'project'
  for i in range(len(s:mavenSettingsOutput))
    if s:mavenSettingsOutput[i] =~ 'Dependencies classpath:'
      let mvnProperties['project.dependencybuildclasspath'] = s:mavenSettingsOutput[i + 1]
    endif
    let matches = matchlist(s:mavenSettingsOutput[i], '\m^\s*<\([a-zA-Z0-9\-\.]\+\)>\s*$')
    if mvnIsManagedTag && !empty(matches)
      let mvnIsManagedTag = index(s:pomTags, matches[1]) >= 0
      let currentPath .= '.' . matches[1]
    else
      let matches = matchlist(s:mavenSettingsOutput[i], '\m^\s*</\([a-zA-Z0-9\-\.]\+\)>\s*$')
      if !empty(matches)
        let mvnIsManagedTag = index(s:pomTags, matches[1]) < 0
        let currentPath  = substitute(currentPath, '\m\.' . matches[1] . '$', '', '')
      else
        let matches = matchlist(s:mavenSettingsOutput[i], '\m^\s*<\([a-zA-Z0-9\-\.]\+\)>\(.\+\)</[a-zA-Z0-9\-\.]\+>\s*$')
        if mvnIsManagedTag && !empty(matches)
          let mvnProperties[currentPath . '.' . matches[1]] = matches[2]
        endif
      endif
    endif
  endfor
  let s:pomProperties[s:mavenPom] = mvnProperties
endfunction

function! javacomplete#classpath#maven#BuildClasspathHandler(jobId, data, event)
  if a:event == 'exit' && a:data == '0'
    if a:data == "0"
      call s:ParseMavenOutput()

      let g:JavaComplete_LibsPath .= s:GetMavenClasspath(s:mavenPath, s:mavenPom)

      call javacomplete#server#Terminate()
      call javacomplete#server#Start()

      echo "Maven classpath builded successfully"
    else
      echo "Failed to build maven classpath"
    endif

    unlet s:mavenPath
    unlet s:mavenPom
    unlet s:mavenSettingsOutput
  elseif a:event == 'stdout'
    echom join(a:data)
    call extend(s:mavenSettingsOutput, a:data)
  elseif a:event == 'stderr'
    echoerr join(a:data)
  endif
endfunction

" vim:set fdm=marker sw=2 nowrap:

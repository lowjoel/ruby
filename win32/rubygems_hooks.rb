Gem.pre_install do |gem_installer|
  unless gem_installer.spec.extensions.empty?
    has_msvc = lambda do
      `cl /? 2>&1`
      $? && $?.exited? && $?.success?
    end
    next if has_msvc.call

    phrase = 'Including Visual Studio into PATH...'
    if defined?(Gem)
      Gem.ui.say(phrase) if Gem.configuration.verbose
    else
      puts phrase
    end

    registry_regex = /REG_SZ +(.+)\n/
    environment_regex = /([^=]+)=(.*)\n/

    _, arch, vsver = (/mswin([\d]*)_([\d]+)0/.match(RbConfig::CONFIG['target_os'])).to_a
    arch = arch == '64' ? 'x64' : 'x86'
    vsdir = registry_regex.match(`reg query HKLM\\Software\\Microsoft\\VisualStudio\\#{vsver}.0 /reg:32 /v InstallDir`)[1]
    vsvarsall = File.join(vsdir, '../../VC/vcvarsall.bat')

    IO.popen(['cmd', '/c', vsvarsall, arch, '&set', err: [:child, :out]]) do |stdout|
      stdout.each do |line|
        _, name, value = environment_regex.match(line).to_a
        if name
          ENV[name] = value
        else
          Gem.ui.say("Unrecognised line #{line}") if Gem.configuration.verbose
        end
      end
    end

    unless has_msvc.call
      raise Gem::InstallError,<<-EOT
The '#{gem_installer.spec.name}' native gem requires installed build tools.
Please update your PATH to include build tools.
EOT
    end
  end
end

$default_tasks = []
Dir.glob('tasks/*.rake').each {|file| load file }
task default: $default_tasks unless $default_tasks.empty?

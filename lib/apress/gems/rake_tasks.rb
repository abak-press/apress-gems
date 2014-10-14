# coding: utf-8
# load everything from tasks/ directory
Dir[File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'tasks', '*.{rb,rake}'))].each { |f| load(f) }

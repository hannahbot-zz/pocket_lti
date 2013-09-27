$LOAD_PATH.unshift(File.expand_path('../../', __FILE__))

ENV['RACK_ENV'] ||= 'development'

require 'bundler'
Bundler.require(:default, ENV['RACK_ENV'].to_sym)
require 'pocket_lti'
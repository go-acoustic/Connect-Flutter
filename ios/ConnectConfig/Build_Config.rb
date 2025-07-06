#!/usr/bin/env ruby
require 'json'

#--------------------------------------------------------------------------------------------
# Copyright (C) 2025 Acoustic, L.P. All rights reserved.
#
# NOTICE: This file contains material that is confidential and proprietary to
# Acoustic, L.P. and/or other developers. No license is granted under any intellectual or
# industrial property rights of Acoustic, L.P. except as may be provided in an agreement with
# Acoustic, L.P. Any unauthorized copying or distribution of content from this file is
# prohibited.
#--------------------------------------------------------------------------------------------
  
pods_root   = ARGV[0]
config_file = ARGV[1]
lib_root    = ARGV[2]

begin 
    puts "*********Build_Config.rb*********"
    puts "Current directory: #{Dir.pwd}"
    puts "Pods root:#{pods_root}"
    puts "Config file:#{config_file}"
    puts "Lib root:#{lib_root}"
    puts "Script location: #{__FILE__}"
    puts "**********************************"
    config_path = "#{pods_root}/../../#{config_file}"
    if !File.exist?(config_path)
        config_path = "#{pods_root}/../#{config_file}"
        lib_root = "#{pods_root}/../#{lib_root}"
    end

    if File.exist?(config_path)
        puts "Read from ConnectConfig.json at:#{config_path}"
        json = JSON.parse(File.read(config_path))
        puts JSON.pretty_generate(json)
    else
        puts "ConnectConfig.json does not exist at:#{config_path}"
        exit
    end

    libConfigPath = "#{lib_root}/AcousticConnectConfig.json"
    if File.exist?(libConfigPath)
        puts "Read from ConnectConfig.json at:#{libConfigPath}"
        libConfig = File.read(libConfigPath)
        puts libConfig

        File.open(libConfigPath, 'w') do |f|
          f.write(JSON.pretty_generate(json))
        end

        libConfig = File.read(libConfigPath)
        puts "Update #{libConfigPath} to"
        puts "#{libConfig}"
    else
        puts "ConnectConfig.json does not exist at:#{libConfigPath}"
        exit
    end

    rescue Errno::ENOENT
        exit
end

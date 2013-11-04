#
# Cookbook Name:: homesick
# Provider:: default
#
# Copyright 2013, Thomas Boerger
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "chef/dsl/include_recipe"
include Chef::DSL::IncludeRecipe

action :create do
  new_resource.keys.each do |name, key|
    simple = key.gsub("/", "_")

    execute "homesick_pull_#{new_resource.username}_#{simple}" do
      command "homesick pull #{key} --force"
      action :run

      user new_resource.username
      group new_resource.group || new_resource.username

      environment(
        "HOME" => home_directory
      )

      only_if do
        ::File.directory? homesick_directory_for(key) and new_commits_for? homesick_directory_for(key)
      end
      
      notifies :run, "execute[homesick_symlink_#{new_resource.username}_#{simple}]", :immediately
    end

    execute "homesick_clone_#{new_resource.username}_#{simple}" do
      command "homesick clone #{key} --force"
      action :run

      user new_resource.username
      group new_resource.group || new_resource.username

      environment(
        "HOME" => home_directory
      )

      not_if do
        ::File.directory? homesick_directory_for(key)
      end
      
      notifies :run, "execute[homesick_symlink_#{new_resource.username}_#{simple}]", :immediately
    end

    execute "homesick_symlink_#{new_resource.username}_#{simple}" do
      command "homesick symlink #{key} --force"
      action :nothing

      user new_resource.username
      group new_resource.group || new_resource.username

      environment(
        "HOME" => home_directory
      )

      only_if do
        ::File.directory? homesick_directory_for(key)
      end
    end
  end

  new_resource.updated_by_last_action(true)
end

action :delete do
  new_resource.keys.each do |name, key|
    simple = key.gsub("/", "_")

    execute "homesick_unlink_#{new_resource.username}_#{simple}" do
      command "homesick unlink #{key}"
      action :run

      user new_resource.username
      group new_resource.group || new_resource.username

      only_if do
        ::File.directory? homesick_directory_for(key)
      end
    end
    
    directory homesick_directory_for(key) do
      action :delete
    end
  end

  new_resource.updated_by_last_action(true)
end

def new_commits_for?(directory)
  `cd #{directory}; git rev-list HEAD...origin/master --count`.strip != "0"
end

def homesick_directory_for(key)
  "#{home_directory}/.homesick/repos/#{key.split("/").last}"
end

protected

def home_directory
  if new_resource.home
    new_resource.home
  else
    if new_resource.username == "root"
      "/root"
    else
      "/home/#{new_resource.username}"
    end
  end
end

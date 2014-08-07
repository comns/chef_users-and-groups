#
# Cookbook Name:: users-and-groups
# Recipe:: default
#
# Copyright (C) 2010 Com N Sense Ltd.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

# Returns true whether the given item (user or group representation)
# should not be defined on this node.
def not_on_this_node?(item)
  item['only_in'] && (Array(item['only_in']) & node.roles).empty?
end

# First we define the groups
data_bag(node[:users_and_groups][:groups_databag]).each do |g|
  if not_on_this_node? g
    next
  end

  group g['id'] do
    gid g['gid'] if g['gid']
  end
end

data_bag(node[:users_and_groups][:users_databag]).each do |u|
  u = Chef::EncryptedDataBagItem.load('users', u) if
      node.users_and_groups.encrypted_data_bag

  if not_on_this_node? u
    next
  end

  homedir = u['home'] || "/home/#{u['id']}"

  user u['id'] do
    uid u['uid'] if u['uid']
    gid u['gid'] if u['gid']
    password u['shadow'] if u['shadow']
    comment u['comment'] if u['comment']
    shell u['shell'] if u['shell']
    home homedir
    supports :manage_home => true
  end

  # add user to the required groups
  u['groups'].each do |g|
    group g do
      action :modify
      append true
      members u['id']
    end
  end if u['groups']

  # TODO: this is a hack trying to guess the group. need to improve!
  groupname = u['gid'] || u['id']

  # ssh keys
  if u['sshpubkey']
    directory File.join(homedir, '.ssh') do
      owner u['id']
      group groupname
      mode "0700"
    end

    template File.join(homedir, '.ssh', 'authorized_keys') do
      owner u['id']
      group groupname
      mode "0600"
      source "authorized_keys.erb"
      variables :keys => u['sshpubkey']
    end
  end
end

# we should remove the installation user if defined and not currently used
# for sudo.
if node[:installation_user]
  user node[:installation_user] do
    action :remove
    supports :manage_home => true
  end unless ENV['SUDO_USER'] == node[:installation_user]
end

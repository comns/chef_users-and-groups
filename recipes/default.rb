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

# ruby shadow is reqruired to setup passwords.
# TODO: Find a better way to differenticate between embedded chef and
# chef installed on system ruby.
ruby_shadow_package = value_for_platform(
  ["debian", "ubuntu"] => {
    "default" => "libshadow-ruby1.8",
    "12.04" => false
  },
  ["centos", "redhat", "fedora"] => {
    "default" => "ruby-shadow"
  }
)

package ruby_shadow_package if ruby_shadow_package

groupsdb = node[:users_and_groups][:groups_databag]
usersdb  = node[:users_and_groups][:users_databag]

# First we define the groups
data_bag(groupsdb).each do |g|
  grp = node.users_and_groups.encrypted_data_bag ?
        Chef::EncryptedDataBagItem.load(groupsdb, g) :
        data_bag_item(groupsdb, g)

  if not_on_this_node? grp
    next
  end

  group grp['id'] do
    gid grp['gid'] if grp['gid']
  end
end

data_bag(usersdb).each do |u|
  usr = node.users_and_groups.encrypted_data_bag ?
        Chef::EncryptedDataBagItem.load(usersdb, u) :
        data_bag_item(usersdb, u)

  if not_on_this_node? usr
    next
  end

  homedir = usr['home'] || "/home/#{usr['id']}"

  user usr['id'] do
    uid usr['uid'] if usr['uid']
    gid usr['gid'] if usr['gid']
    password usr['shadow'] if usr['shadow']
    comment usr['comment'] if usr['comment']
    shell usr['shell'] if usr['shell']
    home homedir
    supports :manage_home => true
  end

  # add user to the required groups
  usr['groups'].each do |g|
    group g do
      action :modify
      append true
      members usr['id']
    end
  end if usr['groups']

  # TODO: this is a hack trying to guess the group. need to improve!
  groupname = usr['gid'] || usr['id']

  # ssh keys
  if usr['sshpubkey']
    directory File.join(homedir, '.ssh') do
      owner usr['id']
      group groupname
      mode "0700"
    end

    template File.join(homedir, '.ssh', 'authorized_keys') do
      owner usr['id']
      group groupname
      mode "0600"
      source "authorized_keys.erb"
      variables :keys => usr['sshpubkey']
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

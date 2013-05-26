# Users and Groups chef cookbook.

## Note
This cookbooks is not fully tested so make sure you verify it works
for you!

## Description:

A cookbook to help populate users and groups from data bags. It
handles the creation of users and creation + population of groups. It
can also handle `$HOME/.ssh/authorized_keys` if supplied in the data
bag.

## Requirements:

* This cookbook only tested on *Ubuntu* but may work on *CentOS* as well.
* Since it relies on data bags if you're using *chef solo* you must
  use a version that supports local data bags.

## Attributes:

* `node[:users_and_groups][:groups_databag]` - The name of the databag
    that holds the groups (default: 'groups').
* `node[:users_and_groups][:users_databag]` - The name of the databag
    that holds the users (default: 'users').
* `node[:installation_user]` - On some system you must create a user
    during setup. If you set this attribute to the username of that
    user, It will be deleted.
* `node[:users_and_groups][:encrypted_data_bag]` - Whether or not the
    data-bag is encrypted. Default is *false*. For more information on
    enrcypted data bags consult the [Opscode documentations][owiki].

## Usage:

### Simple use case

Let's create a group, 2 users which use this group as their GID and one admin
user.

Create the required data bags to hold the users and groups:

    # knife data bag create users
    # knife data bag create groups

Let's define the group (only the *id* is required):

    # knife data bag create groups mygroup
    {
        "id": "mygroup",
        "gid": 601
    }

Now Let's create the 2 non-admin users (again, only *id* is required):

    # knife data bag create users john
    {
      "id": "john",
      "uid": 601,
      "gid": "mygroup",
      "comment": "John Smith",
      "shadow": "shadowpassword...",
      "sshpubkey": [
        "content-of-ssh-pulic-key"
      ],
      "shell": "/bin/bash"
    }

    # knife data bag create users jack
    {
      "id": "jack",
      "uid": 602,
      "gid": "mygroup",
      "comment": "Jack Doe",
      "shadow": "shadowpassword...",
    }

   Note the gid which is _mygroup_ (the one we created earlier) and the
   _sshpubkey_ which holds a *list* of keys (even if it holds only one key).
   Jack doesn't have ssh key and uses the system default shell.

Finally let's create the last user which is admin (on ubuntu belongs
to group *admin*)
    
    # knife data bag create users haim
    {
      "id": "haim",
      "uid": 501,
      "comment": "Haim Ashkenazi",
      "sshpubkey": [
        "content-of-ssh-pulic-key"
      ],
     "groups": ["admin"]
    }

Note the *groups* key which holds a list of groups this user should
belong to (it must be a list even for one group). In this case the
*gid* would be the system default.

### Different user sets for different types of machines

You can define different users/groups for different types of
machine. This is achieved by setting a *only_in* attribute for the
user or group with a list of *chef roles* it's allowed to be defined
in. A user or group without the *only_in* attribute will be defined on
all nodes.

Here is an example. Say we have 2 tier architecture:

* Web servers - Configured by the "web" role. Web developers should
  access to these servers.
* DB servers - Configured by the "db" role. The DBA should access
  these servers.

The sysadmin should have access to all machines.

Create the users with the *only_in* attribute:

    # knife data bag create users
    # knife data bag edit users webdev
    {
      "id": "webdev",
      [...],
      "only_in": ["web"],
    }

    # knife data bag edit users dba
    {
      "id": "dba",
      [...],
      "only_in": ["db"],
    }

    # knife data bag edit users sysadmin
    {
      "id": "sysadmin",
      [...],
    }

Now the user *webdev* will be created only on web role, the user *dba* will be
created only on db role and the *sysadmin* user will be created on *every*
machine (we didn't specify *only_in* for this user).

The same technique could be applied to groups.

### Deleting installation user

On some installations (e.g, ubuntu) you are required to create a regular
user. You can delete this user by overriding the attribute
`node[:installation_user]` with the user name:

    # vi roles/base.rb
    [...]
    override_attributes :installation_user => "ubuntu",

Since we sometimes use this first-time user as the login user when running
chef-client for the first time, it will only be deleted if we logged in
as different user.

## Todo:

* Delete users if they are not supposed to be defined on this node!
* Better discovery of automatically created gid.
* Create another recipe for managing user shells configs.

[owiki]: http://docs.opscode.com/essentials_data_bags_encrypt.html

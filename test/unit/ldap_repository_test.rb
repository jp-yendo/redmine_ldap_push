# ruby -rubygems -I test test/unit/ldap_repository_test.rb

#
# warning : these tests do alter the LDAP repository !
#

# Classes allowing the Rails logger to work outside a Rails environment
class Logger
  def self.debug(s); puts s end
  def self.error(s); puts s end
  def self.info(s); puts s end
  def self.warn(s); puts s end
end
class Rails
  def self.logger; Logger end
end
require 'net/ldap'
require 'test/unit'

require './lib/redmine_ldap_push/ldap_repository'
require './lib/redmine_ldap_push/ldap_object'
require './lib/redmine_ldap_push/ldap_user'
require './lib/redmine_ldap_push/ldap_group'
require './lib/redmine_ldap_push/ldap_project'

class LdapRepositoryTest < Test::Unit::TestCase

  @@ldapRepository = RedmineLdapPush::LdapRepository.new(url = 'ldap://localhost:389', ldap_base = 'dc=loki', user = 'cn=admin,dc=loki', password = 'ldapiscool',
      tls = false, users_base = 'ou=utilisateurs', groups_base = 'ou=groupes', projects_base = 'ou=projets')

  def test1_connection
    puts "=== LDAP connection test ==="
    @@ldapRepository.test_connection

  rescue RedmineLdapPush::LdapRepositoryException => e
    assert(false, "Can't connect to an Ldap Server!")
    end

  def test2_users
    puts "=== LDAP users CRUD tests ==="
    
    puts "== User simple CRUDs =="
    user = User.new(3, "user3", "michael", "jackson", "mich@wow.com", "simple")

    @@ldapRepository.deleteUser(user)
    assert @@ldapRepository.createUser(user)
    user.firstname="robert"
    user.login += "new"
    assert @@ldapRepository.updateUser(user)
    assert @@ldapRepository.deleteUser(user)
    
    puts "== users' ids switch =="
    user1 = User.new(1, "user1", "robert", "mitchum", "rob@test.com", "pass")
    user2 = User.new(2, "user2", "patricia", "kaas", "pat@why.com", "test")
    @@ldapRepository.createUser(user1)
    @@ldapRepository.createUser(user2)
    puts "SWITCH!"
    user1.id=2
    user2.id=1
    assert @@ldapRepository.updateUser(user1)
    assert @@ldapRepository.updateUser(user2)
    
    @@ldapRepository.deleteUser(user1)
    @@ldapRepository.deleteUser(user2)
    
    puts "== users with same uid (one must be renamed until its next sync) =="
    user1 = User.new(1, "user1", "robert", "mitchum", "rob@test.com", "pass")
    user2 = User.new(2, "user1", "patricia", "kaas", "pat@why.com", "test")
    @@ldapRepository.createUser(user1)
    @@ldapRepository.createUser(user2)
    
    
    
  end
  

  def test3_groups
    puts "=== LDAP groups CRUD tests ==="
    group = Group.new(1, "group1")
    user1 = User.new(1, "user1", "robert", "mitchum", "rob@test.com", "pass")
    user2 = User.new(2, "user2", "patricia", "kaas", "pat@why.com", "test")
    user3 = User.new(3, "user3", "michael", "jackson", "mich@wow.com", "simple")

    @@ldapRepository.deleteGroup(group)

    assert @@ldapRepository.createGroup(group)
    group.name = "group111"
    assert @@ldapRepository.updateGroup(group)

    assert @@ldapRepository.addUserInGroup(user1, group)
    assert @@ldapRepository.addUserInGroup(user2, group)
    assert @@ldapRepository.addUserInGroup(user3, group)
    assert @@ldapRepository.removeUserFromGroup(user2, group)

  #assert false unless @@ldapRepository.deleteGroup(group)
  end

  def test4_projects
    puts "=== LDAP projects CRUD tests ==="
    project = Project.new(1, "Super Cool Project", identifier = "super-cool-project", description = "test project description")
    project.description=""
    user1 = User.new(1, "user1", "robert", "mitchum", "rob@test.com", "pass")
    user2 = User.new(2, "user2", "patricia", "kaas", "pat@why.com", "test")
    user3 = User.new(3, "user3", "michael", "jackson", "mich@wow.com", "simple")

    @@ldapRepository.deleteProject(project)

    assert @@ldapRepository.createProject(project)
    project.description="new project description"
    project.name = "new project name"
    assert @@ldapRepository.updateProject(project)

    assert @@ldapRepository.addUserInProject(user1, project)
    assert @@ldapRepository.addUserInProject(user2, project)
    assert @@ldapRepository.addUserInProject(user3, project)
    assert @@ldapRepository.removeUserFromProject(user2, project)

  #assert false unless @@ldapRepository.deleteProject(project)

  end

end

class User
  attr_accessor :id
  attr_accessor :login
  attr_accessor :firstname
  attr_accessor :lastname
  attr_accessor :mail
  attr_accessor :password
  def initialize(id = 1, login = "test-login", firstname = "test-firstname", lastname = "test-lastname", mail = "test@test.fr", password = "test-password")
    @id = id
    @login = login
    @firstname = firstname
    @lastname = lastname
    @mail = mail
    @password = password
  end
end

class Group
  attr_accessor :id
  attr_accessor :name
  attr_accessor :members
  def initialize(id = 1, name = "test-group")
    @id = id
    @name = name
  end
end

class Project
  attr_accessor :id
  attr_accessor :name
  attr_accessor :description
  attr_accessor :homepage
  attr_accessor :parent_id
  attr_accessor :identifier
  attr_accessor :is_public
  def initialize(id = 1, name = "Test Project", identifier = "test-project", description = "test project description", homepage = "http://project-homepage.com", parent_id = nil, is_public = true)
    @id=id
    @name=name
    @identifier=identifier
    @description=description
    @homepage=homepage
    @parent_id=parent_id
    @is_public=is_public
  end
end

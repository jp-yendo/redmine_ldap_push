# ruby -rubygems -I test test/unit/ldap_objects_test.rb

#
# warning : these tests do alter the LDAP repository !
# DO NOT RUN IT AGAINST A PRODUCTION LDAP
#
# Classes allowing the Rails logger to work outside a Rails environment
# 'cause I was too lazy to get into Rails...
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

module RedmineLdapPush
  class LdapObjectsTest < Test::Unit::TestCase

    def test1_users

      assert_equal(:uid, LdapUser.rdnAttribute)
      assert_equal(:uidnumber, LdapUser.idAttribute)
      assert_equal(nil, LdapUser.memberAttribute)

      user1 = User.new(1, "user1", "robert", "mitchum", "rob@test.com", "pass")
      user2 = User.new(2, "user2", "samantha", "fox", "sam@yo.io", "word")
      lu1 = RedmineLdapPush::LdapUser.new(user1)
      lu2 = RedmineLdapPush::LdapUser.new(user2)

      assert_equal(:uid, lu1.rdnAttribute)
      assert_equal(:uidnumber, lu1.idAttribute)
      assert_equal('user1', lu1.rdn)
      assert_equal('1', lu1.id)
      assert_equal('2', lu2.id)

      assert_not_nil(lu1.attributes[:userpassword])

    end

    def test2_groups
      
      assert_equal(:gidnumber, LdapGroup.idAttribute)
      assert_equal(:memberuid, LdapGroup.memberAttribute)
      
      group1 = Group.new(1, "group1")
      group2 = Group.new(2, "group2")

      lg1 = RedmineLdapPush::LdapGroup.new(group1)
      lg2 = RedmineLdapPush::LdapGroup.new(group2)

      assert_equal(:gidnumber, lg1.idAttribute)
      assert_equal(:memberuid, lg2.memberAttribute)
      assert_equal('1', lg1.id)
      assert_equal('2', lg2.id)

    end

    def test3_projects
      
      assert_equal(:gidnumber, LdapProject.idAttribute)
      assert_equal(:memberuid, LdapProject.memberAttribute)
      
      project1 = Project.new(1, "project one", "project-1")
      project2 = Project.new(2, "project two", "project-2")

      lp1 = RedmineLdapPush::LdapProject.new(project1)
      lp2 = RedmineLdapPush::LdapProject.new(project2)

      assert_equal(:gidnumber, lp1.idAttribute)
      assert_equal(:memberuid, lp1.memberAttribute)
      assert_equal('1', lp1.id)
      assert_equal('2', lp2.id)
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
end

# ruby -rubygems -I test test/unit/ldap_repository_test.rb
#
# warning : these tests do alter the LDAP repository !
# DO NOT RUN IT AGAINST A PRODUCTION LDAP
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

require 'test/unit'
require './lib/redmine_ldap_push/ldap_repository'
require './lib/redmine_ldap_push/ldap_object'
require './lib/redmine_ldap_push/ldap_user'
require './lib/redmine_ldap_push/ldap_group'
require './lib/redmine_ldap_push/ldap_project'
require './lib/redmine_ldap_push/ldap_push_service'

module RedmineLdapPush
  class LdapPushServiceTest < Test::Unit::TestCase
    def test1_connection
      assert LdapPushService.test_connection
    end
  end
end
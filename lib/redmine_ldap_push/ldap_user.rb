#    This file is part of redmine_ldap_push.
#
#    redmine_ldap_push is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    redmine_ldap_push is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with redmine_ldap_push.  If not, see <http://www.gnu.org/licenses/>.

module RedmineLdapPush
  class LdapUser < LdapObject
    @@static_attributes = {
      :objectclass => ["top", "inetorgperson", "posixAccount"],
      :loginshell => "/bin/false",
      :homedirectory => "/dev/null",
      :gidnumber => "0"
    }
    @@rdnAttribute = :uid
    @@idAttribute = :uidnumber
    @@memberAttribute = nil
    def initialize(user, password=nil)
      @rdn = "#{user.login}"
      @attributes = {
        :uidnumber => "#{user.id}",
        :cn => "#{user.firstname} #{user.lastname}",
        :givenname => "#{user.firstname}",
        :sn => "#{user.lastname}",
        :mail => "#{user.mail}"
      }
      (p = password || p = user.password) && @attributes[:userpassword] = LdapRepository.generatePassword(:ssha, p)
    end
    def rdnAttribute; @@rdnAttribute end
    def self.rdnAttribute; @@rdnAttribute end
    def idAttribute; @@idAttribute end
    def self.idAttribute; @@idAttribute end
    def rdn; @rdn end
    def id; @attributes[@@idAttribute] end
    def memberAttribute; @@memberAttribute end
    def self.memberAttribute; @@memberAttribute end
    def static_attributes; @@static_attributes end
    def attributes; @attributes end
    def password=(password)
      @attributes[:userpassword] = LdapRepository.generatePassword(:ssha, password)
    end
  end
end
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

require 'net/ldap'
require 'net/ldap/dn'
require 'timeout'
require 'active_support/all'
require 'base64'
require 'digest/sha1'
require 'set'

module RedmineLdapPush
  class LdapRepositoryException < Exception; end

  class LdapRepositoryTimeoutException < LdapRepositoryException; end

  class LdapRepository

    @@errorcodes = {0 => :success,
      16 => :no_such_attribute,
      20 => :attribute_or_value_exists,
      32 => :no_such_object,
      68 => :entry_already_exists}

    def self.errorcode(code)
      return @@errorcodes[code]
    end

    def initialize(url = 'ldap://localhost:389', ldap_base = 'dc=localhost', user = 'cn=admin,dc=localhost', password = '',
      tls = false, users_base = 'ou=users', groups_base = 'ou=groups', projects_base = 'ou=projects')
      Rails.logger.info "[RLP] LdapRepository initialization..."
      if m = /^ldap:\/\/(.+):([0-9]+)/i.match(url)
        @host = m[1]
        @port = m[2]
      end

      @ldap_user = user
      @ldap_password = password
      @tls = tls

      @ldap_base = ldap_base
      @ldap_users = users_base
      @ldap_groups = groups_base
      @ldap_projects = projects_base

      @timeout = 20
      @ldap_con = nil

      @ldap_con = initialize_ldap_con(@ldap_user, @ldap_password)

    end

    # test the connection to the LDAP
    def test_connection
      with_timeout do
        @ldap_con = initialize_ldap_con(@ldap_user, @ldap_password)
        @ldap_con.open { }
        return true
      end
    rescue Net::LDAP::LdapError => e
      Rails.logger.error "[RLP] LdapRepositoryException : #{e.message}"
      raise LdapRepositoryException.new(e.message)
      end

    def initialize_ldap_con(ldap_user, ldap_password)
      options = { :host => @host,
        :port => @port,
        :encryption => (@tls ? :simple_tls : nil)
      }
      options.merge!(:auth => { :method => :simple, :username => ldap_user, :password => ldap_password }) unless ldap_user.blank? && ldap_password.blank?
      Net::LDAP.new options
    end

    def with_timeout(&block)
      timeout = @timeout
      timeout = 20 unless timeout && timeout > 0
      Timeout.timeout(timeout) do
        return yield
      end
    rescue Timeout::Error => e
      Rails.logger.error '[RLP] Timeout exception : #{e.message}'
      raise LdapRepositoryTimeoutException.new(e.message)
      end

    ### LDAP operations ###############################

    def self.generatePassword(type, password)
      case type
      when :ssha
        #a = [('A'..'Z'),(0..9)].map{ |i| i.to_a }.flatten
        #salt = (1..32).map{ a[rand(a.length)]}.join
        srand; salt = (rand * 1000).to_i.to_s
        '{SSHA}'+Base64.encode64(Digest::SHA1.digest(password+salt)+salt).chomp!
      else
      Net::LDAP::Password.generate(type, password)
      end
    end

    def getOuBase(ldapObjectClass)
      if ldapObjectClass == RedmineLdapPush::LdapUser
        ouBase = "#{@ldap_users}"
      elsif ldapObjectClass == RedmineLdapPush::LdapGroup
        ouBase = "#{@ldap_groups}"
      elsif ldapObjectClass == RedmineLdapPush::LdapProject
        ouBase = "#{@ldap_projects}"
      else
        Rails.logger.error "[RLP] Can't determine ldap base for unknown class [#{ldapObjectClass}]"
        return nil
      end
      return ouBase + ",#{@ldap_base}"
    end

    def generateRandomWord(length=32)
      o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten
      (0...length).map{ o[rand(o.length)] }.join
    end

    def generateDn(ldapObject)
      dn = Net::LDAP::DN.escape("#{ldapObject.rdnAttribute}=#{ldapObject.rdn}")
      dn += ',' + getOuBase(ldapObject.class)
    end

    def generateModifyOperations(ldapObject)
      ops = []
      for attrName,attrValue in ldapObject.attributes
        ops.push([:replace, attrName, attrValue])
      end
      ops
    end

    def findDnById(args)

      if args.has_key?(:ldapObjectClass) and args.has_key?(:id)
        ldapObjectClass = args[:ldapObjectClass]
        idAttr = ldapObjectClass.idAttribute
        id = args[:id]
        ouBase = getOuBase(ldapObjectClass)
      else
        ldapObject = args[:ldapObject]
        idAttr = ldapObject.idAttribute
        id = ldapObject.id
        ouBase = getOuBase(ldapObject.class)
      end

      ldap_con = args[:ldap_con] || @ldap_con
      filter = Net::LDAP::Filter.eq(idAttr, id)
      ldap_con.search(:base => ouBase,
      :filter => filter,
      :return_result => false,
      :scope => Net::LDAP::SearchScope_WholeSubtree) do |entry|
        return entry[:dn][0]
      end
      return nil
    end

    def create(args)
      ldapObject = args[:ldapObject]
      ldap_con = args[:ldap_con] || @ldap_con
      dn = generateDn(ldapObject)
      
      Rails.logger.info "[RLP] create(#{dn})"

      if findDnById(:ldapObject => ldapObject, :ldap_con => ldap_con) != nil
        return update(:ldapObject => ldapObject, :ldap_con => ldap_con)
      end

      if ldap_con.add(:dn => dn, :attributes => ldapObject.static_attributes.merge(ldapObject.attributes))
        Rails.logger.info "[RLP] #{dn} was added on the LDAP server"
        return true
      else
        result = ldap_con.get_operation_result
        if @@errorcodes[result.code] == :entry_already_exists
          Rails.logger.info "[RLP] #{dn} already exists, but has wrong id, renaming this entry randomly..."
          retries = 3
          while retries > 0 && !rename(:olddn => dn, :newrdn => Net::LDAP::DN.escape("#{ldapObject.rdnAttribute}="+generateRandomWord), :ldap_con => ldap_con)
            retries -= 1
          end
          if retries == 0
            return false
          else
            return create(:ldapObject => ldapObject, :ldap_con => ldap_con)
          end
        end
        Rails.logger.error "[RLP] can't create #{dn} on the LDAP server, reason: #{result.message} - #{result.error_message}"
      return false
      end
    rescue Exception => e
      Rails.logger.error "[RLP] Exception : #{e.message}"
      return false
     end

    def rename(args)
      oldDn = args[:olddn]
      newRdn = args[:newrdn]
      ldap_con = args[:ldap_con] || @ldap_con
      if ldap_con.rename(:olddn => oldDn, :newrdn => Net::LDAP::DN.escape(newRdn), :delete_attributes => true)
        Rails.logger.info "[RLP] RDN of #{oldDn} was renamed to #{newRdn} on the LDAP server"
        return true
      else
        result = ldap_con.get_operation_result
        Rails.logger.error "[RLP] RDN of #{oldDn} cannot be renamed to #{newRdn} on the LDAP server, reason: #{result.message} - #{result.error_message}"
        return false
      end
    end

    def update(args)
      ldapObject = args[:ldapObject]
      ldap_con = args[:ldap_con] || @ldap_con
      dn = generateDn(ldapObject)
      
      Rails.logger.info "[RLP] update(#{dn})"
      
      oldDn = findDnById(:ldapObject => ldapObject, :ldap_con => ldap_con)
      Rails.logger.info "update - oldDn:#{oldDn} - newDn:#{dn}"
      if oldDn == nil
        return create(:ldapObject => ldapObject, :ldap_con => ldap_con)
      end

      if oldDn != dn
        # dn has changed!
        if !rename(:olddn => oldDn, :newrdn => "#{ldapObject.rdnAttribute}=#{ldapObject.rdn}", :ldap_con => ldap_con)
          retries = 3
          while retries > 0 && !rename(:olddn => dn, :newrdn => Net::LDAP::DN.escape("#{ldapObject.rdnAttribute}="+generateRandomWord), :ldap_con => ldap_con)
            retries -= 1
          end
          return false unless retries > 0
          rename(:olddn => oldDn, :newrdn => "#{ldapObject.rdnAttribute}=#{ldapObject.rdn}", :ldap_con => ldap_con)
        end
      end

      operations = generateModifyOperations(ldapObject)
      if ldap_con.modify(:dn => dn, :operations => operations)
        Rails.logger.info "[RLP] #{dn} was updated on the LDAP server"
      return true
      else
        result = ldap_con.get_operation_result
        if @@errorcodes[result.code] == :no_such_object
          Rails.logger.info "[RLP] #{dn} does not exist, creating it..."
          return create(:ldapObject => ldapObject, :ldap_con => ldap_con)
        else
          Rails.logger.error "[RLP] can't update #{dn} on the LDAP server, reason: #{result.message} - #{result.error_message}"
        end
      end
      return false
    rescue Exception => e
      Rails.logger.error "[RLP] LdapRepositoryException : #{e.message}"
      return false

      end

    def delete(ldapObject)
      dn = generateDn(ldapObject)
      return deleteByDn(dn)
    end

    def deleteByClassAndId(ldapObjectClass, id)
      idAttr = ldapObjectClass.idAttribute
      ouBase = getOuBase(ldapObjectClass)
      dn = "#{attrName}=#{id},#{ouBase}"
      return deleteByDn(dn)
    end

    def deleteByDn(dn)
      if @ldap_con.delete :dn => dn
        Rails.logger.info "[RLP] #{dn} was removed from the LDAP server"
      return true
      else
        result = @ldap_con.get_operation_result
        Rails.logger.error "[RLP] can't delete #{dn} from the LDAP server, reason: #{result.message} - #{result.error_message}"
      return false
      end
    rescue Exception => e
      Rails.logger.error "[RLP] Exception : #{e.message}"
      return false
      end

    def addObjectInGroup(ldapObject, ldapGroup)
      objectDn = generateDn(ldapObject)
      groupDn = generateDn(ldapGroup)
      groupMemberAttr = ldapGroup.memberAttribute

      if @ldap_con.add_attribute(groupDn, groupMemberAttr, objectDn)
        Rails.logger.debug "[RLP] added #{objectDn} to #{groupDn}"
      return true
      else
        result = @ldap_con.get_operation_result
        if @@errorcodes[result.code] == :attribute_or_value_exists
        return true
        end
        Rails.logger.error "[RLP] can't add #{objectDn} to the #{groupDn}, reason: #{result.message} - #{result.error_message}"
      return false
      end
    rescue Exception => e
      Rails.logger.error "[RLP] LdapRepositoryException : #{e.message}"
      return false
      end

    def removeObjectFromGroup(ldapObject, ldapGroup)
      objectDn = generateDn(ldapObject)
      groupDn = generateDn(ldapGroup)
      groupMemberAttr = ldapGroup.memberAttribute

      if @ldap_con.modify(:dn => groupDn, :operations => [[:delete, groupMemberAttr, objectDn]])
        Rails.logger.debug "[RLP] removed #{objectDn} from #{groupDn}"
      return true
      else
        result = @ldap_con.get_operation_result
        if @@errorcodes[result] == :no_such_attribute
        return true
        end
        Rails.logger.error "[RLP] can't remove #{objectDn} from #{groupDn}, reason: #{result.message} - #{result.error_message}"
      return false
      end
    rescue Exception => e
      Rails.logger.error "[RLP] LdapRepositoryException : #{e.message}"
      return false
      end

    def getAllObjectIds(ldapObjectClass)
      idAttr = ldapObjectClass.idAttribute
      result = Set.new
      @ldap_con.search(:base => getOuBase(ldapObjectClass),
      :attributes => [idAttr],
      :return_result => false,
      :scope => Net::LDAP::SearchScope_WholeSubtree) do |entry|
        entry.each do |attr, values|
          if attr == idAttr
          result.add(values[0])
          end
        end
      end
      return result
    end

    ### USER operations ###############################

    def getAllUserIds
      getAllObjectIds(LdapUser)
    end

    def createUser(user)
      ldapUser = RedmineLdapPush::LdapUser.new(user)
      if user.password == nil
        # generate a random password until next password sync
        ldapUser.password= generateRandomWord
      end
      create(:ldapObject => ldapUser)
    end

    def updateUser(user)
      #ldapUser = LdapUser.new(user)
      ldapUser = RedmineLdapPush::LdapUser.new(user)
      update(:ldapObject => ldapUser)
    end

    def deleteUser(user)
      #ldapUser = LdapUser.new(user)
      ldapUser = RedmineLdapPush::LdapUser.new(user)
      delete(ldapUser)
    end

    def deleteUserById(id)
      deleteByClassAndId(LdapUser, id)
    end

    def updateUserPassword(user, password)
      ldapUser = LdapUser.new(user, password)
      update(:ldapObject => ldapUser)
    end

    ### GROUP operations ###############################

    def getAllGroupIds
      getAllObjectIds(LdapGroup)
    end

    def createGroup(group)
      ldapGroup = LdapGroup.new(group)
      create(:ldapObject => ldapGroup)
    end

    def updateGroup(group)
      ldapGroup = RedmineLdapPush::LdapGroup.new(group)
      update(:ldapObject => ldapGroup)
    end

    def deleteGroup(group)
      ldapGroup = RedmineLdapPush::LdapGroup.new(group)
      delete(ldapGroup)
    end

    def addUserInGroup(user, group)
      ldapUser = LdapUser.new(user)
      ldapGroup = RedmineLdapPush::LdapGroup.new(group)
      addObjectInGroup(ldapUser, ldapGroup)
    end

    def removeUserFromGroup(user, group)
      ldapUser = LdapUser.new(user)
      ldapGroup = RedmineLdapPush::LdapGroup.new(group)
      removeObjectFromGroup(ldapUser, ldapGroup)
    end

    ### PROJECT operations ###############################

    def getAllProjectIds
      getAllObjectIds(LdapProject)
    end

    def createProject(project)
      ldapProject = LdapProject.new(project)
      create(:ldapObject => ldapProject)
    end

    def updateProject(project)
      ldapProject = LdapProject.new(project)
      update(:ldapObject => ldapProject)
    end

    def deleteProject(project)
      ldapProject = LdapProject.new(project)
      delete(ldapProject)
    end

    def addUserInProject(user, project)
      ldapUser = LdapUser.new(user)
      ldapProject = LdapProject.new(project)
      addObjectInGroup(ldapUser, ldapProject)
    end

    def removeUserFromProject(user, project)
      ldapUser = LdapUser.new(user)
      ldapProject = LdapProject.new(project)
      removeObjectFromGroup(ldapUser, ldapProject)
    end

  end

end
# rake -f Rakefile redmine:plugins:redmine_ldap_push:sync_all RAILS_ENV=production
require 'pp'
namespace :redmine do
  namespace :plugins do
    namespace :redmine_ldap_push do

      desc "Synchronize redmine's users, groups and projects from database to the LDAP server"
      task :sync_users => :environment do |t, args|

        if defined?(ActiveRecord::Base)
          ActiveRecord::Base.logger = Logger.new(STDOUT)
          ActiveRecord::Base.logger.level = Logger::WARN
        end

        if ENV['DRY_RUN'].present?
          puts "\n!!! Dry-run execution !!!\n"

          User.send :include, RedmineLdapSync::RedmineExt::UserDryRun
          Group.send :include, RedmineLdapSync::RedmineExt::GroupDryRun
        end

        AuthSourceLdap.all.each do |as|
          puts "Synchronizing AuthSource #{as.name}..."
          as.sync_users
        end
      end
      desc "Synchronize redmine's users, groups and projects from database to the LDAP server" 
      task :sync_all, [:arg1] => :environment do |t, args|
        
        puts "Syncing all users to LDAP..."
        RedmineLdapPush::LdapPushService.sync_all_users
        
        puts "Syncing all groups to LDAP..."
        RedmineLdapPush::LdapPushService.sync_all_groups
        
        puts "Syncing all projects to LDAP..."
        RedmineLdapPush::LdapPushService.sync_all_projects
        
        
        
        #redmineGroups = Group.all.map { |group| group.name }.to_set
        #redmineProjects = Project.all { |project| project.identifier}.to_set
        
        
        #ldapGroups = ldapRepository.getAllGroupNames
        #ldapProjects = ldapRepository.getAllProjectIdentifiers
        
        

      end
    end
  end
end

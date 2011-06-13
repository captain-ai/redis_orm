require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class User < RedisOrm::Base
  property :first_name, String
  property :last_name, String

  index :first_name
  index :last_name
  index [:first_name, :last_name]
end

class OmniUser < RedisOrm::Base
  property :email, String
  property :uid, Integer

  index :email, :case_insensitive => true
  index :uid
  index [:email, :uid], :case_insensitive => true
end

describe "check indices" do
  before(:all) do
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    $redis_pid = spawn 'redis-server ' + path_to_conf, :out => "/dev/null"
    sleep(0.3) # must be some delay otherwise "Connection refused - Unable to connect to Redis"
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    $redis = Redis.new(:host => 'localhost', :path => path_to_socket)
  end
  
  before(:each) do
    $redis.flushall if $redis
  end

  after(:each) do
   $redis.flushall if $redis
  end

  after(:all) do
    Process.kill 9, $redis_pid.to_i if $redis_pid
  end

  it "should change index accordingly to the changes in the model" do
    user = User.new :first_name => "Robert", :last_name => "Pirsig"
    user.save

    u = User.find_by_first_name("Robert")
    u.id.should == user.id

    u = User.find_by_first_name_and_last_name("Robert", "Pirsig")
    u.id.should == user.id

    u.first_name = "Chris"
    u.save

    User.find_by_first_name("Robert").should == nil

    User.find_by_first_name_and_last_name("Robert", "Pirsig").should == nil

    User.find_by_first_name("Chris").id.should == user.id
    User.find_by_last_name("Pirsig").id.should == user.id
    User.find_by_first_name_and_last_name("Chris", "Pirsig").id.should == user.id    
  end

  it "should change index accordingly to the changes in the model (test #update_attributes method)" do
    user = User.new :first_name => "Robert", :last_name => "Pirsig"
    user.save

    u = User.find_by_first_name("Robert")
    u.id.should == user.id

    u = User.find_by_first_name_and_last_name("Robert", "Pirsig")
    u.id.should == user.id

    u.update_attributes :first_name => "Christofer", :last_name => "Robin"

    User.find_by_first_name("Robert").should == nil
    User.find_by_last_name("Pirsig").should == nil
    User.find_by_first_name_and_last_name("Robert", "Pirsig").should == nil

    User.find_by_first_name("Christofer").id.should == user.id
    User.find_by_last_name("Robin").id.should == user.id
    User.find_by_first_name_and_last_name("Christofer", "Robin").id.should == user.id    
  end
  
  it "should create case insensitive indices too" do
    ou = OmniUser.new :email => "GERMAN@Ya.ru", :uid => 2718281828
    ou.save
    
    OmniUser.count.should == 1
    OmniUser.find_by_email("german@ya.ru").should be
    OmniUser.find_all_by_email("german@ya.ru").count.should == 1
    
    OmniUser.find_by_email_and_uid("german@ya.ru", 2718281828).should be
    OmniUser.find_all_by_email_and_uid("german@ya.ru", 2718281828).count.should == 1

    OmniUser.find_by_email("geRman@yA.rU").should be
    OmniUser.find_all_by_email_and_uid("GerMan@Ya.ru", 2718281828).count.should == 1
        
    OmniUser.find_all_by_email_and_uid("german@ya.ru", 2718281829).count.should == 0
  end
end

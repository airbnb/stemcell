require 'spec_helper'

class MockInstance
  def initialize(id)
    @id = id
  end

  def id
    @id
  end

  def status
    :running
  end
end

class MockSecurityGroup
  attr_reader :group_id, :name, :vpc_id
  def initialize(id, name, vpc_id)
    @group_id = id
    @name = name
    @vpc_id = vpc_id
  end
end

class MockException < StandardError
end

describe Stemcell::Launcher do
  let(:launcher) {
    opts = {'region' => 'region'}
    launcher = Stemcell::Launcher.new(opts)
    launcher
  }
  let(:operation) { 'op' }
  let(:instances) { (1..4).map { |id| MockInstance.new(id) } }
  let(:instance_ids) { instances.map(&:id) }

  describe '#launch' do
    let(:ec2) { instance_double(AWS::EC2) }
    let(:client) { double(AWS::EC2::Client) }
    let(:response) { instance_double(AWS::Core::Response) }
    let(:launcher) {
      opts = {'region' => 'region', 'vpc_id' => 'vpc-1'}
      launcher = Stemcell::Launcher.new(opts)
      launcher
    }
    let(:launch_options) {
      {
        'chef_role'               => 'role',
        'chef_environment'        => 'environment',
        'chef_data_bag_secret'    => 'data_bag_secret',
        'git_branch'              => 'branch',
        'git_key'                 => 'key',
        'git_origin'              => 'origin',
        'key_name'                => 'key',
        'instance_type'           => 'c1.xlarge',
        'image_id'                => 'ami-d9d6a6b0',
        'availability_zone'       => 'us-east-1a',
        'count'                   => 2,
        'security_groups'         => ['sg_name1', 'sg_name2'],
        'wait'                    => false
      }
    }

    before do
      allow(launcher).to receive(:try_file).and_return('secret')
      allow(launcher).to receive(:render_template).and_return('template')
      allow(launcher).to receive(:ec2).and_return(ec2)
      allow(ec2).to receive(:client).and_return(client)
      allow(response).to receive(:error).and_return(nil)
    end

    it 'launches all of the instances' do
      expect(launcher).to receive(:get_vpc_security_group_ids).
        with('vpc-1', ['sg_name1', 'sg_name2']).and_call_original
      expect_any_instance_of(AWS::EC2::VPC).to receive(:security_groups).
        and_return([1,2].map { |i| MockSecurityGroup.new("sg-#{i}", "sg_name#{i}", 'vpc-1')})
      expect(launcher).to receive(:do_launch).with(a_hash_including(
          :image_id           => 'ami-d9d6a6b0',
          :instance_type      => 'c1.xlarge',
          :key_name           => 'key',
          :count              => 2,
          :security_group_ids => ['sg-1', 'sg-2'],
          :availability_zone  => 'us-east-1a',
          :user_data          => 'template'
        )).and_return(instances)
      expect(launcher).to receive(:set_tags).with(kind_of(Array), kind_of(Hash)).and_return(nil)
      # set_classic_link should not be set on vpc hosts.
      expect(launcher).not_to receive(:set_classic_link)

      launcher.send(:launch, launch_options)
    end

    it 'calls set_classic_link for non vpc instances' do
      launcher = Stemcell::Launcher.new({'region' => 'region', 'vpc_id' => false})
      expect(launcher).to receive(:set_classic_link)
      expect(launcher).to receive(:set_tags).with(kind_of(Array), kind_of(Hash)).and_return(nil)
      expect(launcher).to receive(:do_launch).and_return(instances)
      launcher.send(:launch, launch_options)
    end
  end

  describe '#set_classic_link' do
    let(:ec2) { instance_double(AWS::EC2) }
    let(:client) { double(AWS::EC2::Client) }
    let(:response) { instance_double(AWS::Core::Response) }
    before do
      allow(launcher).to receive(:ec2).and_return(ec2)
      allow(ec2).to receive(:client).and_return(client)
      allow(response).to receive(:error).and_return(nil)
    end

    let(:classic_link) {
      {
        'vpc_id' => 'vpc-1',
        'security_group_ids' => ['sg-1', 'sg-2'],
        'security_groups' => ['sg_name']
      }
    }

    it 'invokes classic link on all of the instances' do
      expect(launcher).to receive(:get_vpc_security_group_ids).with('vpc-1', ['sg_name']).
        and_call_original
      expect_any_instance_of(AWS::EC2::VPC).to receive(:security_groups).
        and_return([MockSecurityGroup.new('sg-3', 'sg_name', 'vpc-1')])
      instances.each do |instance|
        expect(client).to receive(:attach_classic_link_vpc).ordered.with(a_hash_including(
            :instance_id => instance.id,
            :vpc_id => classic_link['vpc_id'],
            :groups => ['sg-1', 'sg-2', 'sg-3'],
          )).and_return(response)
      end

      launcher.send(:set_classic_link, instances, classic_link)
    end
  end

  describe '#run_batch_operation' do
    it "raises no exception when no internal error occur" do
      errors = launcher.send(:run_batch_operation, instances) {}
      expect(errors.all?(&:nil?)).to be true
    end

    it "runs full batch even when there are two error" do
      errors = launcher.send(:run_batch_operation,
                             instances) do |instance, error|
        raise "error-#{instance.id}" if instance.id % 2 == 0
      end
      expect(errors.count(&:nil?)).to be_eql(2)
      expect(errors.reject(&:nil?).map { |e| e.message }).to \
        be_eql([2, 4].map { |id| "error-#{id}" })
    end

    it "retries after an intermittent error" do
      count = 0
      errors = launcher.send(:run_batch_operation,
                             instances)  do |instance|
        if instance.id == 3
          count += 1
          count < 3 ?
            AWS::EC2::Errors::InvalidInstanceID::NotFound.new("error-#{instance.id}"):
            nil
        end
      end
      expect(errors.all?(&:nil?)).to be true
    end

    it "retries up to max_attempts option per instance" do
      max_attempts = 6
      opts = {'region' => 'region', 'max_attempts' => max_attempts}
      launcher = Stemcell::Launcher.new(opts)
      allow(launcher).to receive(:sleep).and_return(0)
      tags = double("Tags")
      instances = (1..2).map do |id|
        inst = MockInstance.new(id)
        allow(inst).to receive(:tags).and_return(tags)
        inst
      end
      expect(tags).to receive(:set).with({'a' => 'b'}).exactly(12).times.
        and_raise(AWS::EC2::Errors::InvalidInstanceID::NotFound.new("error"))
      expect do
        launcher.send(:set_tags, instances, {'a' => 'b'})
      end.to raise_error(Stemcell::IncompleteOperation)
    end
  end

  describe '#configure_aws_creds_and_region' do
    it 'AWS region is configured after launcher is instanciated' do
      expect(AWS.config.region).to be_eql('region')
    end

    it 'AWS region configuration changed' do
      mock_launcher = Stemcell::Launcher.new('region' => 'ap-northeast-1')
      expect(AWS.config.region).to be_eql('ap-northeast-1')
    end
  end
end

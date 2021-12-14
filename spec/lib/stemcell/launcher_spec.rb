require 'spec_helper'
require 'base64'

describe Stemcell::Launcher do
  before do
    Aws.config[:stub_responses] = true
  end

  let(:launcher) {
    opts = {'region' => 'region'}
    launcher = Stemcell::Launcher.new(opts)
    launcher
  }
  let(:operation) { 'op' }
  let(:instances) do
    ('1'..'4').map do |id|
      Aws::EC2::Types::Instance.new(
        instance_id: id,
        private_ip_address: "10.10.10.#{id}",
        state: Aws::EC2::Types::InstanceState.new(name: 'pending')
      )
    end
  end
  let(:instance_ids) { instances.map(&:id) }

  describe '#launch' do
    let(:ec2) do
      ec2 = Aws::EC2::Client.new
      ec2.stub_responses(
        :describe_security_groups,
        security_groups: [
          {group_id: 'sg-1', group_name: 'sg_name1', vpc_id:'vpc-1'},
          {group_id: 'sg-2', group_name: 'sg_name2', vpc_id:'vpc-1'},
        ],
      )
      ec2.stub_responses(
        :describe_instances,
        reservations: [{
          instances: ('1'..'4').map do |id|
            {
              instance_id: id,
              private_ip_address: "10.10.10.#{id}",
              public_ip_address: "24.10.10.#{id}",
              state: {
                name: 'running'
              }
            }
          end
        }]
      )
      ec2
    end
    let(:response) { instance_double(Seahorse::Client::Response) }
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
        'user'                    => 'some_user',
        'wait'                    => true
      }
    }

    before do
      allow(launcher).to receive(:try_file).and_return('secret')
      allow(launcher).to receive(:render_template).and_return('template')
      allow(launcher).to receive(:ec2).and_return(ec2)
      allow(response).to receive(:error).and_return(nil)
    end

    it 'launches all of the instances' do
      expect(launcher).to receive(:get_vpc_security_group_ids).
        with('vpc-1', ['sg_name1', 'sg_name2']).and_call_original
      expect(ec2).to receive(:describe_security_groups).and_call_original
      expect(launcher).to receive(:do_launch).with(a_hash_including(
          :image_id           => 'ami-d9d6a6b0',
          :instance_type      => 'c1.xlarge',
          :key_name           => 'key',
          :min_count          => 2,
          :max_count          => 2,
          :placement          => { :availability_zone => 'us-east-1a' },
          :network_interfaces => [{
            :device_index => 0,
            :groups => ['sg-1', 'sg-2' ]
          }],
          :tag_specifications => [
            {
              :resource_type => 'instance',
              :tags => [
                { :key => "Name",       :value => "role-environment" },
                { :key => "Group",      :value => "role-environment" },
                { :key => "created_by", :value => "some_user" },
                { :key => "stemcell",   :value => Stemcell::VERSION },
              ]},
          ],
          :user_data          => Base64.encode64('template')
        )).and_return(instances)
      launched_instances = launcher.send(:launch, launch_options)
      expect(launched_instances.map(&:public_ip_address)).to all(be_truthy)
    end
  end

  describe '#kill' do
    let(:ec2) do
      ec2 = Aws::EC2::Client.new
      ec2.stub_responses(
        :terminate_instances, -> (context) {
        instance_ids = context.params[:instance_ids]
        if instance_ids.include? 'i-3'
          Aws::EC2::Errors::InvalidInstanceIDNotFound.new(nil, "The instance ID 'i-3' do not exist")
        else
          {} # success
        end
      })
      ec2
    end

    let(:instance_ids) { ('i-1'..'i-4').to_a }

    before do
      allow(launcher).to receive(:ec2).and_return(ec2)
    end

    context 'when ignore_not_found is true' do
      it 'terminates valid instances even if an invalid instance id is provided' do
        launcher.kill(instance_ids, ignore_not_found: true)
      end

      it 'finishes without error even if no instance ids are valid' do
        launcher.kill(['i-3'], ignore_not_found: true)
      end
    end

    context 'when ignore_not_found is false' do
      it 'raises an error' do
        expect { launcher.kill(instance_ids) }.to raise_error(Aws::EC2::Errors::InvalidInstanceIDNotFound)
      end
    end
  end

  describe '#configure_aws_creds_and_region' do
    it 'AWS region is configured after launcher is instantiated' do
      expect(Aws.config[:region]).to be_eql('region')
    end

    it 'AWS region configuration changed' do
      mock_launcher = Stemcell::Launcher.new('region' => 'ap-northeast-1')
      expect(Aws.config[:region]).to be_eql('ap-northeast-1')
    end
  end

  describe '#ec2' do

    it 'can return a client with regional endpoint' do
      launcher = Stemcell::Launcher.new({'region' => 'us-east-1', 'ec2_endpoint' => nil})
      client = launcher.send(:ec2)
      expect(client.config[:endpoint].to_s).to be_eql('https://ec2.us-east-1.amazonaws.com')
    end

    it 'can return a client with custom endpoint' do
      launcher = Stemcell::Launcher.new({
        'region' => 'region1',
        'ec2_endpoint' => 'https://endpoint1',
      })
      client = launcher.send(:ec2)
      expect(client.config[:endpoint].to_s).to be_eql('https://endpoint1')
    end
  end
end

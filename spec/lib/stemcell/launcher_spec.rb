require 'spec_helper'
require 'base64'

describe Stemcell::Launcher do
  let(:launcher) {
    opts = {'region' => 'region'}
    launcher = Stemcell::Launcher.new(opts)
    launcher
  }
  let(:operation) { 'op' }
  let(:instances) { (1..4).map { |id| Aws::EC2::Types::Instance.new(instance_id: id.to_s) } }
  let(:instance_ids) { instances.map(&:id) }

  describe '#launch' do
    let(:ec2) do
      ec2 = Aws::EC2::Client.new(stub_responses: true)
      ec2.stub_responses(
        :describe_security_groups,
        {
          security_groups: [
            {group_id: 'sg-1', group_name: 'sg_name1', vpc_id:'vpc-1'},
            {group_id: 'sg-2', group_name: 'sg_name2', vpc_id:'vpc-1'},
          ],
        }
      )
      ec2
    end
    let(:response) { instance_double(Seahorse::Client::Response ) }
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
        'wait'                    => false
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
      # set_classic_link should not be set on vpc hosts.
      expect(launcher).not_to receive(:set_classic_link)

      launcher.send(:launch, launch_options)
    end

    it 'calls set_classic_link for non vpc instances' do
      launcher = Stemcell::Launcher.new({'region' => 'region', 'vpc_id' => false})
      expect(launcher).to receive(:set_classic_link)
      expect(launcher).to receive(:do_launch).and_return(instances)
      launcher.send(:launch, launch_options)
    end
  end

  describe '#set_classic_link' do
    let(:ec2) do
      ec2 = Aws::EC2::Client.new(stub_responses: true)
      ec2.stub_responses(
        :describe_security_groups,
        {
          security_groups: [{group_id: 'sg-3', group_name: 'sg_name', vpc_id:'vpc-1'}],
        }
      )
      ec2.stub_responses(:attach_classic_link_vpc, {})
      ec2.stub_responses(:describe_instance_status,
        {
          instance_statuses: [
            (1..2).map { |id| { instance_id: id.to_s, instance_state: { name: 'running' }}},
            (3..4).map { |id| { instance_id: id.to_s, instance_state: { name: 'pending' }}},
          ].flatten
        },
        {
          instance_statuses: (3..4).map { |id| { instance_id: id.to_s, instance_state: { name: 'running' }}}
        }
      )
      ec2
    end
    let(:response) { instance_double(Seahorse::Client::Response) }
    before do
      allow(launcher).to receive(:ec2).and_return(ec2)
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
      expect(ec2).to receive(:describe_security_groups).and_call_original
      instances.each do |instance|
        expect(ec2).to receive(:attach_classic_link_vpc).ordered.with(a_hash_including(
            :instance_id => instance.instance_id,
            :vpc_id => classic_link['vpc_id'],
            :groups => ['sg-1', 'sg-2', 'sg-3'],
          )).and_return(response).and_call_original
      end

      launcher.send(:set_classic_link, instances, classic_link)

      expect(ec2.api_requests.size).to eq(7)
      expect(ec2.api_requests.last[:params]).to eq({
       :instance_id => instances.last.instance_id,
       :vpc_id => classic_link['vpc_id'],
       :groups => ['sg-1', 'sg-2', 'sg-3']
     })
    end
  end

  describe '#run_batch_operation' do
    let(:ec2) do
      ec2 = Aws::EC2::Client.new(stub_responses: true)
      ec2.stub_responses(
        :terminate_instances, -> (context) {
        instance_id = context.params[:instance_ids].first # we terminate one at a time
        if instance_id >= '3'
          Aws::EC2::Errors::InvalidInstanceIDNotFound.new("test", "test")
        else
          {} # success
        end
      })
      ec2
    end

    it "raises no exception when no internal error occur" do
      errors = launcher.send(:run_batch_operation, instances) {}
      expect(errors.all?(&:nil?)).to be true
    end

    it "runs full batch even when there are two error" do
      errors = launcher.send(:run_batch_operation,
                             instances) do |instance, error|
        raise "error-#{instance.instance_id}" if instance.instance_id.to_i % 2 == 0
      end
      expect(errors.count(&:nil?)).to be_eql(2)
      expect(errors.reject(&:nil?).map { |e| e.message }).to \
        be_eql([2, 4].map { |id| "error-#{id}" })
    end

    it "retries after an intermittent error" do
      count = 0
      errors = launcher.send(:run_batch_operation,
                             instances)  do |instance|
        if instance.instance_id == 3
          count += 1
          count < 3 ?
            Aws::EC2::Errors::InvalidInstanceIDNotFound.new("error-#{instance.instance_id}"):
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
      instances = (3..4).map do |id|
        Aws::EC2::Types::Instance.new(instance_id: id.to_s)
      end
      allow(launcher).to receive(:ec2).and_return(ec2)
      instances.each do |instance|
        expect(ec2).to receive(:terminate_instances).with(instance_ids: [instance.instance_id]).exactly(6).times.
          and_raise(Aws::EC2::Errors::InvalidInstanceIDNotFound.new('test', 'test')).and_call_original
      end

      expect do
        launcher.send(:kill, instances)
      end.to raise_error(Stemcell::IncompleteOperation)
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
    let(:ec2) { Aws::EC2::Client.new(stub_responses: true) }

    it 'can return a client with regional endpoint' do
      launcher = Stemcell::Launcher.new({'region' => 'us-east-1', 'ec2_endpoint' => nil})
      allow(launcher).to receive(:ec2).and_return(ec2)
      client = launcher.send(:ec2)
      expect(client.config[:endpoint].to_s).to be_eql('https://ec2.us-east-1.amazonaws.com')
    end

    it 'can return a client with custom endpoint' do
      launcher = Stemcell::Launcher.new({
        'region' => 'region1',
        'ec2_endpoint' => 'https://endpoint1',
        'stub_responses' => true
      })
      client =  launcher.send(:ec2)
      expect(client.config[:endpoint].to_s).to be_eql('https://endpoint1')
    end
  end
end

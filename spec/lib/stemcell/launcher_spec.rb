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
  end
end

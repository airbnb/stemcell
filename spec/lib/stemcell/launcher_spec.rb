require 'spec_helper'

class MockInstance
  def initialize(id)
    @id = id
  end

  def id
    @id
  end
end

class MockException < StandardError
end

describe Stemcell::Launcher do
  let(:launcher) {
    opts = {}
    Stemcell::Launcher::REQUIRED_OPTIONS.map { |k| opts[k] = "" }
    launcher = Stemcell::Launcher.new(opts)
    launcher
  }
  let(:operation) { 'op' }
  let(:instances) { (1..4).map { |id| MockInstance.new(id) } }
  let(:instance_ids) { instances.map(&:id) }

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

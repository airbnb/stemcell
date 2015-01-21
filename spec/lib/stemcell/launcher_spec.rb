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
  let(:sleep) { mock("sleep")}
  let(:launcher) {
    opts = {}
    Stemcell::Launcher::REQUIRED_OPTIONS.map { |k| opts[k] = "" }
    launcher = Stemcell::Launcher.new(opts)
    launcher
  }
  instances = (1..4).map { |id| MockInstance.new(id) }
  instance_ids = instances.map { |i| i.id }

  OPERATION = 'op'
  describe '#run_batch_operation' do

    it "raises no exception when no internal error occur" do
      expect do
        errors = launcher.send(:run_batch_operation, instances) {}
        errors.should be_empty
      end
    end

    it "runs full batch even when there are two error" do
      error_message = get_expected_error_message(
        instance_ids,
        [2, 4].map { |id| [id, "error-#{id}"] }
      )
      expect do
        errors = launcher.send(:run_batch_operation,
                               instances) do |instance, error|
          raise "error-#{instance.id}" if instance.id % 2 == 0
        end
        launcher.send(:check_errors, OPERATION, instance_ids, errors)
      end.to raise_error(Stemcell::IncompleteOperation, error_message)
    end

    it "resumes from an intermittent error" do
      count = 0
      expect do
        errors = launcher.send(:run_batch_operation,
                               instances)  do |instance|
          if instance.id == 3
            count += 1
            raise AWS::EC2::Errors::InvalidInstanceID::NotFound, "error-#{instance.id}" if count < 3
          end
        end
        errors.should be_empty
      end
    end
  end

  private

  def get_expected_error_message(all_instances, errors)
    exception = Stemcell::IncompleteOperation.new(OPERATION, all_instances, errors)
    exception.message
  end
end

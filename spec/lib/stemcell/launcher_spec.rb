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
  OPERATION = 'op'
  describe '#run_batch_operation' do
    instances = (1..4).map { |id| MockInstance.new(id) }
    instance_ids = instances.map { |instance| instance.id }

    opts = {}
    Stemcell::Launcher::REQUIRED_OPTIONS.each { |k| opts[k] = "" }
    launcher = Stemcell::Launcher.new(opts)

    it "raises no exception when no internal error occur" do
      expect do
        launcher.send(:run_batch_operation, instances) do
          # do nothing
        end
      end.to_not raise_error
    end

    it "stop operation immediately when there is one error" do
      error_message = get_expected_error_message(instance_ids,
                                                 [1, 2],
                                                 { 3 => 'error' })
      expect do
        # :stop_on_first_error will implicitly be set to be true
        launcher.send(
            :run_batch_operation,
            instances,
            :operation => OPERATION) do |instance|
          raise "error" if instance.id == 3
        end
      end.to raise_error(Stemcell::IncompleteOperation, error_message)
    end

    it "run full batch even when there are two error" do
      error_message = get_expected_error_message(instance_ids,
                                                 [1, 3],
                                                 { 2 => 'error-2', 4 => 'error-4' })
      expect do
        launcher.send(
            :run_batch_operation,
            instances,
            :operation => OPERATION,
            :stop_on_first_error => false) do |instance|
          raise "error-#{instance.id}" if instance.id % 2 == 0
        end
      end.to raise_error(Stemcell::IncompleteOperation, error_message)
    end

    retry_options = {
      :max_retry => 3,
      :interval_ms => 100,
      :exceptions_to_retry => [MockException],
    }
    it "retry an operation from a intermittent error" do
      count = 0
      expect do
        launcher.send(
            :run_batch_operation,
            instances,
            :operation => OPERATION,
            :retry_options => retry_options) do |instance|
          if instance.id == 3
            count += 1
            raise MockException, "error-#{instance.id}" if count < 3
          end
        end
      end.to_not raise_error
    end

    it "fail because of too many retries" do
      error_message = get_expected_error_message(instance_ids,
                                                 [1, 2, 4],
                                                 { 3 => 'error-3' })
      expect do
        launcher.send(
            :run_batch_operation,
            instances,
            :operation => OPERATION,
            :retry_options => retry_options) do |instance|
          raise MockException, "error-#{instance.id}" if instance.id == 3
        end
      end.to raise_error(Stemcell::IncompleteOperation, error_message)
    end
  end

  private

  def get_expected_error_message(all_instances,
                                 finished_instances,
                                 errors)
    exception = Stemcell::IncompleteOperation.new(OPERATION, all_instances )
    finished_instances.each { |i| exception.add_finished_instance(i) }
    errors.each { |instance, error| exception.add_error(instance, error) }
    exception.message
  end
end

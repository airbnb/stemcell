require 'spec_helper'

class MockInstance
  def initialize(id)
    @id = id
  end

  def id
    @id
  end
end

describe Stemcell::Launcher do
  describe '#run_batch_operation' do
    instances = (1..4).map { |id| MockInstance.new(id) }

    it "raises no exception when no internal error occur" do
      expect do
        Stemcell::Launcher::send(:run_batch_operation, instances) do
          # do nothing
        end
      end.to_not raise_error
    end

    it "stop operation immediately when there is one error" do
      error_message = "Incomplete operation 'one-error': all_instances=1|2|3|4; " +
                      "finished_instances=1|2; errors='3' => 'error'"
      expect do
        # :stop_on_first_error will implicitly be set to be true
        Stemcell::Launcher::send(
            :run_batch_operation,
            instances,
            :operation => 'one-error') do |instance|
          raise "error" if instance.id == 3
        end
      end.to raise_error(Stemcell::IncompleteOperation, error_message)
    end

    it "run full batch even when there are two error" do
      error_message = "Incomplete operation 'two-errors': all_instances=1|2|3|4; " +
                      "finished_instances=1|3; errors='2' => 'error-2'|'4' => 'error-4'"
      expect do
        Stemcell::Launcher::send(
            :run_batch_operation,
            instances,
            :operation => 'two-errors',
            :stop_on_first_error => false) do |instance|
          raise "error-#{instance.id}" if instance.id % 2 == 0
        end
      end.to raise_error(Stemcell::IncompleteOperation, error_message)
    end
  end
end

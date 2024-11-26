require "rubygems"
require "state_machines"

class ProcessMachine
  state_machine :state, initial: :ready do
    event :running do
      transition ready: :running
    end
    event :finished do
      transition running: :finished
    end
  end
end

class ServiceCallMachine
  state_machine :state, initial: :ready do
    event :call do
      transition ready: :called
    end
    event :error do
      transition ready: :got_error
    end
    event :receive do
      transition called: :received
    end
    event :end_activity do
      transition received: :done
    end
  end
end

class ServiceScriptCallMachine
  state_machine :state, initial: :ready do
    event :call do
      transition ready: :called
    end
    event :error do
      transition %i[ready manipulated] => :got_error
    end
    event :receive do
      transition called: :received
    end
    event :manipulate do
      transition received: :manipulated
    end
    event :change_dataelements do
      transition manipulated: :dataelements_changed
    end
    event :end_activity do
      transition %i[dataelements_changed received manipulated] => :done
    end
  end
end

class ScriptCallMachine
  state_machine :state, initial: :ready do
    event :manipulate do
      transition ready: :manipulated
    end
    event :error do
      transition manipulated: :got_error
    end
    event :change_dataelements do
      transition manipulated: :dataelements_changed
    end
    event :end_activity do
      transition %i[dataelements_changed manipulated] => :done
    end
  end
end

class DecisionGatewayMachine
  state_machine :state, initial: :ready do
    event :split do
      transition ready: :gateway_split
    end
    event :decide do
      # For gateway/decide, we have no custom state
      transition gateway_split: :gateway_split
    end
    event :join do
      # For gateway/decide, we have no custom state
      transition gateway_split: :done
    end
  end
end

class ParallelGatewayMachine
  state_machine :state, initial: :ready do
    event :split do
      transition ready: :gateway_split
    end
    event :join do
      transition gateway_split: :done
    end
  end
end
